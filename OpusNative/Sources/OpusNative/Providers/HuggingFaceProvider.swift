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
        "meta-llama/Meta-Llama-3-8B-Instruct",
        "microsoft/Phi-3-mini-4k-instruct",
        "tiiuae/falcon-7b-instruct",
        "HuggingFaceH4/zephyr-7b-beta"
    ]

    private let baseURL = "https://router.huggingface.co/v1"
    private let session = URLSession.shared

    // MARK: - Send Message

    func sendMessage(
        _ message: String,
        conversation: [MessageDTO],
        settings: ModelSettings
    ) async throws -> AIResponse {
        let token = try getToken()
        let startTime = CFAbsoluteTimeGetCurrent()

        let endpoint = "\(baseURL)/chat/completions"
        guard let url = URL(string: endpoint) else {
            throw AIProviderError.modelNotAvailable(model: settings.modelName)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // Build messages array (OpenAI-compatible format)
        var messages: [[String: String]] = []

        if !settings.systemPrompt.isEmpty {
            messages.append(["role": "system", "content": settings.systemPrompt])
        }

        for msg in conversation {
            messages.append(["role": msg.role, "content": msg.content])
        }

        messages.append(["role": "user", "content": message])

        let body: [String: Any] = [
            "model": settings.modelName,
            "messages": messages,
            "max_tokens": settings.maxTokens,
            "temperature": max(settings.temperature, 0.01),
            "top_p": settings.topP,
            "stream": false
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProviderError.invalidResponse(provider: displayName, detail: "Not an HTTP response")
        }

        try handleHTTPErrors(httpResponse, data: data)

        // Parse OpenAI-compatible response
        let content = try parseResponse(data: data)

        return AIResponse(
            content: content,
            inputTokenCount: nil,
            outputTokenCount: nil,
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

    private func parseResponse(data: Data) throws -> String {
        // Format 1: OpenAI-compatible (router.huggingface.co/v1)
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = dict["choices"] as? [[String: Any]],
           let first = choices.first,
           let message = first["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Format 2: Array of objects with "generated_text"
        if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
           let first = array.first,
           let text = first["generated_text"] as? String {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Format 3: Single object with "generated_text"
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = dict["generated_text"] as? String {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
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

