import Foundation

// MARK: - Message DTO (Sendable transfer type)

/// Lightweight, Sendable message type used to pass conversation history across
/// concurrency boundaries. Providers receive this instead of SwiftData's
/// non-Sendable `ChatMessage` model objects.
struct MessageDTO: Sendable {
    let role: String     // "user", "assistant", or "system"
    let content: String
}

// MARK: - AI Provider Protocol

/// Core protocol that all AI providers must conform to.
/// Provides a unified interface for sending messages across different AI services.
protocol AIProvider: Sendable {
    /// Unique identifier for this provider (e.g., "anthropic", "openai")
    var id: String { get }

    /// Human-readable display name (e.g., "Anthropic Claude")
    var displayName: String { get }

    /// Whether this provider supports image/vision inputs
    var supportsVision: Bool { get }

    /// Whether this provider supports streaming responses
    var supportsStreaming: Bool { get }

    /// Whether this provider supports tool/function calling
    var supportsTools: Bool { get }

    /// List of available model IDs for this provider
    var availableModels: [String] { get }

    /// Send a message and receive a complete response
    func sendMessage(
        _ message: String,
        conversation: [MessageDTO],
        settings: ModelSettings
    ) async throws -> AIResponse

    /// Stream a response token-by-token (default implementation calls sendMessage)
    func streamMessage(
        _ message: String,
        conversation: [MessageDTO],
        settings: ModelSettings
    ) async throws -> AsyncThrowingStream<String, Error>
}

// MARK: - Default Streaming Implementation

extension AIProvider {
    /// Default implementation wraps sendMessage into a single-yield stream
    func streamMessage(
        _ message: String,
        conversation: [MessageDTO],
        settings: ModelSettings
    ) async throws -> AsyncThrowingStream<String, Error> {
        let response = try await sendMessage(message, conversation: conversation, settings: settings)
        return AsyncThrowingStream { continuation in
            continuation.yield(response.content)
            continuation.finish()
        }
    }
}

// MARK: - ChatMessage convenience

extension ChatMessage {
    /// Convert a SwiftData ChatMessage to a Sendable MessageDTO
    var toDTO: MessageDTO {
        MessageDTO(role: role, content: content)
    }
}


// MARK: - Provider Error

enum AIProviderError: LocalizedError {
    case missingAPIKey(provider: String)
    case invalidResponse(provider: String, detail: String)
    case networkError(underlying: Error)
    case rateLimited(retryAfter: Int?)
    case modelNotAvailable(model: String)
    case unsupportedFeature(feature: String)
    case serverError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "\(provider) API key not configured. Open Settings (⌘,) to add it."
        case .invalidResponse(let provider, let detail):
            return "\(provider) returned an invalid response: \(detail)"
        case .networkError(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Rate limited. Try again in \(seconds) seconds."
            }
            return "Rate limited. Please try again later."
        case .modelNotAvailable(let model):
            return "Model \"\(model)\" is not available."
        case .unsupportedFeature(let feature):
            return "This provider does not support \(feature)."
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        }
    }
}
