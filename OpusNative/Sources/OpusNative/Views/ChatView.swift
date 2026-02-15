import SwiftUI
import SwiftData
import AppKit

/// Main chat view with multi-provider support, token/latency display, and model settings.
struct ChatView: View {
    @Bindable var chatVM: ChatViewModel
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isInputFocused: Bool

    private var aiManager: AIManager { AIManager.shared }

    // Background image from settings
    private var backgroundImagePath: String? {
        UserDefaults.standard.string(forKey: "backgroundImagePath")
    }
    private var backgroundOpacity: Double {
        UserDefaults.standard.double(forKey: "backgroundOpacity").clamped(to: 0.05...0.5, default: 0.15)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Provider & Model toolbar
            providerToolbar

            // Messages area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 20) {
                        if let conversation = chatVM.selectedConversation {
                            ForEach(conversation.sortedMessages) { message in
                                MessageBubbleView(message: message)
                                    .id(message.id)
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                                        removal: .opacity
                                    ))
                            }
                        } else {
                            emptyStateView
                        }

                        // Streaming message
                        if chatVM.isStreaming && !chatVM.streamingText.isEmpty {
                            StreamingBubbleView(
                                text: chatVM.streamingText,
                                providerName: aiManager.activeProvider?.displayName ?? "AI"
                            )
                            .id("streaming")
                        }

                        // Error message
                        if let error = chatVM.errorMessage {
                            ErrorBannerView(message: error) {
                                chatVM.errorMessage = nil
                            }
                            .id("error")
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 20)
                }
                .onChange(of: chatVM.streamingText) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo("streaming", anchor: .bottom)
                    }
                }
                .onChange(of: chatVM.selectedConversation?.messages.count) {
                    if let last = chatVM.selectedConversation?.sortedMessages.last {
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Input area
            inputBar
        }
        .background {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.08, blue: 0.12),
                        Color(red: 0.06, green: 0.07, blue: 0.10),
                        Color(red: 0.05, green: 0.05, blue: 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                if let path = backgroundImagePath, !path.isEmpty,
                   let nsImage = NSImage(contentsOfFile: path) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .opacity(backgroundOpacity)
                        .clipped()
                }

                RadialGradient(
                    colors: [
                        ThemeManager.shared.accent.opacity(0.04),
                        Color.clear
                    ],
                    center: .topTrailing,
                    startRadius: 100,
                    endRadius: 500
                )
            }
            .ignoresSafeArea()
        }
        .navigationTitle(chatVM.selectedConversation?.title ?? "OpusNative")
        .toolbar {
            if chatVM.isStreaming {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        chatVM.stopStreaming()
                    } label: {
                        Label("Stop", systemImage: "stop.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }

    // MARK: - Provider Toolbar

    private var providerToolbar: some View {
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
            Rectangle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .overlay(Rectangle().fill(Color.white.opacity(0.02)))
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

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [ThemeManager.shared.accent, ThemeManager.shared.accentLight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: ThemeManager.shared.accent.opacity(0.4), radius: 20)

            Text("Start a conversation")
                .font(.title2.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))

            Text("Select a provider and type a message below")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.35))

            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextEditor(text: $chatVM.currentMessage)
                .font(.body)
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 36, maxHeight: 120)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
                .focused($isInputFocused)
                .onSubmit {
                    if !NSEvent.modifierFlags.contains(.shift) {
                        chatVM.sendMessage(modelContext: modelContext)
                    }
                }

            Button {
                chatVM.sendMessage(modelContext: modelContext)
            } label: {
                Image(systemName: chatVM.isStreaming ? "ellipsis.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(
                        chatVM.currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color.white.opacity(0.2)
                            : ThemeManager.shared.accent
                    )
                    .shadow(color: chatVM.currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? .clear
                            : ThemeManager.shared.accent.opacity(0.5),
                            radius: 8)
            }
            .buttonStyle(.plain)
            .disabled(chatVM.currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chatVM.isStreaming)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .overlay(Rectangle().fill(Color.white.opacity(0.03)))
        )
    }
}

// MARK: - Streaming Bubble

struct StreamingBubbleView: View {
    let text: String
    var providerName: String = "AI"

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(ThemeManager.shared.accent)
                    Text(providerName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.6))
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                        .tint(ThemeManager.shared.accent)
                }

                Text(text)
                    .textSelection(.enabled)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                            )
                    )
            }
            Spacer(minLength: 80)
        }
    }
}

// MARK: - Error Banner

struct ErrorBannerView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text("Error")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(message, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.white.opacity(0.6))

                Button("Dismiss", action: onDismiss)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Text(message)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.85))
                .textSelection(.enabled)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.red.opacity(0.4), lineWidth: 1)
                )
        )
    }
}

// MARK: - Double Extension

private extension Double {
    func clamped(to range: ClosedRange<Double>, default defaultValue: Double) -> Double {
        if self == 0 { return defaultValue }
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
