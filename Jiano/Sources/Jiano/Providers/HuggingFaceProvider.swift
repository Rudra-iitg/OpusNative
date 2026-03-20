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

    var selectedModelId: String {
        UserDefaults.standard.string(forKey: "huggingface_selected_model") ?? "mistralai/Mistral-7B-Instruct-v0.3"
    }

    var availableModels: [String] {
        [selectedModelId]
    }
    
    var useOpenAICompatibleAPI: Bool = true
    
    enum APIFormat {
        case openAICompatible
        case legacy
    }
    
    private var modelFormatCache: [String: APIFormat] = [:]
    
    private let session = URLSession.shared
    
    private let keychain: KeychainService
    
    init(keychain: KeychainService) {
        self.keychain = keychain
    }

    // MARK: - Send Message

    func sendMessage(
        _ message: String,
        conversation: [MessageDTO],
        images: [ImagePayload] = [],
        settings: ModelSettings
    ) async throws -> AIResponse {
        let token = try getAPIKey()
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let model = selectedModelId
        let format = modelFormatCache[model] ?? .openAICompatible
        
        if format == .openAICompatible {
            do {
                return try await sendOpenAICompatible(model: model, message: message, conversation: conversation, settings: settings, token: token, startTime: startTime)
            } catch let error as AIProviderError {
                if case .serverError(let statusCode, _) = error, statusCode == 404 {
                    modelFormatCache[model] = .legacy
                    useOpenAICompatibleAPI = false
                    return try await sendLegacy(model: model, message: message, conversation: conversation, settings: settings, token: token, startTime: startTime)
                } else if case .invalidResponse = error {
                    modelFormatCache[model] = .legacy
                    useOpenAICompatibleAPI = false
                    return try await sendLegacy(model: model, message: message, conversation: conversation, settings: settings, token: token, startTime: startTime)
                } else {
                    throw error
                }
            } catch {
                throw error
            }
        } else {
            return try await sendLegacy(model: model, message: message, conversation: conversation, settings: settings, token: token, startTime: startTime)
        }
    }
    
    private func sendOpenAICompatible(model: String, message: String, conversation: [MessageDTO], settings: ModelSettings, token: String, startTime: CFAbsoluteTime) async throws -> AIResponse {
        guard let url = URL(string: "https://router.huggingface.co/v1/chat/completions") else {
            throw AIProviderError.modelNotAvailable(model: model)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        var messages: [[String: String]] = []

        if !settings.systemPrompt.isEmpty {
            messages.append(["role": "system", "content": settings.systemPrompt])
        }
        for msg in conversation {
            messages.append(["role": msg.role, "content": msg.content])
        }
        messages.append(["role": "user", "content": message])

        let body: [String: Any] = [
            "model": model,
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
        let content = try parseResponse(data: data)
        
        modelFormatCache[model] = .openAICompatible
        useOpenAICompatibleAPI = true

        return AIResponse(
            content: content,
            inputTokenCount: nil,
            outputTokenCount: nil,
            latencyMs: latency,
            model: model,
            providerID: id,
            finishReason: nil
        )
    }

    private func sendLegacy(model: String, message: String, conversation: [MessageDTO], settings: ModelSettings, token: String, startTime: CFAbsoluteTime) async throws -> AIResponse {
        guard let encodedId = model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://router.huggingface.co/models/\(encodedId)") else {
            throw AIProviderError.modelNotAvailable(model: model)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // Construct input string for legacy models
        var prompt = ""
        if !settings.systemPrompt.isEmpty {
            prompt += "System: \(settings.systemPrompt)\n"
        }
        for msg in conversation {
            let role = msg.role == "user" ? "Human" : "Assistant"
            prompt += "\(role): \(msg.content)\n"
        }
        prompt += "Human: \(message)\nAssistant:"

        let body: [String: Any] = [
            "inputs": prompt,
            "parameters": [
                "max_new_tokens": settings.maxTokens,
                "temperature": max(settings.temperature, 0.01),
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

        let content = try parseResponse(data: data)

        return AIResponse(
            content: content,
            inputTokenCount: nil,
            outputTokenCount: nil,
            latencyMs: latency,
            model: model,
            providerID: id,
            finishReason: nil
        )
    }

    // MARK: - Private Helpers

    private func getAPIKey() throws -> String {
        guard let token = keychain.load(key: KeychainService.huggingfaceToken),
              !token.isEmpty else {
            throw AIProviderError.missingAPIKey(provider: displayName)
        }
        return token
    }

    private func parseResponse(data: Data) throws -> String {
        // Format 1: OpenAI-compatible (router.huggingface.co/v1 or api-inference)
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
                    message: "Model is loading on HuggingFace servers. Estimated wait: \(Int(estimatedTime))s. Try again shortly."
                )
            }
        }

        if response.statusCode == 429 {
            throw AIProviderError.rateLimited(retryAfter: nil)
        }

        throw AIProviderError.serverError(statusCode: response.statusCode, message: errorText)
    }
}
