import Foundation

// MARK: - Universal OpenAI Compatible Provider

/// Base class for any provider that exposes an OpenAI-compatible /v1/chat/completions endpoint.
/// Can be used directly or subclassed by specific providers (e.g., OpenRouter, LM Studio).
class OpenAICompatibleProvider: AIProvider, @unchecked Sendable {
    let id: String
    let displayName: String
    var baseURL: String
    
    var supportsVision: Bool = true
    var supportsStreaming: Bool = true
    var supportsTools: Bool = true
    
    var availableModels: [String]
    let defaultModel: String
    
    private let session = URLSession.shared
    
    /// Stored apiKey, or you can override `getAPIKey()` if it needs to be fetched dynamically
    var apiKey: String

    init(id: String = UUID().uuidString, name: String, baseURL: String, apiKey: String, defaultModel: String, availableModels: [String] = []) {
        self.id = id
        self.displayName = name
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.defaultModel = defaultModel
        self.availableModels = availableModels.isEmpty ? [defaultModel] : availableModels
    }

    // MARK: - Overridable Extension Points
    
    /// Override to provide custom headers (like OpenRouter's HTTP-Referer)
    func customHeaders() -> [String: String] {
        return [:]
    }
    
    /// Override to fetch API key dynamically from keychain
    func getAPIKey() throws -> String {
        return apiKey
    }

    // MARK: - Send Message (Non-Streaming)

    func sendMessage(
        _ message: String,
        conversation: [MessageDTO],
        settings: ModelSettings
    ) async throws -> AIResponse {
        let key = try getAPIKey()
        let startTime = CFAbsoluteTimeGetCurrent()

        let request = try buildRequest(
            message: message,
            conversation: conversation,
            settings: settings,
            apiKey: key,
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

        var inputTokens: Int?
        var outputTokens: Int?
        
        if let usage = json["usage"] as? [String: Any] {
            inputTokens = usage["prompt_tokens"] as? Int
            outputTokens = usage["completion_tokens"] as? Int
        }

        let finishReason = first["finish_reason"] as? String
        let modelUsed = (json["model"] as? String) ?? settings.modelName

        return AIResponse(
            content: content,
            inputTokenCount: inputTokens,
            outputTokenCount: outputTokens,
            latencyMs: latency,
            model: modelUsed,
            providerID: id,
            finishReason: finishReason
        )
    }

    // MARK: - Stream Message

    func streamMessage(
        _ message: String,
        conversation: [MessageDTO],
        settings: ModelSettings
    ) async throws -> AsyncThrowingStream<AIStreamChunk, Error> {
        let key = try getAPIKey()

        let request = try buildRequest(
            message: message,
            conversation: conversation,
            settings: settings,
            apiKey: key,
            stream: true
        )

        let (byteStream, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProviderError.invalidResponse(provider: displayName, detail: "Not an HTTP response")
        }

        if !(200...299).contains(httpResponse.statusCode) {
            var errorData = Data()
            for try await byte in byteStream { errorData.append(byte) }
            try handleHTTPErrors(httpResponse, data: errorData)
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in byteStream.lines {
                        if line.hasPrefix("data: ") {
                            let jsonStr = String(line.dropFirst(6))
                            if jsonStr.trimmingCharacters(in: .whitespaces) == "[DONE]" { break }

                            guard let data = jsonStr.data(using: .utf8),
                                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                                continue
                            }
                            
                            if let choices = json["choices"] as? [[String: Any]],
                               let first = choices.first {
                                
                                // Check for content delta
                                if let delta = first["delta"] as? [String: Any],
                                   let content = delta["content"] as? String {
                                    continuation.yield(.content(content))
                                }
                            }
                            
                            // Check for usage in stream chunk
                            if let usage = json["usage"] as? [String: Any],
                               let input = usage["prompt_tokens"] as? Int,
                               let output = usage["completion_tokens"] as? Int {
                                continuation.yield(.usage(input: input, output: output))
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

    private func buildRequest(
        message: String,
        conversation: [MessageDTO],
        settings: ModelSettings,
        apiKey: String,
        stream: Bool
    ) throws -> URLRequest {
        var urlString = baseURL
        if !urlString.hasSuffix("/v1/chat/completions") {
            if !urlString.hasSuffix("/") { urlString += "/" }
            urlString += "v1/chat/completions"
        }
        
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        for (key, value) in customHeaders() {
            request.setValue(value, forHTTPHeaderField: key)
        }

        var messages: [[String: Any]] = []

        if !settings.systemPrompt.isEmpty {
            messages.append(["role": "system", "content": settings.systemPrompt])
        }

        for msg in conversation {
            messages.append(["role": msg.role, "content": msg.content])
        }

        messages.append(["role": "user", "content": message])

        var body: [String: Any] = [
            "model": settings.modelName.isEmpty ? defaultModel : settings.modelName,
            "messages": messages,
            "max_tokens": settings.maxTokens,
            "temperature": settings.temperature,
            "top_p": settings.topP,
            "stream": stream
        ]

        if stream {
            body["stream_options"] = ["include_usage": true]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func handleHTTPErrors(_ response: HTTPURLResponse, data: Data) throws {
        guard !(200...299).contains(response.statusCode) else { return }

        let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errorObj = json["error"] as? [String: Any],
           let message = errorObj["message"] as? String {
            throw AIProviderError.serverError(statusCode: response.statusCode, message: message)
        }

        if response.statusCode == 429 {
            throw AIProviderError.rateLimited(retryAfter: nil)
        }

        throw AIProviderError.serverError(statusCode: response.statusCode, message: errorText)
    }
}
