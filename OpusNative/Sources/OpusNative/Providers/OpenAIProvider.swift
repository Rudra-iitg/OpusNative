import Foundation

// MARK: - OpenAI Provider

/// OpenAI Chat Completions API provider.
/// Supports streaming via SSE and vision via gpt-4o image URLs.
final class OpenAIProvider: AIProvider, @unchecked Sendable {
    let id = "openai"
    let displayName = "OpenAI"
    let supportsVision = true
    let supportsStreaming = true
    let supportsTools = true

    let availableModels = [
        "gpt-4o",
        "gpt-4o-mini",
        "gpt-4-turbo",
        "gpt-4",
        "gpt-3.5-turbo",
        "o1-preview",
        "o1-mini"
    ]

    private let baseURL = "https://api.openai.com/v1/chat/completions"
    private let session = URLSession.shared

    // MARK: - Send Message (Non-Streaming)

    func sendMessage(
        _ message: String,
        conversation: [MessageDTO],
        settings: ModelSettings
    ) async throws -> AIResponse {
        let apiKey = try getAPIKey()
        let startTime = CFAbsoluteTimeGetCurrent()

        let request = try buildRequest(
            message: message,
            conversation: conversation,
            settings: settings,
            apiKey: apiKey,
            stream: false
        )

        let (data, response) = try await session.data(for: request)
        let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProviderError.invalidResponse(provider: displayName, detail: "Not an HTTP response")
        }

        try handleHTTPErrors(httpResponse, data: data)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let msg = first["message"] as? [String: Any],
              let content = msg["content"] as? String else {
            throw AIProviderError.invalidResponse(provider: displayName, detail: "Could not parse response")
        }

        var tokenCount: Int?
        if let usage = json["usage"] as? [String: Any] {
            tokenCount = usage["total_tokens"] as? Int
        }

        let finishReason = first["finish_reason"] as? String

        return AIResponse(
            content: content,
            tokenCount: tokenCount,
            latencyMs: latency,
            model: settings.modelName,
            providerID: id,
            finishReason: finishReason
        )
    }

    // MARK: - Stream Message

    func streamMessage(
        _ message: String,
        conversation: [MessageDTO],
        settings: ModelSettings
    ) async throws -> AsyncThrowingStream<String, Error> {
        let apiKey = try getAPIKey()

        let request = try buildRequest(
            message: message,
            conversation: conversation,
            settings: settings,
            apiKey: apiKey,
            stream: true
        )

        let (byteStream, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProviderError.invalidResponse(provider: displayName, detail: "Not an HTTP response")
        }

        if !(200...299).contains(httpResponse.statusCode) {
            var errorData = Data()
            for try await byte in byteStream { errorData.append(byte) }
            let errorText = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw AIProviderError.serverError(statusCode: httpResponse.statusCode, message: errorText)
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in byteStream.lines {
                        if line.hasPrefix("data: ") {
                            let jsonStr = String(line.dropFirst(6))
                            if jsonStr.trimmingCharacters(in: .whitespaces) == "[DONE]" { break }

                            guard let data = jsonStr.data(using: .utf8),
                                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                  let choices = json["choices"] as? [[String: Any]],
                                  let first = choices.first,
                                  let delta = first["delta"] as? [String: Any],
                                  let content = delta["content"] as? String else {
                                continue
                            }

                            continuation.yield(content)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func getAPIKey() throws -> String {
        guard let key = KeychainService.shared.load(key: KeychainService.openaiAPIKey),
              !key.isEmpty else {
            throw AIProviderError.missingAPIKey(provider: displayName)
        }
        return key
    }

    private func buildRequest(
        message: String,
        conversation: [MessageDTO],
        settings: ModelSettings,
        apiKey: String,
        stream: Bool
    ) throws -> URLRequest {
        guard let url = URL(string: baseURL) else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        var messages: [[String: Any]] = []

        // System prompt
        if !settings.systemPrompt.isEmpty {
            messages.append(["role": "system", "content": settings.systemPrompt])
        }

        // Conversation history
        for msg in conversation {
            messages.append(["role": msg.role, "content": msg.content])
        }

        // New user message
        messages.append(["role": "user", "content": message])

        var body: [String: Any] = [
            "model": settings.modelName,
            "messages": messages,
            "max_tokens": settings.maxTokens,
            "temperature": settings.temperature,
            "top_p": settings.topP,
            "stream": stream
        ]

        // Stream options for usage in streaming mode
        if stream {
            body["stream_options"] = ["include_usage": true]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
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
