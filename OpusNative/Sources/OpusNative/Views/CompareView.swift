import SwiftUI

/// Side-by-side provider comparison view.
struct CompareView: View {
    @Bindable var viewModel: CompareViewModel

    private let accentColor = Color(red: 0.56, green: 0.44, blue: 1.0)

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "rectangle.split.2x1")
                    .foregroundStyle(accentColor)
                Text("Compare Providers")
                    .font(.title2.weight(.semibold))
                Spacer()
            }
            .padding(20)

            Divider().overlay(Color.white.opacity(0.08))

            ScrollView {
                VStack(spacing: 24) {
                    // Provider selector
                    providerSelector

                    // Prompt input
                    promptInput

                    // Compare button
                    Button {
                        Task { await viewModel.compare() }
                    } label: {
                        HStack {
                            if viewModel.isComparing {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                                Text("Comparing...")
                            } else {
                                Image(systemName: "play.fill")
                                Text("Compare (\(viewModel.selectedProviderIDs.count) providers)")
                            }
                        }
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(accentColor.opacity(viewModel.selectedProviderIDs.count >= 2 ? 1 : 0.4))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.selectedProviderIDs.count < 2 || viewModel.prompt.isEmpty || viewModel.isComparing)

                    if let error = viewModel.errorMessage {
                        ErrorBannerView(message: error) { viewModel.errorMessage = nil }
                    }

                    // Results
                    if !viewModel.results.isEmpty {
                        resultCards
                    }
                }
                .padding(24)
            }
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.08, blue: 0.12), Color(red: 0.05, green: 0.05, blue: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    // MARK: - Provider Selector

    private var providerSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Select Providers")
                .font(.callout.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 10) {
                ForEach(AIManager.shared.providers, id: \.id) { provider in
                    let isSelected = viewModel.selectedProviderIDs.contains(provider.id)
                    let isConfigured = AIManager.shared.isProviderConfigured(provider.id)

                    Button {
                        if isConfigured {
                            viewModel.toggleProvider(provider.id)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            ProviderBadge(providerID: provider.id)
                            Text(provider.displayName)
                                .font(.callout)
                                .foregroundStyle(isConfigured ? .white : .white.opacity(0.3))
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(accentColor)
                            }
                            if !isConfigured {
                                Text("Not configured")
                                    .font(.caption2)
                                    .foregroundStyle(.orange.opacity(0.6))
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isSelected ? accentColor.opacity(0.15) : Color.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(isSelected ? accentColor.opacity(0.5) : Color.white.opacity(0.06))
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!isConfigured)
                }
            }
        }
    }

    // MARK: - Prompt Input

    private var promptInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prompt")
                .font(.callout.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))

            TextEditor(text: $viewModel.prompt)
                .font(.body)
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.08)))
                )
        }
    }

    // MARK: - Result Cards

    private var resultCards: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Results")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Button("Clear") { viewModel.clear() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.white.opacity(0.5))
            }

            ForEach(viewModel.results) { result in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        ProviderBadge(providerID: result.providerID)
                        Text(result.providerName)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.white)
                        Spacer()

                        // Latency
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                            Text(String(format: "%.0fms", result.latencyMs))
                        }
                        .font(.caption2)
                        .foregroundStyle(latencyColor(result.latencyMs))

                        if let tokens = result.tokenCount {
                            HStack(spacing: 3) {
                                Image(systemName: "number")
                                Text("\(tokens)")
                            }
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                        }
                    }

                    if result.isSuccess {
                        Text(result.content)
                            .textSelection(.enabled)
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.85))
                    } else {
                        Text(result.error ?? "")
                            .foregroundStyle(.red.opacity(0.8))
                            .font(.callout)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(result.isSuccess ? Color.white.opacity(0.06) : Color.red.opacity(0.2))
                        )
                )
            }
        }
    }

    private func latencyColor(_ ms: Double) -> Color {
        if ms < 2000 { return .green.opacity(0.6) }
        if ms < 5000 { return .yellow.opacity(0.6) }
        return .red.opacity(0.6)
    }
}
