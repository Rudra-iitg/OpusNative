import Foundation

/// Statistics for token usage and cost
struct UsageStats: Codable, Sendable {
    var inputTokens: Int
    var outputTokens: Int
    var totalCost: Decimal
    var requestCount: Int
    
    var totalTokens: Int {
        inputTokens + outputTokens
    }
    
    static let zero = UsageStats(inputTokens: 0, outputTokens: 0, totalCost: 0, requestCount: 0)
    
    static func + (lhs: UsageStats, rhs: UsageStats) -> UsageStats {
        UsageStats(
            inputTokens: lhs.inputTokens + rhs.inputTokens,
            outputTokens: lhs.outputTokens + rhs.outputTokens,
            totalCost: lhs.totalCost + rhs.totalCost,
            requestCount: lhs.requestCount + rhs.requestCount
        )
    }
}

/// Pricing configuration for a specific model
struct ModelPricing: Codable, Sendable {
    /// Cost per 1 million input tokens
    let inputRate: Decimal
    
    /// Cost per 1 million output tokens
    let outputRate: Decimal
    
    /// Currency code (default USD)
    var currency: String = "USD"
    
    func calculateCost(input: Int, output: Int) -> Decimal {
        let inputCost = (Decimal(input) / 1_000_000) * inputRate
        let outputCost = (Decimal(output) / 1_000_000) * outputRate
        return inputCost + outputCost
    }
}
