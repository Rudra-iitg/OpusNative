import SwiftUI

struct SettingsPersonaTab: View {
    @Bindable var viewModel: SettingsViewModel
    let accentColor: Color

    private let personaPresets: [(String, String)] = [
        ("Coding Expert", "You are an expert software engineer. Provide clean, well-documented code with best practices. Always explain your reasoning."),
        ("Writing Assistant", "You are a skilled writing assistant. Help craft clear, compelling prose. Pay attention to tone, structure, and readability."),
        ("Concise", "You are a concise AI assistant. Give brief, direct answers. Avoid filler words and unnecessary explanations."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("System Prompt / Persona")
                .font(.headline)
                .foregroundStyle(.white)

            TextEditor(text: $viewModel.systemPrompt)
                .font(.body)
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 150)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.08)))
                )

            // Presets
            HStack(spacing: 8) {
                Text("Presets:")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                ForEach(personaPresets, id: \.0) { preset in
                    Button(preset.0) {
                        viewModel.systemPrompt = preset.1
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(accentColor.opacity(0.8))
                }
            }
        }
    }
}
