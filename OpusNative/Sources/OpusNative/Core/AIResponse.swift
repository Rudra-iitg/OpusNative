import Foundation

// MARK: - AI Response

/// Unified response from any AI provider.
struct AIResponse: Sendable {
    /// The text content of the response
    let content: String

    /// Approximate token count (input + output) if available
    let tokenCount: Int?

    /// Response latency in milliseconds
    let latencyMs: Double

    /// Model identifier that generated this response
    let model: String

    /// Provider identifier (matches AIProvider.id)
    let providerID: String

    /// Optional finish reason (e.g., "stop", "max_tokens")
    let finishReason: String?

    init(
        content: String,
        tokenCount: Int? = nil,
        latencyMs: Double = 0,
        model: String = "",
        providerID: String = "",
        finishReason: String? = nil
    ) {
        self.content = content
        self.tokenCount = tokenCount
        self.latencyMs = latencyMs
        self.model = model
        self.providerID = providerID
        self.finishReason = finishReason
    }
}
