import Foundation

// MARK: - Generic API Provider

/// A configurable AIProvider that uses a plugin manifest to communicate with
/// any OpenAI-compatible or Anthropic-compatible API endpoint.
/// This is the runtime bridge between plugin JSON manifests and the AIProvider protocol.
struct GenericAPIProvider: AIProvider, Sendable {
    let id: String
    let displayName: String
    let supportsVision: Bool = false
    let supportsStreaming: Bool
    let supportsTools: Bool = false
    let availableModels: [String]

    private let config: ProviderPluginConfig
    private let keychain: KeychainService

    init(pluginID: String, pluginName: String, config: ProviderPluginConfig, keychain: KeychainService) {
        self.id = pluginID
        self.displayName = pluginName
        self.supportsStreaming = config.supportsStreaming
        self.availableModels = config.models
        self.config = config
        self.keychain = keychain
    }

    // MARK: - AIProvider

    func sendMessage(
        _ message: String,
        conversation: [MessageDTO],
        settings: ModelSettings
    ) async throws -> AIResponse {
        // Resolve API key
        let apiKey = resolveAPIKey()
        let startTime = CFAbsoluteTimeGetCurrent()

        // Build request based on format
        let (request, body) = try buildRequest(
            message: message,
            conversation: conversation,
            settings: settings,
            apiKey: apiKey
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProviderError.invalidResponse(provider: displayName, detail: "Not an HTTP response")
        }

        // Handle rate limiting
        if httpResponse.statusCode == 429 {
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
            throw AIProviderError.rateLimited(retryAfter: retryAfter)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIProviderError.serverError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        // Parse response based on format
        return try parseResponse(data: data, latency: latency, settings: settings)
    }

    // MARK: - Request Building

    private func buildRequest(
        message: String,
        conversation: [MessageDTO],
        settings: ModelSettings,
        apiKey: String?
    ) throws -> (URLRequest, Data) {
        let baseURL = config.baseURL.hasSuffix("/") ? String(config.baseURL.dropLast()) : config.baseURL

        var request: URLRequest
        var body: [String: Any]

        switch config.requestFormat {
        case "openai-compatible":
            request = URLRequest(url: URL(string: "\(baseURL)/chat/completions")!)

            var messages: [[String: String]] = []
            if !settings.systemPrompt.isEmpty {
                messages.append(["role": "system", "content": settings.systemPrompt])
            }
            for msg in conversation {
                messages.append(["role": msg.role, "content": msg.content])
            }
            messages.append(["role": "user", "content": message])

            body = [
                "model": settings.modelName,
                "messages": messages,
                "max_tokens": settings.maxTokens,
                "temperature": settings.temperature,
                "top_p": settings.topP
            ]

        case "anthropic-compatible":
            request = URLRequest(url: URL(string: "\(baseURL)/messages")!)

            var messages: [[String: String]] = []
            for msg in conversation {
                messages.append(["role": msg.role, "content": msg.content])
            }
            messages.append(["role": "user", "content": message])

            body = [
                "model": settings.modelName,
                "messages": messages,
                "max_tokens": settings.maxTokens,
                "temperature": settings.temperature
            ]

            if !settings.systemPrompt.isEmpty {
                body["system"] = settings.systemPrompt
            }

        default:
            // Default to OpenAI-compatible
            request = URLRequest(url: URL(string: "\(baseURL)/chat/completions")!)
            var messages: [[String: String]] = []
            for msg in conversation {
                messages.append(["role": msg.role, "content": msg.content])
            }
            messages.append(["role": "user", "content": message])
            body = ["model": settings.modelName, "messages": messages, "max_tokens": settings.maxTokens]
        }

        // Set auth header
        switch config.authType {
        case "bearer":
            if let key = apiKey {
                request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            }
        case "api-key-header":
            if let key = apiKey {
                request.setValue(key, forHTTPHeaderField: "x-api-key")
            }
        default:
            break
        }

        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Apply custom headers
        if let customHeaders = config.customHeaders {
            for (key, value) in customHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        let jsonData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = jsonData

        return (request, jsonData)
    }

    // MARK: - Response Parsing

    private func parseResponse(data: Data, latency: Double, settings: ModelSettings) throws -> AIResponse {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIProviderError.invalidResponse(provider: displayName, detail: "Invalid JSON")
        }

        // Try OpenAI format first
        if let choices = json["choices"] as? [[String: Any]],
           let first = choices.first,
           let message = first["message"] as? [String: Any],
           let content = message["content"] as? String {

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
                finishReason: first["finish_reason"] as? String
            )
        }

        // Try Anthropic format
        if let contentArray = json["content"] as? [[String: Any]],
           let first = contentArray.first,
           let text = first["text"] as? String {

            var inputTokens: Int?
            var outputTokens: Int?
            if let usage = json["usage"] as? [String: Any] {
                inputTokens = usage["input_tokens"] as? Int
                outputTokens = usage["output_tokens"] as? Int
            }

            return AIResponse(
                content: text,
                inputTokenCount: inputTokens,
                outputTokenCount: outputTokens,
                latencyMs: latency,
                model: settings.modelName,
                providerID: id,
                finishReason: json["stop_reason"] as? String
            )
        }

        throw AIProviderError.invalidResponse(provider: displayName, detail: "Unrecognized response format")
    }

    // MARK: - API Key

    private func resolveAPIKey() -> String? {
        guard let keyName = config.authKeyName else { return nil }
        return keychain.load(key: keyName)
    }
}
