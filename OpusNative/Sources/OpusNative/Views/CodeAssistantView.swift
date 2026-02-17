import SwiftUI
import MarkdownUI

/// Code assistant view with paste area, language detection, and 5 analysis actions.
struct CodeAssistantView: View {
    @Bindable var assistant: CodeAssistant

    private var accentColor: Color { ThemeManager.shared.accent }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .foregroundStyle(accentColor)
                Text("Code Assistant")
                    .font(.title2.weight(.semibold))
                Spacer()
                
                // Model Selector
                HStack(spacing: 8) {
                    // Provider Picker
                    Menu {
                        ForEach(AIManager.shared.providers.filter { AIManager.shared.isProviderConfigured($0.id) }, id: \.id) { provider in
                            Button(provider.displayName) {
                                assistant.selectedProviderID = provider.id
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if let provider = AIManager.shared.provider(for: assistant.selectedProviderID) {
                                ProviderBadge(providerID: provider.id, compact: true)
                                Text(provider.displayName)
                            } else {
                                Text("Select Provider")
                            }
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    // Model Picker
                    Menu {
                         ForEach(assistant.availableModels, id: \.self) { model in
                            Button(model) {
                                assistant.selectedModel = model
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                             Text(shortModelName(assistant.selectedModel))
                                .fixedSize()
                             Image(systemName: "chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .disabled(assistant.availableModels.isEmpty)
                }
                .padding(.trailing, 8)

                if assistant.detectedLanguage != "unknown" {
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                        Text(assistant.detectedLanguage)
                    }
                    .font(.callout)
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(accentColor.opacity(0.15))
                    )
                }
            }
            .padding(20)

            Divider().overlay(Color.white.opacity(0.08))

            HSplitView {
                // Left: code input + actions
                VStack(spacing: 16) {
                    // Code editor area
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Paste your code")
                                .font(.callout.weight(.medium))
                                .foregroundStyle(.white.opacity(0.7))
                            Spacer()
                            Button("Clear") {
                                assistant.code = ""
                                assistant.result = ""
                                assistant.detectedLanguage = "unknown"
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(.white.opacity(0.5))
                        }

                        TextEditor(text: $assistant.code)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.white)
                            .scrollContentBackground(.hidden)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.black.opacity(0.3))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(Color.white.opacity(0.08))
                                    )
                            )
                            .frame(maxHeight: .infinity)
                            .onChange(of: assistant.code) {
                                assistant.detectLanguage()
                            }
                    }

                    // Action buttons
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 10) {
                        ForEach(CodeAssistant.CodeAction.allCases) { action in
                            Button {
                                Task { await assistant.execute(action: action) }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: action.icon)
                                        .font(.callout)
                                    Text(action.rawValue)
                                        .font(.callout.weight(.medium))
                                }
                                .foregroundStyle(assistant.lastAction == action ? .white : .white.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(assistant.lastAction == action ? accentColor.opacity(0.3) : Color.white.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .strokeBorder(
                                                    assistant.lastAction == action ? accentColor.opacity(0.6) : Color.white.opacity(0.08)
                                                )
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(assistant.isProcessing || assistant.code.isEmpty)
                        }
                    }
                }
                .padding(20)
                .frame(minWidth: 300)

                // Right: results
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        if assistant.isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(accentColor)
                            Text("Analyzing...")
                                .font(.callout.weight(.medium))
                                .foregroundStyle(.white.opacity(0.6))
                        } else if let action = assistant.lastAction {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(action.rawValue + " Result")
                                .font(.callout.weight(.medium))
                                .foregroundStyle(.white.opacity(0.7))
                        } else {
                            Text("Results")
                                .font(.callout.weight(.medium))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        Spacer()
                    }
                    .padding(.top, 12)

                    if let error = assistant.errorMessage {
                        ErrorBannerView(message: error) { assistant.errorMessage = nil }
                    }

                    if !assistant.result.isEmpty {
                        ScrollView {
                            Markdown(assistant.result)
                                .markdownTheme(.gitHub)
                                .textSelection(.enabled)
                                .padding(16)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.03))
                        )
                    } else if !assistant.isProcessing {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "curlybraces")
                                .font(.system(size: 40))
                                .foregroundStyle(.white.opacity(0.15))
                            Text("Paste code and select an action")
                                .font(.callout)
                                .foregroundStyle(.white.opacity(0.3))
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding(20)
                .frame(minWidth: 300)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.08, blue: 0.12), Color(red: 0.05, green: 0.05, blue: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    /// Shorten model names (e.g. "mistralai/Mistral-7B" -> "Mistral-7B")
    private func shortModelName(_ name: String) -> String {
        if name.isEmpty { return "Select Model" }
        if let slashIndex = name.lastIndex(of: "/") {
            return String(name[name.index(after: slashIndex)...])
        }
        return name
    }
}
