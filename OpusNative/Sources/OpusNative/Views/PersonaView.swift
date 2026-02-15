import SwiftUI

/// Persona settings tab for configuring the system prompt.
struct PersonaView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("System Prompt")
                .font(.headline)

            Text("Set a custom persona for Claude. This will be sent as the system prompt with every message.")
                .font(.callout)
                .foregroundStyle(.secondary)

            TextEditor(text: $viewModel.systemPrompt)
                .font(.body)
                .frame(minHeight: 160)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                )

            HStack {
                Button("Save") {
                    viewModel.saveSettings()
                }
                .buttonStyle(.borderedProminent)

                Button("Reset") {
                    viewModel.systemPrompt = ""
                }
                .buttonStyle(.bordered)

                if !viewModel.saveStatus.isEmpty {
                    Text(viewModel.saveStatus)
                        .font(.callout)
                        .foregroundStyle(viewModel.saveStatus.contains("✓") ? .green : .red)
                }

                Spacer()
            }

            // Preset prompts
            GroupBox("Quick Presets") {
                VStack(alignment: .leading, spacing: 8) {
                    presetButton(
                        "Coding Expert",
                        prompt: "You are an expert software engineer. Write clean, production-ready code with detailed explanations. Follow best practices and include error handling."
                    )
                    presetButton(
                        "Writing Assistant",
                        prompt: "You are a skilled writing assistant. Help with clear, concise, and engaging writing. Provide suggestions for improvement."
                    )
                    presetButton(
                        "Concise Responder",
                        prompt: "Be extremely concise. Respond with the minimum number of words necessary. Avoid filler phrases. Use bullet points when listing things."
                    )
                }
                .padding(8)
            }
        }
        .padding()
    }

    private func presetButton(_ title: String, prompt: String) -> some View {
        Button {
            viewModel.systemPrompt = prompt
        } label: {
            HStack {
                Text(title)
                    .font(.callout)
                Spacer()
                Image(systemName: "arrow.right.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
    }
}
