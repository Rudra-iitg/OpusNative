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
        let content: String
        let latencyMs: Double
        let tokenCount: Int?
        let error: String?

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

        // Run all providers concurrently
        await withTaskGroup(of: CompareResult.self) { group in
            for provider in selectedProviders {
                let settings = ModelSettings.defaultFor(providerID: provider.id)
                let providerID = provider.id
                let providerName = provider.displayName
                group.addTask {
                    let startTime = CFAbsoluteTimeGetCurrent()

                    do {
                        let response = try await provider.sendMessage(
                            text,
                            conversation: [],
                            settings: settings
                        )
                        let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

                        return CompareResult(
                            providerID: providerID,
                            providerName: providerName,
                            content: response.content,
                            latencyMs: latency,
                            tokenCount: response.tokenCount,
                            error: nil
                        )
                    } catch {
                        let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                        return CompareResult(
                            providerID: providerID,
                            providerName: providerName,
                            content: "",
                            latencyMs: latency,
                            tokenCount: nil,
                            error: error.localizedDescription
                        )
                    }
                }
            }

            for await result in group {
                results.append(result)
            }
        }

        // Sort by latency
        results.sort { $0.latencyMs < $1.latencyMs }
        isComparing = false
    }

    func clear() {
        prompt = ""
        results = []
        errorMessage = nil
    }
}
