import Foundation
import SwiftUI
import SwiftData

/// Manages token usage tracking, cost estimation, and persistence.
@Observable
final class UsageManager {
    static let shared = UsageManager()
    
    /// Pricing configuration for known models
    /// Rates are per 1M tokens (USD)
    private(set) var pricing: [String: ModelPricing] = [
        // OpenAI
        "gpt-4o": ModelPricing(inputRate: 2.50, outputRate: 10.00),
        "gpt-4o-mini": ModelPricing(inputRate: 0.15, outputRate: 0.60),
        "gpt-4-turbo": ModelPricing(inputRate: 10.00, outputRate: 30.00),
        "o1-preview": ModelPricing(inputRate: 15.00, outputRate: 60.00),
        "o1-mini": ModelPricing(inputRate: 3.00, outputRate: 12.00),
        
        // Anthropic
        "claude-3-5-sonnet-20241022": ModelPricing(inputRate: 3.00, outputRate: 15.00),
        "claude-3-opus-20240229": ModelPricing(inputRate: 15.00, outputRate: 75.00),
        "claude-3-haiku-20240307": ModelPricing(inputRate: 0.25, outputRate: 1.25),
        
        // Google
        "gemini-1.5-pro": ModelPricing(inputRate: 3.50, outputRate: 10.50),
        "gemini-1.5-flash": ModelPricing(inputRate: 0.075, outputRate: 0.30),
        
        // Local (Free)
        "llama3": ModelPricing(inputRate: 0, outputRate: 0),
        "mistral": ModelPricing(inputRate: 0, outputRate: 0)
    ]
    
    /// Current session statistics
    var sessionUsage: UsageStats = .zero
    
    /// Lifetime statistics
    var lifetimeUsage: UsageStats = .zero
    
    /// Monthly statistics (Year-Month string -> Stats)
    var monthlyUsage: [String: UsageStats] = [:]
    
    private let defaults = UserDefaults.standard
    private let lifetimeKey = "usage_lifetime"
    private let monthlyKey = "usage_monthly"
    
    init() {
        loadData()
    }
    
    // MARK: - Tracking
    
    /// Track usage from an AI Response
    func track(response: AIResponse, providerID: String, modelContext: ModelContext? = nil) {
        let input = response.inputTokenCount ?? 0
        let output = response.outputTokenCount ?? 0
        
        let finalInput = input > 0 ? input : estimateTokens(response.content.count)
        
        let cost = calculateCost(input: finalInput, output: output, model: response.model)
        
        let stats = UsageStats(
            inputTokens: finalInput,
            outputTokens: output,
            totalCost: cost,
            requestCount: 1
        )
        
        updateStats(with: stats)
        
        if let context = modelContext {
            let record = UsageRecord(
                date: Date(),
                providerID: providerID,
                modelID: response.model,
                promptTokens: finalInput,
                completionTokens: output,
                totalCostUSD: Double(truncating: cost as NSNumber),
                requestCount: 1,
                avgLatencyMs: response.latencyMs ?? 0.0
            )
            context.insert(record)
            try? context.save()
        }
    }
    
    private func updateStats(with stats: UsageStats) {
        sessionUsage = sessionUsage + stats
        lifetimeUsage = lifetimeUsage + stats
        
        let monthKey = currentMonthKey()
        let currentMonth = monthlyUsage[monthKey] ?? .zero
        monthlyUsage[monthKey] = currentMonth + stats
        
        saveData()
    }
    
    // MARK: - Cost Calculation
    
    func calculateCost(input: Int, output: Int, model: String) -> Decimal {
        // Simple matching, ideally use fuzzy match or provider prefix handling
        // Normalize model name (remove provider prefix if present e.g. "anthropic/claude..." -> "claude...")
        let cleanModel = model.components(separatedBy: "/").last ?? model
        
        // Try exact match first
        if let price = pricing[cleanModel] {
            return price.calculateCost(input: input, output: output)
        }
        
        // Try to find by prefix (e.g. "gpt-4o" matches "gpt-4o-2024...")
        if let key = pricing.keys.first(where: { cleanModel.hasPrefix($0) }) {
            return pricing[key]!.calculateCost(input: input, output: output)
        }
        
        return 0
    }
    
    private func estimateTokens(_ charCount: Int) -> Int {
        return charCount / 4
    }
    
    private func currentMonthKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }
    
    // MARK: - Persistence
    
    private func saveData() {
        if let data = try? JSONEncoder().encode(lifetimeUsage) {
            defaults.set(data, forKey: lifetimeKey)
        }
        if let data = try? JSONEncoder().encode(monthlyUsage) {
            defaults.set(data, forKey: monthlyKey)
        }
    }
    
    private func loadData() {
        if let data = defaults.data(forKey: lifetimeKey),
           let stats = try? JSONDecoder().decode(UsageStats.self, from: data) {
            lifetimeUsage = stats
        }
        
        if let data = defaults.data(forKey: monthlyKey),
           let stats = try? JSONDecoder().decode([String: UsageStats].self, from: data) {
            monthlyUsage = stats
        }
    }
}
