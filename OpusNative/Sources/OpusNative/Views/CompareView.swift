import SwiftUI

/// Premium side-by-side provider comparison view.
struct CompareView: View {
    @Bindable var viewModel: CompareViewModel
    @State private var showingAddModel = false
    @State private var addPickerProvider: String? = nil

    private var accentColor: Color { ThemeManager.shared.accent }

    private var accentGradient: LinearGradient {
        LinearGradient(
            colors: [ThemeManager.shared.accent, ThemeManager.shared.accentDark],
            startPoint: .leading, endPoint: .trailing
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider().overlay(Color.white.opacity(0.06))

            ScrollView {
                VStack(spacing: 20) {
                    // Model selector
                    modelSelector

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
                Text("Compare Models")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text("Add models and compare responses side by side")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            if !viewModel.results.isEmpty || !viewModel.entries.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.resetAll()
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

    // MARK: - Model Selector (Chips + Add Button)

    private var modelSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Models")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                if viewModel.entries.count >= 2 {
                    Text("\(viewModel.entries.count) models")
                        .font(.caption)
                        .foregroundStyle(accentColor.opacity(0.7))
                }
            }

            // Chips flow + add button
            FlowLayout(spacing: 8) {
                // Existing model chips
                ForEach(viewModel.entries) { entry in
                    modelChip(entry)
                        .transition(.scale.combined(with: .opacity))
                }

                // Add button
                addModelButton
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: viewModel.entries.count)
        }
    }

    /// A compact chip showing provider + model with ✕ to remove
    private func modelChip(_ entry: CompareViewModel.CompareEntry) -> some View {
        HStack(spacing: 6) {
            ProviderBadge(providerID: entry.providerID, compact: true)

            Text(shortModelName(entry.modelName))
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)

            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    viewModel.removeEntry(entry)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 6)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(accentColor.opacity(0.1))
                .overlay(
                    Capsule().strokeBorder(accentColor.opacity(0.25), lineWidth: 1)
                )
        )
    }

    /// The + button that opens the add model popover
    private var addModelButton: some View {
        Button {
            showingAddModel.toggle()
            addPickerProvider = nil
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                Text("Add Model")
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .strokeBorder(accentColor.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingAddModel, arrowEdge: .bottom) {
            addModelPopover
        }
    }

    // MARK: - Add Model Popover

    private var addModelPopover: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                if addPickerProvider != nil {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            addPickerProvider = nil
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }

                Text(addPickerProvider != nil ? "Select Model" : "Select Provider")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().overlay(Color.white.opacity(0.1))

            ScrollView {
                VStack(spacing: 2) {
                    if let pid = addPickerProvider {
                        // Step 2: Show models for selected provider
                        let models = viewModel.modelsForProvider(pid)
                        ForEach(models, id: \.self) { model in
                            let alreadyAdded = viewModel.entries.contains {
                                $0.providerID == pid && $0.modelName == model
                            }
                            Button {
                                viewModel.addEntry(providerID: pid, modelName: model)
                                showingAddModel = false
                                addPickerProvider = nil
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "cpu")
                                        .font(.system(size: 12))
                                        .foregroundStyle(accentColor.opacity(0.6))
                                        .frame(width: 20)

                                    Text(model)
                                        .font(.callout)
                                        .foregroundStyle(.white.opacity(alreadyAdded ? 0.3 : 0.9))
                                        .lineLimit(1)

                                    Spacer()

                                    if alreadyAdded {
                                        Text("Added")
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.3))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.001)) // Hit area
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(alreadyAdded)
                        }
                    } else {
                        // Step 1: Show providers
                        ForEach(viewModel.configuredProviders, id: \.id) { provider in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    addPickerProvider = provider.id
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    ProviderBadge(providerID: provider.id)

                                    Text(provider.displayName)
                                        .font(.callout.weight(.medium))
                                        .foregroundStyle(.white.opacity(0.9))

                                    Spacer()

                                    Text("\(viewModel.modelsForProvider(provider.id).count) models")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.3))

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.3))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.001))
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }

                        // Show unconfigured providers as disabled hints
                        let unconfigured = AIManager.shared.providers.filter {
                            !AIManager.shared.isProviderConfigured($0.id)
                        }
                        if !unconfigured.isEmpty {
                            Divider().overlay(Color.white.opacity(0.06)).padding(.vertical, 4)

                            ForEach(unconfigured, id: \.id) { provider in
                                HStack(spacing: 10) {
                                    ProviderBadge(providerID: provider.id)

                                    Text(provider.displayName)
                                        .font(.callout.weight(.medium))
                                        .foregroundStyle(.white.opacity(0.25))

                                    Spacer()

                                    Text("Not configured")
                                        .font(.caption2)
                                        .foregroundStyle(.orange.opacity(0.4))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .frame(width: 300, height: 340)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.10, green: 0.10, blue: 0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white.opacity(0.08))
                )
        )
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
                    Text("Compare (\(viewModel.entries.count) models)")
                        .font(.callout.weight(.semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        viewModel.entries.count >= 2 && !viewModel.prompt.isEmpty
                            ? AnyShapeStyle(accentGradient)
                            : AnyShapeStyle(Color.white.opacity(0.08))
                    )
                    .shadow(
                        color: viewModel.entries.count >= 2
                            ? accentColor.opacity(0.3) : .clear,
                        radius: 8, y: 4
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.entries.count < 2 || viewModel.prompt.isEmpty || viewModel.isComparing)
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

    /// Shorten model names for display (e.g. "mistralai/Mistral-7B-Instruct-v0.2" → "Mistral-7B-Instruct-v0.2")
    private func shortModelName(_ name: String) -> String {
        if let slashIndex = name.lastIndex(of: "/") {
            return String(name[name.index(after: slashIndex)...])
        }
        return name
    }
}

// MARK: - Flow Layout (wrapping horizontal layout)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: ProposedViewSize(width: bounds.width, height: bounds.height), subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }

    private struct ArrangeResult {
        var size: CGSize
        var positions: [CGPoint]
        var sizes: [CGSize]
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            sizes.append(size)

            if x + size.width > maxWidth && x > 0 {
                // Wrap to next row
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return ArrangeResult(
            size: CGSize(width: maxWidth, height: totalHeight),
            positions: positions,
            sizes: sizes
        )
    }
}
