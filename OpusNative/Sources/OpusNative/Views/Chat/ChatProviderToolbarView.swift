import SwiftUI

struct ChatProviderToolbarView: View {
    @Bindable var aiManager: AIManager
    let performanceManager: PerformanceManager

    var body: some View {
        HStack(spacing: 16) {
            // Provider selector
            HStack(spacing: 8) {
                Image(systemName: "cpu")
                    .foregroundStyle(.white.opacity(0.5))
                Picker("Provider", selection: Binding(
                    get: { aiManager.activeProviderID },
                    set: { aiManager.switchProvider(to: $0) }
                )) {
                    ForEach(aiManager.providers, id: \.id) { provider in
                        HStack {
                            Text(provider.displayName)
                            if aiManager.isProviderConfigured(provider.id) {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                        .tag(provider.id)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 180)
            }

            Divider().frame(height: 20)

            // Model selector — dynamic for Ollama
            HStack(spacing: 8) {
                Image(systemName: "cube")
                    .foregroundStyle(.white.opacity(0.5))

                if aiManager.isLoadingOllamaModels && aiManager.activeProviderID == "ollama" {
                    // Loading state
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                    Text("Loading models…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if aiManager.activeProviderID == "ollama" && aiManager.activeProviderModels.isEmpty {
                    // No models state
                    Label {
                        Text("No models found")
                            .font(.caption)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                } else {
                    Picker("Model", selection: Binding(
                        get: { aiManager.settings.modelName },
                        set: { aiManager.settings.modelName = $0 }
                    )) {
                        let models = aiManager.activeProviderModels
                        ForEach(models, id: \.self) { model in
                            if aiManager.activeProviderID == "ollama",
                               let info = aiManager.ollamaModelInfo(for: model) {
                                HStack {
                                    Text(model)
                                    Spacer()
                                    if info.isLargeModel {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(.orange)
                                    }
                                    Text(info.formattedSize)
                                        .foregroundStyle(.secondary)
                                }
                                .tag(model)
                            } else {
                                Text(model).tag(model)
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 280)
                }

                // Refresh button (Ollama only)
                if aiManager.activeProviderID == "ollama" {
                    Button {
                        Task { await aiManager.refreshOllamaModels() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .disabled(aiManager.isLoadingOllamaModels)
                    .help("Refresh Ollama models")
                }
            }

            // Ollama error tooltip
            if let error = aiManager.ollamaModelError, aiManager.activeProviderID == "ollama" {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                    .help(error)
            }

            Spacer()

            // Capability badges
            if let provider = aiManager.activeProvider {
                HStack(spacing: 6) {
                    if provider.supportsVision {
                        capabilityBadge("eye", "Vision")
                    }
                    if provider.supportsStreaming {
                        capabilityBadge("waveform", "Stream")
                    }
                    if provider.supportsTools {
                        capabilityBadge("hammer", "Tools")
                    }
                }
            }

            // Status indicator
            if aiManager.isProviderConfigured(aiManager.activeProviderID) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                    .shadow(color: .green.opacity(0.5), radius: 4)
            } else {
                Circle()
                    .fill(.orange)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Group {
                if performanceManager.reduceTranslucency {
                    Color.black.opacity(0.9)
                } else {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .overlay(Rectangle().fill(Color.white.opacity(0.02)))
                }
            }
        )
        .task {
            // Auto-fetch Ollama models on view appearance when Ollama is active
            if aiManager.activeProviderID == "ollama" && aiManager.ollamaModels.isEmpty {
                await aiManager.fetchOllamaModels()
            }
        }
    }

    private func capabilityBadge(_ icon: String, _ label: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
            Text(label)
        }
        .font(.caption2)
        .foregroundStyle(.white.opacity(0.4))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.05)))
    }
}
