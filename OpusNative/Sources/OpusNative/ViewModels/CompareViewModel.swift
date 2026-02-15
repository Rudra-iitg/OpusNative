import Foundation

// MARK: - Compare View Model

/// Sends the same prompt to multiple selected providers concurrently and collects results.
@Observable
@MainActor
final class CompareViewModel {
    var prompt: String = ""
    var selectedProviderIDs: Set<String> = []
    var results: [CompareResult] = []
    var isComparing = false
    var errorMessage: String?

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

    /// Toggle a provider for comparison
    func toggleProvider(_ id: String) {
        if selectedProviderIDs.contains(id) {
            selectedProviderIDs.remove(id)
        } else {
            selectedProviderIDs.insert(id)
        }
    }

    /// Send the prompt to all selected providers concurrently
    func compare() async {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            errorMessage = "Enter a prompt to compare."
            return
        }

        guard selectedProviderIDs.count >= 2 else {
            errorMessage = "Select at least 2 providers to compare."
            return
        }

        isComparing = true
        results = []
        errorMessage = nil

        let aiManager = AIManager.shared
        let selectedProviders = aiManager.providers.filter { selectedProviderIDs.contains($0.id) }

        // Ensure Ollama models are fetched for correct model name
        if selectedProviderIDs.contains("ollama") && aiManager.ollamaModels.isEmpty {
            await aiManager.fetchOllamaModels()
        }

        // Collect results without rank first
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
            for provider in selectedProviders {
                // Use saved settings from UserDefaults (has correct model), not static defaults
                let settings = self.loadSettings(for: provider.id, aiManager: aiManager)
                let providerID = provider.id
                let providerName = provider.displayName
                let modelName = settings.modelName
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

    // MARK: - Load Saved Settings

    /// Load the user's saved settings for a provider (with correct model name).
    /// Falls back to static defaults, but for Ollama ensures a valid model is set.
    private func loadSettings(for providerID: String, aiManager: AIManager) -> ModelSettings {
        // Try loading from UserDefaults (persisted by AIManager)
        if let data = UserDefaults.standard.data(forKey: "modelSettings_\(providerID)"),
           let saved = try? JSONDecoder().decode(ModelSettings.self, from: data),
           !saved.modelName.isEmpty {
            return saved
        }

        // Fallback: for Ollama, use first fetched model
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

