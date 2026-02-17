import Foundation
import Combine

/// Manages context window usage and limits for various models.
/// Provides estimates when exact token counts are unavailable.
@Observable
final class ContextManager {
    static let shared = ContextManager()
    
    // MARK: - State
    
    var currentUsage: Int = 0
    var usagePercentage: Double = 0.0
    var maxContext: Int = 128_000 // Default fallback
    
    // MARK: - Configuration
    
    /// Hardcoded limits for major models (safe lower bounds)
    private let modelLimits: [String: Int] = [
        // Anthropic
        "claude-3-5-sonnet-20240620": 200_000,
        "claude-3-opus-20240229": 200_000,
        "claude-3-haiku-20240307": 200_000,
        "claude-2.1": 200_000,
        
        // OpenAI
        "gpt-4o": 128_000,
        "gpt-4-turbo": 128_000,
        "gpt-4-turbo-preview": 128_000,
        "gpt-3.5-turbo": 16_000,
        
        // Google
        "gemini-1.5-pro": 2_000_000, // Actually 1M-2M, huge
        "gemini-1.5-flash": 1_000_000,
        
        // Local / Other (Conservative defaults)
        "llama3": 8_000,
        "mistral": 32_000,
        "grog-3": 128_000 // Hypothetical
    ]
    
    private init() {}
    
    // MARK: - Public API
    
    /// Update usage stats based on current conversation and model
    @MainActor
    func updateUsage(messages: [ChatMessage], model: String) {
        let limit = modelLimits[model] ?? modelLimits.first(where: { model.contains($0.key) })?.value ?? detectLimit(for: model)
        self.maxContext = limit
        
        // Calculate usage
        // 1. Sum known tokens from messages
        // 2. Estimate for messages without token counts (approx 4 chars/token)
        var total = 0
        for msg in messages {
            if let count = msg.tokenCount {
                total += count
            } else {
                // Heuristic estimation
                total += estimateTokens(text: msg.content)
            }
        }
        
        // Add safety buffer for system prompt/overhead (e.g. 500 tokens)
        total += 500
        
        self.currentUsage = total
        self.usagePercentage = Double(total) / Double(limit)
    }
    
    private func estimateTokens(text: String) -> Int {
        return Int(Double(text.count) / 3.5) // Rough approximation
    }
    
    private func detectLimit(for modelName: String) -> Int {
        let lower = modelName.lowercased()
        if lower.contains("128k") { return 128_000 }
        if lower.contains("32k") { return 32_000 }
        if lower.contains("16k") { return 16_000 }
        if lower.contains("flash") || lower.contains("pro") { return 1_000_000 } // Assumption for modern Gemini
        return 8_192 // Safe modern default
    }
}
