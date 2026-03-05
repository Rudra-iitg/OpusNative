import Foundation

enum ModelCapability: String, Codable, Sendable, Hashable {
    case vision
    case toolUse
    case json
    case reasoning
}

struct ModelInfo: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let displayName: String
    let provider: String
    let contextWindow: Int
    let inputCostPer1MTokens: Double
    let outputCostPer1MTokens: Double
    let capabilities: Set<ModelCapability>
    
    var formatPricing: String {
        return "$\(inputCostPer1MTokens) / $\(outputCostPer1MTokens) per 1M"
    }
}

/// Centralized registry of known AI models
struct ModelRegistry {
    
    static let knownModels: [ModelInfo] = [
        // MARK: Anthropic
        ModelInfo(
            id: "claude-opus-4-6",
            displayName: "Claude Opus 4.6",
            provider: "Anthropic",
            contextWindow: 200_000,
            inputCostPer1MTokens: 15.0,
            outputCostPer1MTokens: 75.0,
            capabilities: [.vision, .toolUse, .json, .reasoning]
        ),
        ModelInfo(
            id: "claude-sonnet-4-5",
            displayName: "Claude Sonnet 4.5",
            provider: "Anthropic",
            contextWindow: 200_000,
            inputCostPer1MTokens: 3.0,
            outputCostPer1MTokens: 15.0,
            capabilities: [.vision, .toolUse, .json]
        ),
        ModelInfo(
            id: "claude-haiku-3-5",
            displayName: "Claude Haiku 3.5",
            provider: "Anthropic",
            contextWindow: 200_000,
            inputCostPer1MTokens: 0.25,
            outputCostPer1MTokens: 1.25,
            capabilities: [.vision, .toolUse, .json]
        ),
        
        // MARK: OpenAI
        ModelInfo(
            id: "gpt-4o",
            displayName: "GPT-4o",
            provider: "OpenAI",
            contextWindow: 128_000,
            inputCostPer1MTokens: 5.0,
            outputCostPer1MTokens: 15.0,
            capabilities: [.vision, .toolUse, .json]
        ),
        ModelInfo(
            id: "gpt-4o-mini",
            displayName: "GPT-4o Mini",
            provider: "OpenAI",
            contextWindow: 128_000,
            inputCostPer1MTokens: 0.15,
            outputCostPer1MTokens: 0.60,
            capabilities: [.vision, .toolUse, .json]
        ),
        ModelInfo(
            id: "o1",
            displayName: "o1",
            provider: "OpenAI",
            contextWindow: 128_000,
            inputCostPer1MTokens: 15.0,
            outputCostPer1MTokens: 60.0,
            capabilities: [.vision, .reasoning]
        ),
        ModelInfo(
            id: "o3-mini",
            displayName: "o3-mini",
            provider: "OpenAI",
            contextWindow: 200_000,
            inputCostPer1MTokens: 1.10,
            outputCostPer1MTokens: 4.40,
            capabilities: [.reasoning, .toolUse]
        ),
        
        // MARK: Google
        ModelInfo(
            id: "gemini-2.0-flash",
            displayName: "Gemini 2.0 Flash",
            provider: "Google",
            contextWindow: 1_000_000,
            inputCostPer1MTokens: 0.15,
            outputCostPer1MTokens: 0.60,
            capabilities: [.vision, .toolUse, .json]
        ),
        ModelInfo(
            id: "gemini-1.5-pro",
            displayName: "Gemini 1.5 Pro",
            provider: "Google",
            contextWindow: 2_000_000,
            inputCostPer1MTokens: 3.50,
            outputCostPer1MTokens: 10.50,
            capabilities: [.vision, .toolUse, .json]
        ),
        
        // MARK: xAI
        ModelInfo(
            id: "grok-2",
            displayName: "Grok-2",
            provider: "xAI",
            contextWindow: 128_000,
            inputCostPer1MTokens: 5.0,
            outputCostPer1MTokens: 15.0,
            capabilities: [.vision, .toolUse]
        ),
        ModelInfo(
            id: "grok-2-mini",
            displayName: "Grok-2 Mini",
            provider: "xAI",
            contextWindow: 128_000,
            inputCostPer1MTokens: 1.50,
            outputCostPer1MTokens: 4.50,
            capabilities: [.vision, .toolUse]
        ),
        
        // MARK: Meta (OpenRouter)
        ModelInfo(
            id: "meta-llama/llama-3.3-70b-instruct",
            displayName: "Llama 3.3 70B",
            provider: "OpenRouter (Meta)",
            contextWindow: 128_000,
            inputCostPer1MTokens: 0.13,
            outputCostPer1MTokens: 0.40,
            capabilities: [.toolUse, .json]
        ),
        ModelInfo(
            id: "meta-llama/llama-3.1-8b-instruct",
            displayName: "Llama 3.1 8B",
            provider: "OpenRouter (Meta)",
            contextWindow: 128_000,
            inputCostPer1MTokens: 0.05,
            outputCostPer1MTokens: 0.08,
            capabilities: [.toolUse, .json]
        ),
        
        // MARK: DeepSeek (OpenRouter)
        ModelInfo(
            id: "deepseek/deepseek-r1",
            displayName: "DeepSeek R1",
            provider: "OpenRouter (DeepSeek)",
            contextWindow: 64_000,
            inputCostPer1MTokens: 0.14,
            outputCostPer1MTokens: 2.19,
            capabilities: [.reasoning]
        ),
        ModelInfo(
            id: "deepseek/deepseek-chat",
            displayName: "DeepSeek V3",
            provider: "OpenRouter (DeepSeek)",
            contextWindow: 64_000,
            inputCostPer1MTokens: 0.14,
            outputCostPer1MTokens: 0.28,
            capabilities: [.toolUse, .json]
        ),
        
        // MARK: Mistral (OpenRouter)
        ModelInfo(
            id: "mistralai/mistral-large-2411",
            displayName: "Mistral Large",
            provider: "OpenRouter (Mistral)",
            contextWindow: 128_000,
            inputCostPer1MTokens: 2.00,
            outputCostPer1MTokens: 6.00,
            capabilities: [.toolUse, .json]
        ),
        ModelInfo(
            id: "mistralai/mistral-small-24b-instruct-2501",
            displayName: "Mistral Small",
            provider: "OpenRouter (Mistral)",
            contextWindow: 32_000,
            inputCostPer1MTokens: 0.07,
            outputCostPer1MTokens: 0.14,
            capabilities: [.toolUse, .json]
        ),
        
        // MARK: Alibaba (OpenRouter)
        ModelInfo(
            id: "qwen/qwen-2.5-72b-instruct",
            displayName: "Qwen 2.5 72B",
            provider: "OpenRouter (Alibaba)",
            contextWindow: 128_000,
            inputCostPer1MTokens: 0.12,
            outputCostPer1MTokens: 0.35,
            capabilities: [.toolUse, .json, .vision]
        )
    ]
    
    /// Get model info if it exists
    static func getModelInfo(for id: String) -> ModelInfo? {
        // Find exact match
        if let exact = knownModels.first(where: { $0.id == id }) {
            return exact
        }
        
        // Fallback for partial matches (like deepseek-r1 without producer prefix)
        return knownModels.first { $0.id.contains(id) }
    }
}
