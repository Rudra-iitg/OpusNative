import Foundation

// MARK: - AI Manager

/// Central manager for all AI providers.
/// Registers providers, manages active provider selection, and persists settings.
@Observable
@MainActor
final class AIManager {
    // static let shared removed for pure DI

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
    
    let keychain: KeychainService
    
    /// Reference to PluginManager for checking if a provider is plugin-based
    weak var pluginManager: PluginManager?

    init(keychain: KeychainService) {
        self.keychain = keychain
        let savedProvider = UserDefaults.standard.string(forKey: "activeProviderID") ?? "anthropic"
        self.activeProviderID = savedProvider
        self.settings = ModelSettings.defaultFor(providerID: savedProvider)
        loadSettings()
        registerDefaultProviders()
        observeGenericEndpoints()

        // Plugin loading is now handled by AppDIContainer after all dependencies are set up
    }

    // MARK: - Generic Endpoint Live Sync

    private var endpointObservationTask: Task<Void, Never>?

    /// Watches GenericEndpointManager for changes and keeps AIManager.providers in sync.
    private func observeGenericEndpoints() {
        endpointObservationTask = Task { [weak self] in
            var lastEndpoints: [SavedEndpoint] = GenericEndpointManager.shared.endpoints
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000) // poll every 0.5s
                guard let self else { return }
                let current = GenericEndpointManager.shared.endpoints
                guard current != lastEndpoints else { continue }
                await MainActor.run { self.syncGenericProviders(current) }
                lastEndpoints = current
            }
        }
    }

    /// Reconciles AIManager.providers with the given endpoint list.
    private func syncGenericProviders(_ endpoints: [SavedEndpoint]) {
        let currentIDs = Set(endpoints.map { "generic-\($0.id.uuidString)" })
        let registeredGenericIDs = Set(providers.compactMap { p -> String? in
            p.id.hasPrefix("generic-") ? p.id : nil
        })

        // Remove deleted endpoints
        for id in registeredGenericIDs.subtracting(currentIDs) {
            unregister(providerID: id)
            if activeProviderID == id {
                switchProvider(to: "anthropic")
            }
        }

        // Add or update endpoints
        for endpoint in endpoints {
            let pid = "generic-\(endpoint.id.uuidString)"
            unregister(providerID: pid) // remove stale version if present
            register(provider: GenericOpenAICompatibleProvider(endpoint: endpoint))
        }
    }
    
    deinit {
        // We do not have single saved task, but any unstructured tasks like Task { await fetchOllamaModels() }
        // should ideally be tracked. Since it's a one-off fetch, it usually finishes quickly.
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
        ObservabilityManager.shared.log("Switched provider to \(id)", level: .info, subsystem: "AIManager")

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
            return keychain.load(key: KeychainService.anthropicAPIKey) != nil
        case "openai":
            return keychain.load(key: KeychainService.openaiAPIKey) != nil
        case "huggingface":
            return keychain.load(key: KeychainService.huggingfaceToken) != nil
        case "ollama":
            return true // Local, no API key needed
        case "bedrock":
            let access = keychain.load(key: KeychainService.accessKeyID)
            let secret = keychain.load(key: KeychainService.secretAccessKey)
            return access != nil && secret != nil
        case "gemini":
            return keychain.load(key: KeychainService.geminiAPIKey) != nil
        case "grok":
            return keychain.load(key: KeychainService.grokAPIKey) != nil
        case "openrouter":
            return keychain.load(key: KeychainService.openRouterAPIKey) != nil
        case "litellm", "lmstudio":
            return true
        case "azure-openai":
            let key = keychain.load(key: KeychainService.azureOpenAIAPIKey)
            let resource = UserDefaults.standard.string(forKey: "azureOpenAIResourceName")
            let deployment = UserDefaults.standard.string(forKey: "azureOpenAIDeploymentName")
            return key != nil && resource?.isEmpty == false && deployment?.isEmpty == false
        default:
            if providerID.hasPrefix("generic-") {
                return true
            }
            // Check if it's a plugin provider
            if let pm = pluginManager, pm.isPluginProvider(providerID) {
                if let plugin = pm.plugin(for: providerID),
                   let keyName = plugin.provider?.authKeyName {
                    return plugin.provider?.authType == "none" || keychain.load(key: keyName) != nil
                }
                return true
            }
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
        register(provider: AnthropicProvider(keychain: keychain))
        register(provider: OpenAIProvider(keychain: keychain))
        register(provider: GeminiProvider(keychain: keychain))
        register(provider: GrokProvider(keychain: keychain))
        register(provider: HuggingFaceProvider(keychain: keychain))
        register(provider: OllamaProvider(keychain: keychain))
        register(provider: AWSBedrockProvider(keychain: keychain))
        
        register(provider: OpenRouterProvider(keychain: keychain))
        register(provider: LiteLLMProvider(keychain: keychain))
        register(provider: LMStudioProvider())
        register(provider: AzureOpenAIProvider(keychain: keychain))
        
        for endpoint in GenericEndpointManager.shared.endpoints {
            register(provider: GenericOpenAICompatibleProvider(endpoint: endpoint))
        }
    }
}

