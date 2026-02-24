import Foundation

// MARK: - Plugin Manifest

/// JSON-defined plugin schema for runtime provider registration.
/// Users drop a `.json` file into `~/Library/Application Support/OpusNative/plugins/`
/// and OpusNative automatically loads it as a new provider.
///
/// Example plugin JSON:
/// ```json
/// {
///   "id": "together-ai",
///   "name": "Together AI",
///   "version": "1.0",
///   "provider": {
///     "baseURL": "https://api.together.xyz/v1",
///     "authType": "bearer",
///     "authKeyName": "together_api_key",
///     "models": ["meta-llama/Llama-3-70b-chat-hf", "mistralai/Mixtral-8x7B-Instruct-v0.1"],
///     "supportsStreaming": true,
///     "requestFormat": "openai-compatible"
///   }
/// }
/// ```
struct PluginManifest: Codable, Sendable {
    /// Unique identifier (used as providerID)
    let id: String

    /// Human-readable name
    let name: String

    /// Semantic version
    let version: String

    /// Provider configuration (nil if this plugin doesn't add a provider)
    let provider: ProviderPluginConfig?
}

/// Configuration for a custom API provider plugin
struct ProviderPluginConfig: Codable, Sendable {
    /// Base URL of the API endpoint
    let baseURL: String

    /// Authentication type: "bearer", "api-key-header", or "none"
    let authType: String

    /// Keychain key name for the API key (user sets this in Settings)
    let authKeyName: String?

    /// Available model IDs
    let models: [String]

    /// Whether this API supports streaming responses
    let supportsStreaming: Bool

    /// Request format: "openai-compatible" or "anthropic-compatible"
    let requestFormat: String

    /// Custom headers to include with every request (optional)
    let customHeaders: [String: String]?

    /// Custom request body fields to merge (optional)
    let customBodyFields: [String: String]?
}
