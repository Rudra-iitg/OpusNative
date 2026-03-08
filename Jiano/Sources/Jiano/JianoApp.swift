import SwiftUI
import SwiftData

@main
struct OpusNativeApp: App {
    /// Whether we're running inside XCTest (test host mode)
    static let isRunningTests: Bool = {
        NSClassFromString("XCTestCase") != nil
    }()

    /// Optional model container — nil if creation failed
    let sharedModelContainer: ModelContainer?
    /// Error message if model container creation failed
    let containerError: String?
    
    @State private var diContainer = AppDIContainer()

    init() {
        // When launched as a test host, skip heavy SwiftData initialization
        // to prevent crashes in the test runner
        guard !Self.isRunningTests else {
            self.sharedModelContainer = nil
            self.containerError = "Running in test mode"
            return
        }

        let schema = Schema([
            Conversation.self,
            ChatMessage.self,
            EmbeddingItem.self,
            EmbeddingCollection.self,
            PromptEntry.self,
            ResponseEvaluation.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            self.sharedModelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            self.containerError = nil
        } catch {
            self.sharedModelContainer = nil
            self.containerError = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            rootView
        }
        .defaultSize(width: 1100, height: 750)

        Settings {
            settingsView
        }
    }

    @ViewBuilder
    private var rootView: some View {
        if let container = sharedModelContainer {
            ContentView(diContainer: diContainer)
                .modelContainer(container)
                .environment(diContainer)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    Task { await diContainer.vectorStore.flush() }
                    diContainer.observabilityManager.flush()
                }
        } else {
            DataErrorView(errorMessage: containerError ?? "Unknown error")
        }
    }

    @ViewBuilder
    private var settingsView: some View {
        if let container = sharedModelContainer {
            SettingsView(diContainer: diContainer)
                .modelContainer(container)
                .environment(diContainer)
        } else {
            Text("Settings unavailable — data store error.")
                .padding()
        }
    }
}

// MARK: - Data Error Recovery View

/// Shown when the SwiftData ModelContainer fails to initialize (e.g., schema migration failure).
/// Gives the user the option to reset their data and relaunch instead of crashing.
struct DataErrorView: View {
    let errorMessage: String
    @State private var showResetConfirmation = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)

            Text("Unable to Load Data")
                .font(.title2.bold())

            Text("The app's data store could not be opened. This can happen after an app update that changes the data format.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 400)

            errorDetailBox

            buttonRow
        }
        .padding(40)
        .frame(width: 500, height: 400)
        .alert("Reset All Data?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetDataAndRelaunch()
            }
        } message: {
            Text("This will delete all conversations, prompts, and settings. This action cannot be undone.")
        }
    }

    private var errorDetailBox: some View {
        GroupBox {
            ScrollView {
                Text(errorMessage)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 100)
        }
        .frame(maxWidth: 400)
    }

    private var buttonRow: some View {
        HStack(spacing: 16) {
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }

            Button("Reset Data & Relaunch") {
                showResetConfirmation = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
    }

    private func resetDataAndRelaunch() {
        // Delete the SwiftData store
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let storeURL = appSupport.appendingPathComponent("default.store")
        try? FileManager.default.removeItem(at: storeURL)
        // Also try the standard SwiftData location
        let bundleID = Bundle.main.bundleIdentifier ?? "OpusNative"
        let altDir = appSupport.appendingPathComponent(bundleID)
        try? FileManager.default.removeItem(at: altDir)

        // Relaunch
        let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
        let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [path]
        try? task.run()

        NSApplication.shared.terminate(nil)
    }
}
