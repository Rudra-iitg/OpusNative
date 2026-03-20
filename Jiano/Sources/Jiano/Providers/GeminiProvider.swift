import Foundation

// MARK: - Google Gemini Provider

/// Google Gemini API provider using the Generative Language REST API.
/// Uses OpenAI-compatible endpoint via generativelanguage.googleapis.com.
final class GeminiProvider: AIProvider, @unchecked Sendable {
    let id = "gemini"
    let displayName = "Gemini"
    let supportsVision = true
    let supportsStreaming = false
    let supportsTools = false

    let availableModels = [
        "gemini-2.5-flash-preview-05-20",
        "gemini-2.5-pro-preview-05-06",
        "gemini-2.0-flash",
        "gemini-2.0-flash-lite",
        "gemini-1.5-pro",
        "gemini-1.5-flash"
    ]

    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"
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
        let apiKey = try getAPIKey()
        let startTime = CFAbsoluteTimeGetCurrent()

        let endpoint = "\(baseURL)/models/\(settings.modelName):generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else {
            throw AIProviderError.modelNotAvailable(model: settings.modelName)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build contents array
        var contents: [[String: Any]] = []

        for msg in conversation {
            let role = msg.role == "assistant" ? "model" : "user"
            var parts: [[String: Any]] = []
            // Include any images stored on history messages
            for img in msg.images {
                parts.append([
                    "inlineData": [
                        "mimeType": img.mimeType,
                        "data": img.data.base64EncodedString()
                    ]
                ])
            }
            parts.append(["text": msg.content])
            contents.append(["role": role, "parts": parts])
        }

        // Build current user message parts (images first, then text)
        var userParts: [[String: Any]] = images.map { img in
            [
                "inlineData": [
                    "mimeType": img.mimeType,
                    "data": img.data.base64EncodedString()
                ]
            ]
        }
        userParts.append(["text": message])
        contents.append(["role": "user", "parts": userParts])

        var body: [String: Any] = [
            "contents": contents,
            "generationConfig": [
                "temperature": settings.temperature,
                "maxOutputTokens": settings.maxTokens,
                "topP": settings.topP
            ]
        ]

        // System instruction
        if !settings.systemPrompt.isEmpty {
            body["systemInstruction"] = [
                "parts": [["text": settings.systemPrompt]]
            ]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProviderError.invalidResponse(provider: displayName, detail: "Not an HTTP response")
        }

        try handleHTTPErrors(httpResponse, data: data)

        // Parse Gemini response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw AIProviderError.invalidResponse(provider: displayName, detail: "Could not parse response")
        }

        // Parse usage metadata
        let usageMeta = json["usageMetadata"] as? [String: Any]
        let inputTokens = usageMeta?["promptTokenCount"] as? Int
        let outputTokens = usageMeta?["candidatesTokenCount"] as? Int

        return AIResponse(
            content: text,
            inputTokenCount: inputTokens,
            outputTokenCount: outputTokens,
            latencyMs: latency,
            model: settings.modelName,
            providerID: id,
            finishReason: nil
        )
    }

    // MARK: - Private Helpers

    private func getAPIKey() throws -> String {
        guard let key = keychain.load(key: KeychainService.geminiAPIKey),
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
