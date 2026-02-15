import Foundation

// MARK: - AI Manager

/// Central manager for all AI providers.
/// Registers providers, manages active provider selection, and persists settings.
@Observable
@MainActor
final class AIManager {
    static let shared = AIManager()

    /// All registered providers
    private(set) var providers: [any AIProvider] = []

    /// Currently selected provider ID
    var activeProviderID: String {
        didSet {
            UserDefaults.standard.set(activeProviderID, forKey: "activeProviderID")
        }
    }

    /// Model settings for the active provider
    var settings: ModelSettings {
        didSet {
            saveSettings()
        }
    }

    /// Per-provider settings cache
    private var providerSettings: [String: ModelSettings] = [:]

    private init() {
        let savedProvider = UserDefaults.standard.string(forKey: "activeProviderID") ?? "anthropic"
        self.activeProviderID = savedProvider
        self.settings = ModelSettings.defaultFor(providerID: savedProvider)
        loadSettings()
        registerDefaultProviders()
    }

    // MARK: - Provider Registration

    func register(provider: any AIProvider) {
        guard !providers.contains(where: { $0.id == provider.id }) else { return }
        providers.append(provider)
    }

    func unregister(providerID: String) {
        providers.removeAll { $0.id == providerID }
    }

    /// Get a provider by its ID
    func provider(for id: String) -> (any AIProvider)? {
        providers.first { $0.id == id }
    }

    /// The currently active provider instance
    var activeProvider: (any AIProvider)? {
        provider(for: activeProviderID)
    }

    /// Switch to a different provider, loading its saved settings
    func switchProvider(to id: String) {
        // Save current settings
        providerSettings[activeProviderID] = settings

        activeProviderID = id

        // Load saved settings or defaults
        if let saved = providerSettings[id] {
            settings = saved
        } else {
            settings = loadSettingsFor(providerID: id)
        }
    }

    /// Providers that are configured (have API keys set)
    var configuredProviders: [any AIProvider] {
        providers.filter { isProviderConfigured($0.id) }
    }

    /// Check if a provider has its required credentials configured
    func isProviderConfigured(_ providerID: String) -> Bool {
        switch providerID {
        case "anthropic":
            return KeychainService.shared.load(key: KeychainService.anthropicAPIKey) != nil
        case "openai":
            return KeychainService.shared.load(key: KeychainService.openaiAPIKey) != nil
        case "huggingface":
            return KeychainService.shared.load(key: KeychainService.huggingfaceToken) != nil
        case "ollama":
            return true // Local, no API key needed
        case "bedrock":
            let access = KeychainService.shared.load(key: KeychainService.accessKeyID)
            let secret = KeychainService.shared.load(key: KeychainService.secretAccessKey)
            return access != nil && secret != nil
        default:
            return false
        }
    }

    // MARK: - Settings Persistence

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "modelSettings_\(activeProviderID)")
        }
    }

    private func loadSettings() {
        settings = loadSettingsFor(providerID: activeProviderID)
    }

    private func loadSettingsFor(providerID: String) -> ModelSettings {
        if let data = UserDefaults.standard.data(forKey: "modelSettings_\(providerID)"),
           let saved = try? JSONDecoder().decode(ModelSettings.self, from: data) {
            return saved
        }
        return ModelSettings.defaultFor(providerID: providerID)
    }

    // MARK: - Default Providers

    private func registerDefaultProviders() {
        register(provider: AnthropicProvider())
        register(provider: OpenAIProvider())
        register(provider: HuggingFaceProvider())
        register(provider: OllamaProvider())
        register(provider: AWSBedrockProvider())
    }
}
