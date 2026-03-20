import Foundation

// MARK: - Anthropic Provider

/// Anthropic Messages API provider (direct API, not Bedrock).
/// Supports streaming via SSE and vision via image content blocks.
final class AnthropicProvider: AIProvider, @unchecked Sendable {
    let id = "anthropic"
    let displayName = "Anthropic Claude"
    let supportsVision = true
    let supportsStreaming = true
    let supportsTools = true

    let availableModels = [
        "claude-sonnet-4-20250514",
        "claude-opus-4-20250514",
        "claude-haiku-3-20250414",
        "claude-3-5-sonnet-20241022",
        "claude-3-haiku-20240307"
    ]

    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let apiVersion = "2023-06-01"
    private let session = URLSession.shared
    private let keychain: KeychainService

    init(keychain: KeychainService) {
        self.keychain = keychain
    }

    // MARK: - Send Message (Non-Streaming)

    func sendMessage(
        _ message: String,
        conversation: [MessageDTO],
        images: [ImagePayload] = [],
        settings: ModelSettings
    ) async throws -> AIResponse {
        let apiKey = try getAPIKey()
        let startTime = CFAbsoluteTimeGetCurrent()

        let request = try buildRequest(
            message: message,
            conversation: conversation,
            images: images,
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
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw AIProviderError.invalidResponse(provider: displayName, detail: "Could not parse response body")
        }

        // Extract token usage
        // Extract token usage
        var inputTokens: Int?
        var outputTokens: Int?
        
        if let usage = json["usage"] as? [String: Any] {
            inputTokens = usage["input_tokens"] as? Int
            outputTokens = usage["output_tokens"] as? Int
        }

        let finishReason = (json["stop_reason"] as? String)

        return AIResponse(
            content: text,
            inputTokenCount: inputTokens,
            outputTokenCount: outputTokens,
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
        images: [ImagePayload] = [],
        settings: ModelSettings
    ) async throws -> AsyncThrowingStream<AIStreamChunk, Error> {
        let apiKey = try getAPIKey()

        let request = try buildRequest(
            message: message,
            conversation: conversation,
            images: images,
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

            if httpResponse.statusCode == 429 {
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                    .flatMap { Int($0) }
                throw AIProviderError.rateLimited(retryAfter: retryAfter)
            }

            throw AIProviderError.serverError(statusCode: httpResponse.statusCode, message: errorText)
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    var inputTokens = 0
                    var outputTokens = 0
                    
                    for try await line in byteStream.lines {
                        if line.hasPrefix("data: ") {
                            let jsonStr = String(line.dropFirst(6))
                            if jsonStr.trimmingCharacters(in: .whitespaces) == "[DONE]" { break }

                            guard let data = jsonStr.data(using: .utf8),
                                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                                continue
                            }

                            let type = json["type"] as? String ?? ""

                            if type == "message_start",
                               let message = json["message"] as? [String: Any],
                               let usage = message["usage"] as? [String: Any],
                               let input = usage["input_tokens"] as? Int {
                                inputTokens = input
                            }
                            
                            if type == "message_delta",
                               let usage = json["usage"] as? [String: Any],
                               let output = usage["output_tokens"] as? Int {
                                outputTokens = output
                                // message_delta is usually the end of usage updates
                                continuation.yield(.usage(input: inputTokens, output: outputTokens))
                            }

                            if type == "content_block_delta",
                               let delta = json["delta"] as? [String: Any],
                               let text = delta["text"] as? String {
                                continuation.yield(.content(text))
                            }

                            if type == "error",
                               let error = json["error"] as? [String: Any],
                               let msg = error["message"] as? String {
                                continuation.finish(throwing: AIProviderError.serverError(statusCode: 0, message: msg))
                                return
                            }
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
        guard let key = keychain.load(key: KeychainService.anthropicAPIKey),
              !key.isEmpty else {
            throw AIProviderError.missingAPIKey(provider: displayName)
        }
        return key
    }

    private func buildRequest(
        message: String,
        conversation: [MessageDTO],
        images: [ImagePayload] = [],
        settings: ModelSettings,
        apiKey: String,
        stream: Bool
    ) throws -> URLRequest {
        guard let url = URL(string: baseURL) else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")

        // Build messages array
        var messages: [[String: Any]] = conversation.map { msg in
            ["role": msg.role, "content": msg.content]
        }

        // Build the current user message content
        if images.isEmpty {
            messages.append(["role": "user", "content": message])
        } else {
            var contentBlocks: [[String: Any]] = images.map { payload in
                [
                    "type": "image",
                    "source": [
                        "type": "base64",
                        "media_type": payload.mimeType,
                        "data": payload.data.base64EncodedString()
                    ] as [String: Any]
                ]
            }
            contentBlocks.append(["type": "text", "text": message])
            messages.append(["role": "user", "content": contentBlocks])
        }

        var body: [String: Any] = [
            "model": settings.modelName,
            "max_tokens": settings.maxTokens,
            "temperature": settings.temperature,
            "top_p": settings.topP,
            "messages": messages,
            "stream": stream
        ]

        if !settings.systemPrompt.isEmpty {
            body["system"] = settings.systemPrompt
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func handleHTTPErrors(_ response: HTTPURLResponse, data: Data) throws {
        guard !(200...299).contains(response.statusCode) else { return }

        let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"

        if response.statusCode == 429 {
            // Read retry-after from HTTP response headers (not the JSON body)
            let retryAfter = response.value(forHTTPHeaderField: "Retry-After")
                .flatMap { Int($0) }
            throw AIProviderError.rateLimited(retryAfter: retryAfter)
        }

        throw AIProviderError.serverError(statusCode: response.statusCode, message: errorText)
    }
}
