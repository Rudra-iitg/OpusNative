import SwiftUI

/// Premium side-by-side provider comparison view.
struct CompareView: View {
    @Bindable var viewModel: CompareViewModel

    @Environment(AppDIContainer.self) private var diContainer

    private var themeManager: ThemeManager { diContainer.themeManager }
    private var aiManager: AIManager { diContainer.aiManager }

    private var accentColor: Color { themeManager.accent }

    private var accentGradient: LinearGradient {
        LinearGradient(
            colors: [themeManager.accent, themeManager.accentDark],
            startPoint: .leading, endPoint: .trailing
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            CompareHeaderView(viewModel: viewModel, accentColor: accentColor)

            Divider().overlay(Color.white.opacity(0.06))

            ScrollView {
                VStack(spacing: 20) {
                    // Model selector
                    CompareModelSelectorView(viewModel: viewModel, accentColor: accentColor, aiManager: aiManager)

                    // Prompt input and Compare action
                    CompareActionView(viewModel: viewModel, accentColor: accentColor, accentGradient: accentGradient)

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
                        Text("Fastest: \(fastest.providerName) · \(shortModelName(fastest.modelName))")
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
                CompareResultCardView(result: result, viewModel: viewModel, accentColor: accentColor)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Save Evaluations button
            if viewModel.hasEvaluationData {
                Button {
                    viewModel.saveEvaluations()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.evaluationsSaved ? "checkmark.circle.fill" : "square.and.arrow.down")
                        Text(viewModel.evaluationsSaved ? "Evaluations Saved" : "Save All Evaluations")
                    }
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(viewModel.evaluationsSaved ? Color.green.opacity(0.2) : accentColor.opacity(0.3))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Shorten model names for display (e.g. "mistralai/Mistral-7B-Instruct-v0.2" → "Mistral-7B-Instruct-v0.2")
    private func shortModelName(_ name: String) -> String {
        if let slashIndex = name.lastIndex(of: "/") {
            return String(name[name.index(after: slashIndex)...])
        }
        return name
    }
}

