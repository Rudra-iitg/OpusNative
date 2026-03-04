import Foundation

// MARK: - Plugin Manager

/// Loads plugin manifests from the plugins directory and registers providers at runtime.
/// Watches for file changes to hot-reload plugins without app restart.
@Observable
@MainActor
final class PluginManager {
    static let shared = PluginManager()

    /// All loaded plugin manifests
    private(set) var plugins: [PluginManifest] = []

    /// Errors encountered during plugin loading
    private(set) var loadErrors: [String: String] = [:]
    var diContainer: AppDIContainer!
    
    init() {}

    /// Whether plugins are currently being loaded
    var isLoading = false

    /// File system watcher for hot-reload
    private var fileWatcher: DispatchSourceFileSystemObject?
    private var watcherFD: Int32 = -1

    private let pluginDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("OpusNative/plugins", isDirectory: true)
    }()

    // MARK: - Loading

    /// Load all plugins from the plugins directory
    func loadPlugins() {
        isLoading = true
        loadErrors = [:]

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)

        // Find all .json files
        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(at: pluginDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }
        } catch {
            loadErrors["directory"] = "Failed to read plugins directory: \(error.localizedDescription)"
            isLoading = false
            return
        }

        var loadedPlugins: [PluginManifest] = []

        for file in files {
            do {
                let data = try Data(contentsOf: file)
                let manifest = try JSONDecoder().decode(PluginManifest.self, from: data)

                // Validate manifest
                guard !manifest.id.isEmpty else {
                    loadErrors[file.lastPathComponent] = "Plugin ID is empty"
                    continue
                }

                // Check for duplicates
                guard !loadedPlugins.contains(where: { $0.id == manifest.id }) else {
                    loadErrors[file.lastPathComponent] = "Duplicate plugin ID: \(manifest.id)"
                    continue
                }

                loadedPlugins.append(manifest)

            } catch {
                loadErrors[file.lastPathComponent] = "Parse error: \(error.localizedDescription)"
            }
        }

        plugins = loadedPlugins

        // Register providers
        registerProviders()

        isLoading = false
    }

    /// Register all plugin providers with AIManager
    private func registerProviders() {
        let aiManager = diContainer.aiManager

        for plugin in plugins {
            guard let config = plugin.provider else { continue }

            // Skip if already registered
            guard aiManager.provider(for: plugin.id) == nil else { continue }

            let provider = GenericAPIProvider(
                pluginID: plugin.id,
                pluginName: plugin.name,
                config: config,
                keychain: diContainer.keychainService
            )
            aiManager.register(provider: provider)
        }
    }

    // MARK: - File Watching (Hot Reload)

    /// Start watching the plugins directory for changes
    func startWatching() {
        stopWatching()

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)

        watcherFD = open(pluginDirectory.path, O_EVTONLY)
        guard watcherFD >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: watcherFD,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.loadPlugins()
            }
        }

        source.setCancelHandler { [weak self] in
            if let fd = self?.watcherFD, fd >= 0 {
                close(fd)
            }
            self?.watcherFD = -1
        }

        source.resume()
        fileWatcher = source
    }

    /// Stop watching for file changes
    func stopWatching() {
        fileWatcher?.cancel()
        fileWatcher = nil
    }

    // MARK: - Queries

    /// Get the plugin manifest for a given provider ID
    func plugin(for providerID: String) -> PluginManifest? {
        plugins.first { $0.id == providerID }
    }

    /// The plugins directory path (for display in UI)
    var pluginDirectoryPath: String {
        pluginDirectory.path
    }

    /// Whether a provider is plugin-based
    func isPluginProvider(_ providerID: String) -> Bool {
        plugins.contains { $0.id == providerID }
    }
}
