import SwiftUI

/// Premium side-by-side provider comparison view.
struct CompareView: View {
    @Bindable var viewModel: CompareViewModel

    private let accentColor = Color(red: 0.56, green: 0.44, blue: 1.0)
    private let accentGradient = LinearGradient(
        colors: [Color(red: 0.56, green: 0.44, blue: 1.0), Color(red: 0.36, green: 0.24, blue: 0.95)],
        startPoint: .leading, endPoint: .trailing
    )

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider().overlay(Color.white.opacity(0.06))

            ScrollView {
                VStack(spacing: 20) {
                    // Provider selector
                    providerSelector

                    // Prompt input
                    promptInput

                    // Compare button
                    compareButton

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
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.07, green: 0.07, blue: 0.12),
                        Color(red: 0.04, green: 0.04, blue: 0.09)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                // Subtle radial glow behind header
                RadialGradient(
                    colors: [accentColor.opacity(0.06), .clear],
                    center: .top,
                    startRadius: 50,
                    endRadius: 400
                )
            }
            .ignoresSafeArea()
        )
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "rectangle.split.2x1.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Compare Providers")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text("Send the same prompt to multiple AI providers")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            if !viewModel.results.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.clear()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.08)))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Provider Selector

    private var providerSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Select Providers")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text("\(viewModel.selectedProviderIDs.count) selected")
                    .font(.caption)
                    .foregroundStyle(accentColor.opacity(0.7))
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170))], spacing: 10) {
                ForEach(AIManager.shared.providers, id: \.id) { provider in
                    let isSelected = viewModel.selectedProviderIDs.contains(provider.id)
                    let isConfigured = AIManager.shared.isProviderConfigured(provider.id)

                    Button {
                        if isConfigured {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                viewModel.toggleProvider(provider.id)
                            }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            ProviderBadge(providerID: provider.id)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(provider.displayName)
                                    .font(.callout.weight(.medium))
                                    .foregroundStyle(isConfigured ? .white : .white.opacity(0.3))
                                    .lineLimit(1)
                                if !isConfigured {
                                    Text("Not configured")
                                        .font(.caption2)
                                        .foregroundStyle(.orange.opacity(0.6))
                                }
                            }

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(accentColor)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isSelected
                                      ? accentColor.opacity(0.12)
                                      : Color.white.opacity(0.03))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(
                                            isSelected ? accentColor.opacity(0.4) : Color.white.opacity(0.06),
                                            lineWidth: 1
                                        )
                                )
                        )
                        .scaleEffect(isSelected ? 1.01 : 1.0)
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
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))

            TextEditor(text: $viewModel.prompt)
                .font(.body)
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80, maxHeight: 160)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.white.opacity(0.08))
                        )
                )
        }
    }

    // MARK: - Compare Button

    private var compareButton: some View {
        Button {
            Task { await viewModel.compare() }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isComparing {
                    ProgressView()
                        .scaleEffect(0.75)
                        .tint(.white)
                    Text("Comparing…")
                        .font(.callout.weight(.semibold))
                } else {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 13))
                    Text("Compare (\(viewModel.selectedProviderIDs.count) providers)")
                        .font(.callout.weight(.semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        viewModel.selectedProviderIDs.count >= 2 && !viewModel.prompt.isEmpty
                            ? AnyShapeStyle(accentGradient)
                            : AnyShapeStyle(Color.white.opacity(0.08))
                    )
                    .shadow(
                        color: viewModel.selectedProviderIDs.count >= 2
                            ? accentColor.opacity(0.3) : .clear,
                        radius: 8, y: 4
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.selectedProviderIDs.count < 2 || viewModel.prompt.isEmpty || viewModel.isComparing)
    }

    // MARK: - Result Cards

    private var resultCards: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Results")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                // Summary badge
                if let fastest = viewModel.results.first(where: { $0.isSuccess }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(.yellow)
                        Text("Fastest: \(fastest.providerName)")
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.yellow.opacity(0.08))
                            .overlay(Capsule().strokeBorder(Color.yellow.opacity(0.15)))
                    )
                }
            }

            ForEach(viewModel.results) { result in
                resultCard(result)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func resultCard(_ result: CompareViewModel.CompareResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Provider header row
            HStack(spacing: 10) {
                // Rank medal
                rankBadge(result.rank, isSuccess: result.isSuccess)

                ProviderBadge(providerID: result.providerID)

                VStack(alignment: .leading, spacing: 1) {
                    Text(result.providerName)
                        .font(.callout.weight(.bold))
                        .foregroundStyle(.white)
                    if !result.modelName.isEmpty {
                        Text(result.modelName)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }

                Spacer()

                // Stats
                HStack(spacing: 12) {
                    // Latency
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9))
                        Text(formatLatency(result.latencyMs))
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(latencyColor(result.latencyMs))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(latencyColor(result.latencyMs).opacity(0.1))
                    )

                    if let tokens = result.tokenCount {
                        HStack(spacing: 3) {
                            Image(systemName: "textformat.size")
                                .font(.system(size: 9))
                            Text("\(tokens) tok")
                        }
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                    }
                }

                // Success / error indicator
                Circle()
                    .fill(result.isSuccess ? .green : .red)
                    .frame(width: 8, height: 8)
                    .shadow(color: (result.isSuccess ? Color.green : Color.red).opacity(0.5), radius: 4)
            }

            Divider().overlay(Color.white.opacity(0.06))

            // Content
            if result.isSuccess {
                Text(result.content)
                    .textSelection(.enabled)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineSpacing(3)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red.opacity(0.7))
                    Text(result.error ?? "Unknown error")
                        .textSelection(.enabled)
                        .foregroundStyle(.red.opacity(0.7))
                }
                .font(.callout)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .opacity(0.6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    result.rank == 1 && result.isSuccess
                        ? Color.yellow.opacity(0.15)
                        : result.isSuccess
                            ? Color.white.opacity(0.06)
                            : Color.red.opacity(0.15),
                    lineWidth: 1
                )
        )
        .shadow(
            color: result.rank == 1 && result.isSuccess
                ? Color.yellow.opacity(0.05) : .clear,
            radius: 12, y: 4
        )
    }

    // MARK: - Rank Badge

    private func rankBadge(_ rank: Int, isSuccess: Bool) -> some View {
        ZStack {
            Circle()
                .fill(rankColor(rank, isSuccess: isSuccess).opacity(0.15))
                .frame(width: 30, height: 30)

            if !isSuccess {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.red.opacity(0.7))
            } else if rank == 1 {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.yellow)
            } else {
                Text("#\(rank)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(rankColor(rank, isSuccess: isSuccess))
            }
        }
    }

    private func rankColor(_ rank: Int, isSuccess: Bool) -> Color {
        if !isSuccess { return .red }
        switch rank {
        case 1: return .yellow
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.8) // silver
        case 3: return Color(red: 0.8, green: 0.55, blue: 0.3)  // bronze
        default: return .white.opacity(0.5)
        }
    }

    // MARK: - Helpers

    private func latencyColor(_ ms: Double) -> Color {
        if ms < 2000 { return .green }
        if ms < 5000 { return .yellow }
        return .red
    }

    private func formatLatency(_ ms: Double) -> String {
        if ms < 1000 {
            return String(format: "%.0fms", ms)
        }
        return String(format: "%.1fs", ms / 1000)
    }
}
