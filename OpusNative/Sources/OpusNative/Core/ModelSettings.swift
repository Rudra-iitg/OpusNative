import Foundation

// MARK: - Model Settings

/// Configurable parameters for AI model inference.
/// Shared across all providers; individual providers may ignore unsupported fields.
struct ModelSettings: Sendable, Codable {
    /// Sampling temperature (0.0 = deterministic, 1.0 = creative)
    var temperature: Double = 0.7

    /// Maximum number of tokens to generate
    var maxTokens: Int = 4096

    /// Nucleus sampling parameter (0.0–1.0)
    var topP: Double = 1.0

    /// Model name/ID to use (provider-specific)
    var modelName: String = ""

    /// System prompt / persona
    var systemPrompt: String = ""

    /// Whether to use streaming (if provider supports it)
    var useStreaming: Bool = true

    // MARK: - Defaults per Provider

    static func defaultFor(providerID: String) -> ModelSettings {
        switch providerID {
        case "anthropic":
            return ModelSettings(
                temperature: 0.7,
                maxTokens: 4096,
                topP: 1.0,
                modelName: "claude-sonnet-4-20250514",
                useStreaming: true
            )
        case "openai":
            return ModelSettings(
                temperature: 0.7,
                maxTokens: 4096,
                topP: 1.0,
                modelName: "gpt-4o",
                useStreaming: true
            )
        case "huggingface":
            return ModelSettings(
                temperature: 0.7,
                maxTokens: 1024,
                topP: 0.9,
                modelName: "mistralai/Mistral-7B-Instruct-v0.2",
                useStreaming: false
            )
        case "ollama":
            return ModelSettings(
                temperature: 0.7,
                maxTokens: 4096,
                topP: 1.0,
                modelName: "llama3",
                useStreaming: true
            )
        case "bedrock":
            return ModelSettings(
                temperature: 0.7,
                maxTokens: 4096,
                topP: 1.0,
                modelName: "us.anthropic.claude-sonnet-4-20250514-v1:0",
                useStreaming: true
            )
        default:
            return ModelSettings()
        }
    }
}
