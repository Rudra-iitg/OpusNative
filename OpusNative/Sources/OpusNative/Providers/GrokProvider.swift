import Foundation

// MARK: - Grok (xAI) Provider

/// xAI Grok API provider. Uses OpenAI-compatible chat completions endpoint.
final class GrokProvider: AIProvider, @unchecked Sendable {
    let id = "grok"
    let displayName = "Grok"
    let supportsVision = true
    let supportsStreaming = false
    let supportsTools = false

    let availableModels = [
        "grok-3",
        "grok-3-fast",
        "grok-3-mini",
        "grok-3-mini-fast",
        "grok-2",
        "grok-2-vision"
    ]

    private let baseURL = "https://api.x.ai/v1/chat/completions"
    private let session = URLSession.shared

    // MARK: - Send Message

    func sendMessage(
        _ message: String,
        conversation: [MessageDTO],
        settings: ModelSettings
    ) async throws -> AIResponse {
        let apiKey = try getAPIKey()
        let startTime = CFAbsoluteTimeGetCurrent()

        guard let url = URL(string: baseURL) else {
            throw AIProviderError.modelNotAvailable(model: settings.modelName)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // Build messages array (OpenAI-compatible)
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
            "temperature": settings.temperature,
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

        // Parse response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let messageObj = first["message"] as? [String: Any],
              let content = messageObj["content"] as? String else {
            throw AIProviderError.invalidResponse(provider: displayName, detail: "Could not parse response")
        }
        
        // Usage
        var inputTokens: Int?
        var outputTokens: Int?
        if let usage = json["usage"] as? [String: Any] {
            inputTokens = usage["prompt_tokens"] as? Int
            outputTokens = usage["completion_tokens"] as? Int
        }

        return AIResponse(
            content: content,
            inputTokenCount: inputTokens,
            outputTokenCount: outputTokens,
            latencyMs: latency,
            model: settings.modelName,
            providerID: id,
            finishReason: (first["finish_reason"] as? String)
        )
    }

    private func getAPIKey() throws -> String {
        guard let key = KeychainService.shared.load(key: KeychainService.grokAPIKey),
              !key.isEmpty else {
            throw AIProviderError.missingAPIKey(provider: displayName)
        }
        return key
    }

    private func handleHTTPErrors(_ response: HTTPURLResponse, data: Data) throws {
        guard !(200...299).contains(response.statusCode) else { return }

        let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"

        if response.statusCode == 429 {
            throw AIProviderError.rateLimited(retryAfter: nil)
        }

        throw AIProviderError.serverError(statusCode: response.statusCode, message: errorText)
    }
}
