import Foundation
import SwiftData
import SwiftUI

/// Central Dependency Injection Container for OpusNative.
/// This replaces the heavy reliance on global `.shared` singletons and allows for easier testing and mocking.
@MainActor
@Observable
final class AppDIContainer {
    
    // Core Managers & Services
    let aiManager: AIManager
    let themeManager: ThemeManager
    let pluginManager: PluginManager
    let usageManager: UsageManager
    let observabilityManager: ObservabilityManager
    let performanceManager: PerformanceManager
    let contextManager: ContextManager
    let keychainService: KeychainService
    let requestQueue: RequestQueue
    
    // Feature Services
    let embeddingService: EmbeddingService
    let vectorStore: VectorStore
    let reportGenerator: ReportGenerator
    let s3BackupManager: S3BackupManager
    
    init() {
        // Initialize all dependencies. In a real testing environment, we could pass mock versions here.
        // For now, we still instantiate the concrete instances, but we'll stop using their `shared` properties globally.
        self.keychainService = KeychainService()
        self.observabilityManager = ObservabilityManager()
        self.performanceManager = PerformanceManager()
        self.usageManager = UsageManager()
        self.themeManager = ThemeManager()
        self.pluginManager = PluginManager()
        self.contextManager = ContextManager()
        self.requestQueue = RequestQueue()
        
        self.aiManager = AIManager(keychain: keychainService)
        self.embeddingService = EmbeddingService()
        self.vectorStore = VectorStore()
        self.reportGenerator = ReportGenerator()
        self.s3BackupManager = S3BackupManager()
        
        // Handle cyclic dependencies
        self.pluginManager.diContainer = self
        self.s3BackupManager.aiManager = aiManager
        self.aiManager.pluginManager = self.pluginManager
        
        // Skip plugin loading during unit tests to prevent crashes
        guard NSClassFromString("XCTestCase") == nil else { return }
        
        // Start plugin loading now that DI is wired up
        Task { @MainActor in
            self.pluginManager.loadPlugins()
            self.pluginManager.startWatching()
        }
    }
}
