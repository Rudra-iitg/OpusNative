import Foundation

// MARK: - AI Response

/// Unified response from any AI provider.
struct AIResponse: Sendable {
    /// The text content of the response
    let content: String

    /// Approximate token count (input + output) if available
    var tokenCount: Int {
        return (inputTokenCount ?? 0) + (outputTokenCount ?? 0)
    }
    
    /// Input (Prompt) tokens
    let inputTokenCount: Int?
    
    /// Output (Completion) tokens
    let outputTokenCount: Int?

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
        inputTokenCount: Int? = nil,
        outputTokenCount: Int? = nil,
        latencyMs: Double = 0,
        model: String = "",
        providerID: String = "",
        finishReason: String? = nil
    ) {
        self.content = content
        self.inputTokenCount = inputTokenCount
        self.outputTokenCount = outputTokenCount
        self.latencyMs = latencyMs
        self.model = model
        self.providerID = providerID
        self.finishReason = finishReason
    }
}
