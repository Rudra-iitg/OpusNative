import Foundation

// MARK: - Compare View Model

/// Sends the same prompt to multiple selected models concurrently and collects results.
@Observable
@MainActor
final class CompareViewModel {
    var prompt: String = ""
    var entries: [CompareEntry] = []  // Models to compare
    var results: [CompareResult] = []
    var isComparing = false
    var errorMessage: String?

    // MARK: - Data Types

    /// A single model added for comparison
    struct CompareEntry: Identifiable, Equatable {
        let id = UUID()
        let providerID: String
        let providerName: String
        let modelName: String

        static func == (lhs: CompareEntry, rhs: CompareEntry) -> Bool {
            lhs.providerID == rhs.providerID && lhs.modelName == rhs.modelName
        }
    }

    struct CompareResult: Identifiable {
        let id = UUID()
        let providerID: String
        let providerName: String
        let modelName: String
        let content: String
        let latencyMs: Double
        let tokenCount: Int?
        let error: String?
        let rank: Int  // 1-based rank by latency (assigned after sorting)

        var isSuccess: Bool { error == nil }
    }

    // MARK: - Entry Management

    /// All configured providers the user can add from
    var configuredProviders: [(any AIProvider)] {
        AIManager.shared.providers.filter { AIManager.shared.isProviderConfigured($0.id) }
    }

    /// Get available models for a provider
    func modelsForProvider(_ id: String) -> [String] {
        let aiManager = AIManager.shared
        if id == "ollama" && !aiManager.ollamaModels.isEmpty {
            return aiManager.ollamaModels.map(\.name)
        }
        return aiManager.provider(for: id)?.availableModels ?? []
    }

    /// Add a model to the comparison
    func addEntry(providerID: String, modelName: String) {
        let provider = AIManager.shared.provider(for: providerID)
        let entry = CompareEntry(
            providerID: providerID,
            providerName: provider?.displayName ?? providerID,
            modelName: modelName
        )
        // Avoid exact duplicates
        if !entries.contains(where: { $0.providerID == providerID && $0.modelName == modelName }) {
            entries.append(entry)
        }
    }

    /// Remove an entry
    func removeEntry(_ entry: CompareEntry) {
        entries.removeAll { $0.id == entry.id }
    }

    // MARK: - Computed helpers for backward compat with compare logic

    private var selectedProviderIDs: Set<String> {
        Set(entries.map(\.providerID))
    }

    // MARK: - Compare

    /// Send the prompt to all selected models concurrently
    func compare() async {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            errorMessage = "Enter a prompt to compare."
            return
        }

        guard entries.count >= 2 else {
            errorMessage = "Add at least 2 models to compare."
            return
        }

        isComparing = true
        results = []
        errorMessage = nil

        let aiManager = AIManager.shared

        // Ensure Ollama models are fetched
        if entries.contains(where: { $0.providerID == "ollama" }) && aiManager.ollamaModels.isEmpty {
            await aiManager.fetchOllamaModels()
        }

        struct RawResult: Sendable {
            let providerID: String
            let providerName: String
            let modelName: String
            let content: String
            let latencyMs: Double
            let tokenCount: Int?
            let error: String?
        }

        var rawResults: [RawResult] = []

        await withTaskGroup(of: RawResult.self) { group in
            for entry in entries {
                guard let provider = aiManager.provider(for: entry.providerID) else { continue }

                var settings = self.loadSettings(for: entry.providerID, aiManager: aiManager)
                settings.modelName = entry.modelName

                let providerID = entry.providerID
                let providerName = entry.providerName
                let modelName = entry.modelName

                group.addTask {
                    let startTime = CFAbsoluteTimeGetCurrent()
                    do {
                        let response = try await provider.sendMessage(
                            text,
                            conversation: [],
                            settings: settings
                        )
                        let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                        return RawResult(
                            providerID: providerID,
                            providerName: providerName,
                            modelName: modelName,
                            content: response.content,
                            latencyMs: latency,
                            tokenCount: response.tokenCount,
                            error: nil
                        )
                    } catch {
                        let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                        return RawResult(
                            providerID: providerID,
                            providerName: providerName,
                            modelName: modelName,
                            content: "",
                            latencyMs: latency,
                            tokenCount: nil,
                            error: error.localizedDescription
                        )
                    }
                }
            }

            for await result in group {
                rawResults.append(result)
            }
        }

        // Sort by latency and assign ranks
        rawResults.sort { $0.latencyMs < $1.latencyMs }
        results = rawResults.enumerated().map { index, raw in
            CompareResult(
                providerID: raw.providerID,
                providerName: raw.providerName,
                modelName: raw.modelName,
                content: raw.content,
                latencyMs: raw.latencyMs,
                tokenCount: raw.tokenCount,
                error: raw.error,
                rank: index + 1
            )
        }

        isComparing = false
    }

    func clear() {
        prompt = ""
        results = []
        errorMessage = nil
    }

    func resetAll() {
        entries = []
        clear()
    }

    // MARK: - Load Saved Settings

    private func loadSettings(for providerID: String, aiManager: AIManager) -> ModelSettings {
        if let data = UserDefaults.standard.data(forKey: "modelSettings_\(providerID)"),
           let saved = try? JSONDecoder().decode(ModelSettings.self, from: data),
           !saved.modelName.isEmpty {
            return saved
        }

        if providerID == "ollama" {
            var settings = ModelSettings.defaultFor(providerID: providerID)
            if let firstModel = aiManager.ollamaModels.first?.name {
                settings.modelName = firstModel
            } else if let provider = aiManager.provider(for: "ollama") {
                settings.modelName = provider.availableModels.first ?? "llama3"
            }
            return settings
        }

        return ModelSettings.defaultFor(providerID: providerID)
    }
}
