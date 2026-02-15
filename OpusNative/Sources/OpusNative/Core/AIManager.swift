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

    // MARK: - Ollama Dynamic Models

    /// Fetched Ollama model metadata (name, size, etc.)
    var ollamaModels: [OllamaModelInfo] = []

    /// Whether Ollama models are currently being fetched
    var isLoadingOllamaModels: Bool = false

    /// Error message from the last Ollama model fetch attempt
    var ollamaModelError: String?

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

        // Auto-fetch Ollama models when switching to Ollama
        if id == "ollama" && ollamaModels.isEmpty {
            Task { await fetchOllamaModels() }
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

    // MARK: - Ollama Model Fetching

    /// Fetch available Ollama models from the local /api/tags endpoint.
    /// Updates `ollamaModels`, auto-selects first model if needed.
    func fetchOllamaModels() async {
        guard let ollamaProvider = provider(for: "ollama") as? OllamaProvider else { return }

        isLoadingOllamaModels = true
        ollamaModelError = nil

        do {
            let models = try await ollamaProvider.fetchAvailableModels()
            ollamaModels = models

            // Auto-select first model if current selection is invalid
            if activeProviderID == "ollama" {
                let modelNames = models.map(\.name)
                if !modelNames.contains(settings.modelName), let first = modelNames.first {
                    settings.modelName = first
                }
            }
        } catch {
            ollamaModelError = error.localizedDescription
        }

        isLoadingOllamaModels = false
    }

    /// Force refresh Ollama models, clearing cached data first
    func refreshOllamaModels() async {
        ollamaModels = []
        await fetchOllamaModels()
    }

    /// Available models for the active provider — uses dynamic list for Ollama
    var activeProviderModels: [String] {
        if activeProviderID == "ollama" && !ollamaModels.isEmpty {
            return ollamaModels.map(\.name)
        }
        return activeProvider?.availableModels ?? []
    }

    /// Get OllamaModelInfo for a specific model name (for size display)
    func ollamaModelInfo(for name: String) -> OllamaModelInfo? {
        ollamaModels.first { $0.name == name }
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

