import SwiftUI

/// Individual result card for a provider comparison
struct CompareResultCardView: View {
    let result: CompareViewModel.CompareResult
    @Bindable var viewModel: CompareViewModel
    let accentColor: Color

    var body: some View {
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
                        Text(shortModelName(result.modelName))
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

                // Evaluation controls
                evaluationControls(result)
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

    // MARK: - Evaluation Controls

    private func evaluationControls(_ result: CompareViewModel.CompareResult) -> some View {
        VStack(spacing: 8) {
            Divider().overlay(Color.white.opacity(0.06))

            HStack(spacing: 12) {
                // Thumbs up
                Button {
                    viewModel.toggleThumbsUp(result.id)
                } label: {
                    Image(systemName: viewModel.thumbsRatings[result.id] == true ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .foregroundStyle(viewModel.thumbsRatings[result.id] == true ? .green : .white.opacity(0.4))
                        .font(.callout)
                }
                .buttonStyle(.plain)

                // Thumbs down
                Button {
                    viewModel.toggleThumbsDown(result.id)
                } label: {
                    Image(systemName: viewModel.thumbsRatings[result.id] == false ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        .foregroundStyle(viewModel.thumbsRatings[result.id] == false ? .red : .white.opacity(0.4))
                        .font(.callout)
                }
                .buttonStyle(.plain)

                Spacer()

                // Expand rubric
                Button {
                    viewModel.toggleEvaluation(result.id)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                        Text("Rate")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(accentColor.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(accentColor.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }

            // Expanded rubric scoring
            if viewModel.evaluationExpanded[result.id] == true {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(ResponseEvaluation.rubricCategories, id: \.self) { category in
                        HStack(spacing: 8) {
                            Text(category)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(width: 100, alignment: .leading)

                            // Star rating 1-5
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { star in
                                    let currentScore = viewModel.rubricScores[result.id]?[category] ?? 0
                                    Image(systemName: star <= currentScore ? "star.fill" : "star")
                                        .font(.system(size: 12))
                                        .foregroundStyle(star <= currentScore ? .yellow : .white.opacity(0.2))
                                        .onTapGesture {
                                            viewModel.setRubricScore(result.id, category: category, score: star)
                                        }
                                }
                            }
                        }
                    }

                    // Notes
                    TextField("Add notes...", text: Binding(
                        get: { viewModel.evaluationNotes[result.id] ?? "" },
                        set: { viewModel.setNotes(result.id, notes: $0) }
                    ))
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.04))
                    )
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.white.opacity(0.06))
                        )
                )
            }
        }
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

    /// Shorten model names for display
    private func shortModelName(_ name: String) -> String {
        if let slashIndex = name.lastIndex(of: "/") {
            return String(name[name.index(after: slashIndex)...])
        }
        return name
    }
}
