import SwiftUI

struct SettingsModelTab: View {
    @Bindable var viewModel: SettingsViewModel
    let accentColor: Color

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




        }
    }
}
