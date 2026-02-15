import Foundation

// MARK: - Ollama API Response Models

/// Response from GET /api/tags — lists locally installed Ollama models.
struct OllamaTagResponse: Codable, Sendable {
    let models: [OllamaModelInfo]
}

/// Metadata for a single locally installed Ollama model.
struct OllamaModelInfo: Codable, Sendable, Identifiable {
    var id: String { name }
    let name: String
    let model: String?
    let size: Int?

    /// Human-readable size string (e.g., "3.1 GB")
    var formattedSize: String {
        guard let size else { return "" }
        let gb = Double(size) / 1_000_000_000
        if gb >= 1.0 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(size) / 1_000_000
        return String(format: "%.0f MB", mb)
    }

    /// Whether this model is large (>10 GB)
    var isLargeModel: Bool {
        guard let size else { return false }
        return size > 10_000_000_000
    }

    /// Whether this is an embedding-only model (should be filtered from chat)
    var isEmbeddingModel: Bool {
        name.lowercased().contains("embedding") ||
        name.lowercased().contains("embed")
    }
}

// MARK: - Ollama Provider

/// Local Ollama provider via localhost API.
/// Dynamically fetches installed models from /api/tags.
/// Full streaming support via NDJSON, configurable base URL.
final class OllamaProvider: AIProvider, @unchecked Sendable {
    let id = "ollama"
    let displayName = "Ollama (Local)"
    let supportsVision = true
    let supportsStreaming = true
    let supportsTools = false

    /// Fallback models shown when Ollama is not reachable
    var availableModels: [String] {
        if !_fetchedModels.isEmpty {
            return _fetchedModels.map(\.name)
        }
        return _fallbackModels
    }

    /// Fetched model metadata (includes size, etc.)
    private(set) var _fetchedModels: [OllamaModelInfo] = []

    /// Static fallback list — only used if Ollama is unreachable
    private let _fallbackModels = [
        "llama3",
        "gemma3:latest",
        "mistral",
        "codellama",
        "phi3"
    ]

    private let session = URLSession.shared

    /// Get the configured Ollama base URL (defaults to localhost)
    var baseURL: String {
        let saved = KeychainService.shared.load(key: KeychainService.ollamaBaseURL)
        if let url = saved, !url.isEmpty {
            return url.hasSuffix("/") ? String(url.dropLast()) : url
        }
        return "http://localhost:11434"
    }

    // MARK: - Fetch Available Models

