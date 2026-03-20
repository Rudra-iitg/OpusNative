import SwiftUI

struct SettingsModelTab: View {
    @Bindable var viewModel: SettingsViewModel
    let accentColor: Color

    @State private var selectedPresetTokens: Int = 0
    @State private var customLimitText: String = ""
    @State private var showCustomField: Bool = false
    @State private var customValidationError: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Inference Parameters")
                .font(.headline)
                .foregroundStyle(.white)

            SettingsCardView(title: "Temperature", icon: "thermometer", accentColor: accentColor) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Slider(value: $viewModel.temperature, in: 0...1, step: 0.05)
                        Text(String(format: "%.2f", viewModel.temperature))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 40)
                    }
                    Text("Lower = more deterministic, higher = more creative")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.3))
                }
            }

            SettingsCardView(title: "Max Tokens", icon: "number", accentColor: accentColor) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Slider(value: Binding(
                            get: { Double(viewModel.maxTokens) },
                            set: { viewModel.maxTokens = Int($0) }
                        ), in: 256...8192, step: 256)
                        Text("\(viewModel.maxTokens)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 50)
                    }
                }
            }

            SettingsCardView(title: "Top P (Nucleus Sampling)", icon: "chart.pie", accentColor: accentColor) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Slider(value: $viewModel.topP, in: 0...1, step: 0.05)
                        Text(String(format: "%.2f", viewModel.topP))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 40)
                    }
                }
            }

            SettingsCardView(title: "Context Window Default", icon: "text.alignleft", accentColor: accentColor) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sets the default context limit for all providers. Set to Auto to let Jiano detect per model.")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.3))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ContextManager.presets) { preset in
                                let isSelected = selectedPresetTokens == preset.tokens && !showCustomField
                                Button {
                                    selectedPresetTokens = preset.tokens
                                    showCustomField = false
                                    customValidationError = false
                                    ContextManager.shared.globalDefaultLimit = preset.tokens
                                } label: {
                                    Text(preset.label)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(isSelected ? .white : Color.white.opacity(0.6))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(isSelected ? accentColor : Color.white.opacity(0.06))
                                        )
                                }
                                .buttonStyle(.plain)
                            }

                            // Custom chip
                            Button {
                                showCustomField.toggle()
                                customValidationError = false
                            } label: {
                                Text("Custom")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(showCustomField ? .white : Color.white.opacity(0.6))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(showCustomField ? accentColor : Color.white.opacity(0.06))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if showCustomField {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                TextField("e.g. 65536", text: $customLimitText)
                                    .textFieldStyle(.plain)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.white.opacity(0.06))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .strokeBorder(customValidationError ? Color.red.opacity(0.6) : Color.white.opacity(0.1))
                                            )
                                    )

                                Button("Apply") {
                                    if let value = Int(customLimitText), value > 0 {
                                        selectedPresetTokens = value
                                        customValidationError = false
                                        ContextManager.shared.globalDefaultLimit = value
                                    } else {
                                        customValidationError = true
                                    }
                                }
                                .buttonStyle(.plain)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(accentColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(accentColor.opacity(0.15))
                                )
                            }

                            if customValidationError {
                                Text("Enter a positive integer (e.g. 65536)")
                                    .font(.caption2)
                                    .foregroundStyle(Color.red.opacity(0.8))
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    let globalDefault = ContextManager.shared.globalDefaultLimit
                    if globalDefault > 0 {
                        Text("Global default: \(globalDefault / 1000)k tokens")
                            .font(.caption2)
                            .foregroundStyle(Color.white.opacity(0.3))
                    } else {
                        Text("Auto-detect: limit resolved per model")
                            .font(.caption2)
                            .foregroundStyle(Color.white.opacity(0.3))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showCustomField)
            }
            .onAppear {
                selectedPresetTokens = ContextManager.shared.globalDefaultLimit
            }
        }
    }
}
