import SwiftUI

struct SettingsProvidersTab: View {
    @Bindable var viewModel: SettingsViewModel
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("API Keys & Credentials")
                .font(.headline)
                .foregroundStyle(.white)

            SettingsCardView(title: "Anthropic", icon: "sparkle", accentColor: accentColor) {
                SettingsSecureFieldView(label: "API Key", text: $viewModel.anthropicKey)
            }

            SettingsCardView(title: "OpenAI", icon: "brain", accentColor: accentColor) {
                SettingsSecureFieldView(label: "API Key", text: $viewModel.openaiKey)
            }

            SettingsCardView(title: "HuggingFace", icon: "text.magnifyingglass", accentColor: accentColor) {
                SettingsSecureFieldView(label: "Access Token", text: $viewModel.huggingfaceToken)
            }

            SettingsCardView(title: "Google Gemini", icon: "sparkles", accentColor: accentColor) {
                SettingsSecureFieldView(label: "API Key", text: $viewModel.geminiKey)
            }

            SettingsCardView(title: "Grok (xAI)", icon: "bolt.fill", accentColor: accentColor) {
                SettingsSecureFieldView(label: "API Key", text: $viewModel.grokKey)
            }

            SettingsCardView(title: "Ollama (Local)", icon: "desktopcomputer", accentColor: accentColor) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Base URL")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                    TextField("http://localhost:11434", text: $viewModel.ollamaBaseURL)
                        .textFieldStyle(.roundedBorder)
                }
            }

            SettingsCardView(title: "AWS Bedrock", icon: "cloud", accentColor: accentColor) {
                VStack(spacing: 12) {
                    SettingsSecureFieldView(label: "Access Key ID", text: $viewModel.accessKey)
                    SettingsSecureFieldView(label: "Secret Access Key", text: $viewModel.secretKey)
                    HStack {
                        Text("Region")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                        Picker("", selection: $viewModel.region) {
                            ForEach(SettingsViewModel.regions, id: \.self) { r in
                                Text(r).tag(r)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
        }
    }
}