    /// Fetches locally installed models from Ollama's /api/tags endpoint.
    /// Filters out embedding models automatically.
    /// - Returns: Array of OllamaModelInfo for chat-capable models
    /// - Throws: AIProviderError if connection fails or response is invalid
    func fetchAvailableModels() async throws -> [OllamaModelInfo] {
        let endpoint = "\(baseURL)/api/tags"
        guard let url = URL(string: endpoint) else {
            throw AIProviderError.serverError(statusCode: 0, message: "Invalid Ollama URL: \(endpoint)")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIProviderError.invalidResponse(provider: displayName, detail: "Not an HTTP response")
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw AIProviderError.serverError(statusCode: httpResponse.statusCode, message: errorText)
            }

            let tagResponse = try JSONDecoder().decode(OllamaTagResponse.self, from: data)

            // Filter out embedding models
            let chatModels = tagResponse.models.filter { !$0.isEmbeddingModel }

            // Cache the fetched models
            _fetchedModels = chatModels

            return chatModels
        } catch let error as AIProviderError {
            throw error
        } catch let error as DecodingError {
            throw AIProviderError.invalidResponse(
                provider: displayName,
                detail: "Invalid JSON from Ollama: \(error.localizedDescription)"
            )
        } catch {
            let nsError = error as NSError
            if nsError.code == NSURLErrorCannotConnectToHost ||
               nsError.code == NSURLErrorTimedOut ||
               nsError.code == NSURLErrorNetworkConnectionLost ||
               nsError.domain == NSURLErrorDomain {
                throw AIProviderError.serverError(
                    statusCode: 0,
                    message: "Cannot connect to Ollama at \(baseURL). Is Ollama running? Start it with 'ollama serve'."
                )
            }
            throw AIProviderError.networkError(underlying: error)
        }
    }

    // MARK: - Send Message (Non-Streaming)

    func sendMessage(
        _ message: String,
        conversation: [MessageDTO],
        settings: ModelSettings
    ) async throws -> AIResponse {
        let startTime = CFAbsoluteTimeGetCurrent()

        let request = try buildRequest(
            message: message,
            conversation: conversation,
            settings: settings,
            stream: false
        )

        let (data, response) = try await session.data(for: request)
        let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProviderError.invalidResponse(provider: displayName, detail: "Not an HTTP response")
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIProviderError.serverError(statusCode: httpResponse.statusCode, message: errorText)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messageObj = json["message"] as? [String: Any],
              let content = messageObj["content"] as? String else {
            throw AIProviderError.invalidResponse(provider: displayName, detail: "Could not parse response")
        }

        // Ollama provides eval_count (output tokens) and prompt_eval_count (input tokens)
        var tokenCount: Int?
        if let evalCount = json["eval_count"] as? Int {
            let promptCount = json["prompt_eval_count"] as? Int ?? 0
            tokenCount = promptCount + evalCount
        }

        return AIResponse(
            content: content,
            tokenCount: tokenCount,
            latencyMs: latency,
            model: settings.modelName,
            providerID: id,
            finishReason: "stop"
        )
    }

    // MARK: - Stream Message

    func streamMessage(
        _ message: String,
        conversation: [MessageDTO],
        settings: ModelSettings
    ) async throws -> AsyncThrowingStream<String, Error> {
        let request = try buildRequest(
            message: message,
            conversation: conversation,
            settings: settings,
            stream: true
        )

        let (byteStream, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProviderError.invalidResponse(provider: displayName, detail: "Not an HTTP response")
        }

        if !(200...299).contains(httpResponse.statusCode) {
            var errorData = Data()
            for try await byte in byteStream { errorData.append(byte) }
            let errorText = String(data: errorData, encoding: .utf8) ?? "Ollama connection failed"
            throw AIProviderError.serverError(statusCode: httpResponse.statusCode, message: errorText)
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // Ollama streams NDJSON (one JSON object per line)
                    for try await line in byteStream.lines {
                        guard !line.isEmpty,
                              let data = line.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                            continue
                        }

                        // Check if stream is done
                        if let done = json["done"] as? Bool, done {
                            break
                        }

                        // Extract content delta
                        if let message = json["message"] as? [String: Any],
                           let content = message["content"] as? String {
                            continuation.yield(content)
                        }
                    }
                    continuation.finish()
                } catch {
                    // Connection refused = Ollama not running
                    if (error as NSError).code == NSURLErrorCannotConnectToHost ||
                       (error as NSError).code == NSURLErrorNetworkConnectionLost {
                        continuation.finish(throwing: AIProviderError.serverError(
                            statusCode: 0,
                            message: "Cannot connect to Ollama at \(self.baseURL). Is Ollama running?"
                        ))
                    } else {
                        continuation.finish(throwing: error)
                    }
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func buildRequest(
        message: String,
        conversation: [MessageDTO],
        settings: ModelSettings,
        stream: Bool
    ) throws -> URLRequest {
        let endpoint = "\(baseURL)/api/chat"
        guard let url = URL(string: endpoint) else {
            throw AIProviderError.serverError(statusCode: 0, message: "Invalid Ollama URL: \(endpoint)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120  // Local models can be slow

        // Build messages
        var messages: [[String: Any]] = []

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
            "stream": stream,
            "options": [
                "temperature": settings.temperature,
                "top_p": settings.topP,
                "num_predict": settings.maxTokens
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }
}
