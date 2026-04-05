import SwiftUI
import Charts
import SwiftData

struct UsageDashboardView: View {
    @Environment(AppDIContainer.self) private var diContainer
    @Query(sort: \UsageRecord.date, order: .reverse) private var usageRecords: [UsageRecord]

    private var themeManager: ThemeManager { diContainer.themeManager }
    private var usageManager: UsageManager { diContainer.usageManager }
    private var accentColor: Color { themeManager.accent }

    // MARK: - Computed

    private var providerSummary: [(providerID: String, totalTokens: Int, totalCost: Double)] {
        var map: [String: (tokens: Int, cost: Double)] = [:]
        for record in usageRecords {
            let existing = map[record.providerID] ?? (0, 0)
            map[record.providerID] = (
                existing.tokens + record.promptTokens + record.completionTokens,
                existing.cost + record.totalCostUSD
            )
        }
        return map
            .map { (providerID: $0.key, totalTokens: $0.value.tokens, totalCost: $0.value.cost) }
            .sorted { $0.totalCost > $1.totalCost }
    }

    private var totalTokens: Int { usageManager.lifetimeUsage.totalTokens }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000    { return String(format: "%.1fk", Double(count) / 1_000) }
        return "\(count)"
    }

    // MARK: - Card style helper

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                    )
            )
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.07, blue: 0.12), Color(red: 0.04, green: 0.04, blue: 0.09)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    summaryCardsSection
                    chartsRow
                    providerBreakdownSection
                    pricingTableSection
                }
                .padding(28)
            }
        }
    }

    // MARK: - Section 1: Header

    private var headerSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Usage & Cost")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Token usage, costs, and model pricing")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            Text(currentMonthYear)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.3))
        }
    }

    private var currentMonthYear: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: Date())
    }

    // MARK: - Section 2: Summary Cards

    private var summaryCardsSection: some View {
        HStack(spacing: 16) {
            metricCard(
                icon: "dollarsign.circle.fill",
                iconColor: .green,
                value: usageManager.sessionUsage.totalCost.formatted(.currency(code: "USD")),
                label: "This Session"
            )
            metricCard(
                icon: "banknote.fill",
                iconColor: accentColor,
                value: usageManager.lifetimeUsage.totalCost.formatted(.currency(code: "USD")),
                label: "All Time"
            )
            metricCard(
                icon: "number.circle.fill",
                iconColor: .orange,
                value: formatTokens(totalTokens),
                label: "Total Tokens Used"
            )
        }
    }

    private func metricCard(icon: String, iconColor: Color, value: String, label: String) -> some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Section 3: Charts Row

    private var chartsRow: some View {
        HStack(alignment: .top, spacing: 16) {
            tokenDistributionCard
            monthlyActivityCard
        }
    }

    private var tokenDistributionCard: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accentColor)
                    Text("Token Distribution")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }

                let input = usageManager.lifetimeUsage.inputTokens
                let output = usageManager.lifetimeUsage.outputTokens

                if input == 0 && output == 0 {
                    ContentUnavailableView("No data yet", systemImage: "chart.pie")
                        .frame(height: 220)
                } else {
                    Chart {
                        SectorMark(
                            angle: .value("Output", output),
                            innerRadius: .ratio(0.58),
                            angularInset: 2.0
                        )
                        .foregroundStyle(accentColor)

                        SectorMark(
                            angle: .value("Input", input),
                            innerRadius: .ratio(0.58),
                            angularInset: 2.0
                        )
                        .foregroundStyle(accentColor.opacity(0.35))
                    }
                    .frame(height: 220)

                    let total = input + output
                    VStack(spacing: 6) {
                        legendRow(
                            color: accentColor.opacity(0.35),
                            label: "Input",
                            value: "\(formatTokens(input)) (\(total > 0 ? Int(Double(input)/Double(total)*100) : 0)%)"
                        )
                        legendRow(
                            color: accentColor,
                            label: "Output",
                            value: "\(formatTokens(output)) (\(total > 0 ? Int(Double(output)/Double(total)*100) : 0)%)"
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func legendRow(color: Color, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
        }
    }

    private var monthlyActivityCard: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accentColor)
                    Text("Monthly Activity")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }

                if usageManager.monthlyUsage.isEmpty {
                    ContentUnavailableView("No activity yet", systemImage: "chart.bar")
                        .frame(height: 220)
                } else {
                    Chart {
                        ForEach(usageManager.monthlyUsage.keys.sorted(), id: \.self) { month in
                            if let stats = usageManager.monthlyUsage[month] {
                                BarMark(
                                    x: .value("Month", month),
                                    y: .value("Cost", stats.totalCost)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [accentColor, accentColor.opacity(0.5)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .cornerRadius(4)
                            }
                        }
                    }
                    .frame(height: 220)
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisValueLabel()
                                .font(.caption2)
                                .foregroundStyle(Color.white.opacity(0.5))
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                if let d = value.as(Double.self) {
                                    Text(Decimal(d).formatted(.currency(code: "USD")))
                                        .font(.caption2)
                                        .foregroundStyle(Color.white.opacity(0.5))
                                }
                            }
                        }
                    }
                    .chartPlotStyle { plot in
                        plot.background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.03))
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Section 4: Provider Breakdown

    private var providerBreakdownSection: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accentColor)
                    Text("Provider Breakdown")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }

                if providerSummary.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.15))
                        Text("No provider data yet")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(providerSummary.enumerated()), id: \.element.providerID) { index, summary in
                            HStack(spacing: 12) {
                                ProviderBadge(providerID: summary.providerID)
                                Text(displayName(for: summary.providerID))
                                    .font(.callout.weight(.medium))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text(formatTokens(summary.totalTokens))
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.5))
                                Text(summary.totalCost.formatted(.currency(code: "USD")))
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(accentColor)
                            }
                            .padding(.vertical, 10)

                            if index < providerSummary.count - 1 {
                                Divider()
                                    .overlay(Color.white.opacity(0.06))
                            }
                        }
                    }
                }
            }
        }
    }

    private func displayName(for providerID: String) -> String {
        switch providerID {
        case "anthropic":   return "Anthropic"
        case "openai":      return "OpenAI"
        case "gemini":      return "Google Gemini"
        case "grok":        return "Grok"
        case "ollama":      return "Ollama"
        case "huggingface": return "HuggingFace"
        case "bedrock":     return "AWS Bedrock"
        default:            return providerID.capitalized
        }
    }

    // MARK: - Section 5: Model Pricing Table

    private var pricingTableSection: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "tag")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accentColor)
                    Text("Model Pricing")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("per 1M tokens")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.3))
                }

                VStack(spacing: 0) {
                    // Header row
                    HStack {
                        Text("Model")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Input")
                            .frame(width: 80, alignment: .trailing)
                        Text("Output")
                            .frame(width: 80, alignment: .trailing)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 8)

                    Divider()
                        .overlay(Color.white.opacity(0.08))

                    ForEach(usageManager.pricing.keys.sorted(), id: \.self) { model in
                        if let price = usageManager.pricing[model] {
                            let isFree = price.inputRate == 0 && price.outputRate == 0

                            HStack {
                                Text(model)
                                    .font(.system(.callout, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                if isFree {
                                    Text("Free")
                                        .font(.caption)
                                        .foregroundStyle(.green.opacity(0.7))
                                        .frame(width: 80, alignment: .trailing)
                                    Text("Free")
                                        .font(.caption)
                                        .foregroundStyle(.green.opacity(0.7))
                                        .frame(width: 80, alignment: .trailing)
                                } else {
                                    Text(price.inputRate.formatted(.currency(code: "USD")))
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.6))
                                        .frame(width: 80, alignment: .trailing)
                                    Text(price.outputRate.formatted(.currency(code: "USD")))
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.6))
                                        .frame(width: 80, alignment: .trailing)
                                }
                            }
                            .padding(.vertical, 8)

                            Divider()
                                .overlay(Color.white.opacity(0.04))
                        }
                    }
                }
            }
        }
    }
}
