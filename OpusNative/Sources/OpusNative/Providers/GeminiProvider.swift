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

    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"
    private let session = URLSession.shared

    // MARK: - Send Message

    func sendMessage(
        _ message: String,
        conversation: [MessageDTO],
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
            contents.append([
                "role": role,
                "parts": [["text": msg.content]]
            ])
        }

        contents.append([
            "role": "user",
            "parts": [["text": message]]
        ])

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

        var tokenCount: Int?
        if let usageMetadata = json["usageMetadata"] as? [String: Any] {
            tokenCount = usageMetadata["totalTokenCount"] as? Int
        }

        return AIResponse(
            content: text,
            tokenCount: tokenCount,
            latencyMs: latency,
            model: settings.modelName,
            providerID: id,
            finishReason: nil
        )
    }

    // MARK: - Private Helpers

    private func getAPIKey() throws -> String {
        guard let key = KeychainService.shared.load(key: KeychainService.geminiAPIKey),
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
