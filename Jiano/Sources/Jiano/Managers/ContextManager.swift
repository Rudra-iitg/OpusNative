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
    var manualOverride: Int? = nil
    
    var isManualOverride: Bool { manualOverride != nil }

    /// Global default context window limit, persisted in UserDefaults.
    /// A value of 0 means auto-detect; positive values are the limit in tokens.
    var globalDefaultLimit: Int {
        get { UserDefaults.standard.integer(forKey: "contextWindowGlobalDefault") }
        set { UserDefaults.standard.set(newValue, forKey: "contextWindowGlobalDefault") }
    }

    @MainActor
    func clearOverride() {
        manualOverride = nil
    }
    
    // MARK: - Configuration
    
    /// Hardcoded limits for major models (safe lower bounds)
    private let modelLimits: [String: Int] = [
        // Anthropic (current models from AnthropicProvider.availableModels)
        "claude-sonnet-4-20250514": 200_000,
        "claude-opus-4-20250514": 200_000,
        "claude-haiku-3-20250414": 200_000,
        "claude-3-5-sonnet-20241022": 200_000,
        "claude-3-haiku-20240307": 200_000,
        // Legacy Anthropic model IDs (backward compatibility)
        "claude-3-5-sonnet-20240620": 200_000,
        "claude-3-opus-20240229": 200_000,
        "claude-2.1": 200_000,
        
        // AWS Bedrock Anthropic
        "us.anthropic.claude-sonnet-4-20250514-v1:0": 200_000,
        
        // OpenAI
        "gpt-4o": 128_000,
        "gpt-4-turbo": 128_000,
        "gpt-4-turbo-preview": 128_000,
        "gpt-4o-mini": 128_000,
        "gpt-3.5-turbo": 16_000,
        "o1": 200_000,
        "o1-preview": 128_000,
        "o1-mini": 128_000,
        
        // Google Gemini
        "gemini-1.5-pro": 2_000_000,
        "gemini-1.5-flash": 1_000_000,
        "gemini-2.5-flash-preview-05-20": 1_000_000,
        "gemini-2.0-flash": 1_000_000,
        "gemini-2.0-flash-lite": 1_000_000,
        "gemini-2.5-pro-preview-05-06": 2_000_000,
        
        // Grok
        "grok-3": 128_000,
        "grok-2": 131_072,
        "grok-2-1212": 131_072,
        "grok-beta": 131_072,
        
        // Moonshot / Kimi
        "moonshotai/kimi-k2-instruct": 131_072,
        "kimi-k2-instruct": 131_072,
        
        // Local / Other (Conservative defaults)
        "llama3": 8_000,
        "mistral": 32_000,
        "gemma3:latest": 128_000,
        "codellama": 16_384,
    ]
    
    // MARK: - Presets

    struct ContextPreset: Identifiable {
        let id: UUID = UUID()
        let label: String
        let tokens: Int
    }

    static let presets: [ContextPreset] = [
        ContextPreset(label: "Auto",  tokens: 0),
        ContextPreset(label: "4k",    tokens: 4_096),
        ContextPreset(label: "8k",    tokens: 8_192),
        ContextPreset(label: "16k",   tokens: 16_384),
        ContextPreset(label: "32k",   tokens: 32_768),
        ContextPreset(label: "64k",   tokens: 65_536),
        ContextPreset(label: "128k",  tokens: 131_072),
        ContextPreset(label: "200k",  tokens: 200_000),
        ContextPreset(label: "1M",    tokens: 1_000_000),
        ContextPreset(label: "2M",    tokens: 2_000_000),
    ]

    init() {}
    
    // MARK: - Public API

    /// Resolves the effective context window limit for a given model using a priority chain:
    /// 1. manualOverride (if set and > 0)
    /// 2. globalDefaultLimit (if > 0)
    /// 3. Exact match in modelLimits
    /// 4. Case-insensitive partial key match in modelLimits
    /// 5. detectLimit(for:) heuristic (includes 128k fallback)
    public func resolveLimit(for model: String) -> Int {
        if let override = manualOverride, override > 0 {
            return override
        }
        if globalDefaultLimit > 0 {
            return globalDefaultLimit
        }
        if let exact = modelLimits[model] {
            return exact
        }
        if let partial = modelLimits.first(where: { model.lowercased().contains($0.key.lowercased()) })?.value {
            return partial
        }
        return detectLimit(for: model)
    }

    /// Update usage stats based on current conversation and model
    @MainActor
    func updateUsage(messages: [ChatMessage], model: String) {
        let limit = resolveLimit(for: model)
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
        if lower.contains("claude") { return 200_000 }
        if lower.contains("gpt-4") { return 128_000 }
        if lower.contains("gemini") { return 1_000_000 }
        if lower.contains("flash") { return 1_000_000 }
        if lower.contains("128k") { return 128_000 }
        if lower.contains("32k") { return 32_000 }
        if lower.contains("16k") { return 16_000 }
        return 128_000 // Modern default fallback
    }
}
