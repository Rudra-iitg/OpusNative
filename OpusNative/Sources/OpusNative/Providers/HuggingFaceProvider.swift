import Foundation

// MARK: - HuggingFace Provider

/// HuggingFace Inference API provider.
/// Non-streaming, normalizes varying response formats across models.
final class HuggingFaceProvider: AIProvider, @unchecked Sendable {
    let id = "huggingface"
    let displayName = "HuggingFace"
    let supportsVision = false
    let supportsStreaming = false
    let supportsTools = false

    let availableModels = [
        "mistralai/Mistral-7B-Instruct-v0.2",
        "meta-llama/Llama-2-7b-chat-hf",
        "google/flan-t5-xxl",
        "bigscience/bloom-560m",
        "tiiuae/falcon-7b-instruct",
        "HuggingFaceH4/zephyr-7b-beta"
    ]

    private let baseURL = "https://api-inference.huggingface.co/models"
    private let session = URLSession.shared

    // MARK: - Send Message

    func sendMessage(
        _ message: String,
        conversation: [MessageDTO],
        settings: ModelSettings
    ) async throws -> AIResponse {
        let token = try getToken()
        let startTime = CFAbsoluteTimeGetCurrent()

        let endpoint = "\(baseURL)/\(settings.modelName)"
        guard let url = URL(string: endpoint) else {
            throw AIProviderError.modelNotAvailable(model: settings.modelName)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // Build prompt from conversation + message
        let prompt = buildPrompt(message: message, conversation: conversation, systemPrompt: settings.systemPrompt)

        let body: [String: Any] = [
            "inputs": prompt,
            "parameters": [
                "max_new_tokens": settings.maxTokens,
                "temperature": max(settings.temperature, 0.01),  // HF doesn't accept 0
                "top_p": settings.topP,
                "return_full_text": false
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProviderError.invalidResponse(provider: displayName, detail: "Not an HTTP response")
        }

        try handleHTTPErrors(httpResponse, data: data)

        // HuggingFace returns varying formats — normalize
        let content = try parseResponse(data: data)

        return AIResponse(
            content: content,
            tokenCount: nil,  // HF doesn't always return token counts
            latencyMs: latency,
            model: settings.modelName,
            providerID: id,
            finishReason: nil
        )
    }

    // MARK: - Private Helpers

    private func getToken() throws -> String {
        guard let token = KeychainService.shared.load(key: KeychainService.huggingfaceToken),
              !token.isEmpty else {
            throw AIProviderError.missingAPIKey(provider: displayName)
        }
        return token
    }

    private func buildPrompt(message: String, conversation: [MessageDTO], systemPrompt: String) -> String {
        var parts: [String] = []

        if !systemPrompt.isEmpty {
            parts.append("[INST] <<SYS>>\n\(systemPrompt)\n<</SYS>>")
        }

        for msg in conversation {
            if msg.role == "user" {
                parts.append("[INST] \(msg.content) [/INST]")
            } else {
                parts.append(msg.content)
            }
        }

        parts.append("[INST] \(message) [/INST]")

        return parts.joined(separator: "\n")
    }

    private func parseResponse(data: Data) throws -> String {
        // Format 1: Array of objects with "generated_text"
        if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
           let first = array.first,
           let text = first["generated_text"] as? String {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Format 2: Single object with "generated_text"
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = dict["generated_text"] as? String {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Format 3: Array of arrays (some models)
        if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
           let first = array.first,
           let text = first["translation_text"] as? String {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Format 4: Conversational format
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let generated = dict["generated_text"] as? String {
            return generated.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Fallback: try raw string
        if let rawString = String(data: data, encoding: .utf8) {
            return rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        throw AIProviderError.invalidResponse(provider: displayName, detail: "Unrecognized response format")
    }

    private func handleHTTPErrors(_ response: HTTPURLResponse, data: Data) throws {
        guard !(200...299).contains(response.statusCode) else { return }

        let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"

        if response.statusCode == 503 {
            // Model is loading
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let estimatedTime = json["estimated_time"] as? Double {
                throw AIProviderError.serverError(
                    statusCode: 503,
                    message: "Model is loading. Estimated wait: \(Int(estimatedTime))s. Try again shortly."
                )
            }
        }

        if response.statusCode == 429 {
            throw AIProviderError.rateLimited(retryAfter: nil)
        }

        throw AIProviderError.serverError(statusCode: response.statusCode, message: errorText)
    }
}
