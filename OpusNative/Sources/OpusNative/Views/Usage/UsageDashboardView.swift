import SwiftUI
import Charts

struct UsageDashboardView: View {
    @State private var usageManager = UsageManager.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                Text("Usage & Cost")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Key Metrics
                HStack(spacing: 16) {
                    MetricCard(
                        title: "Session Cost",
                        value: usageManager.sessionUsage.totalCost.formatted(.currency(code: "USD")),
                        icon: "dollarsign.circle.fill",
                        color: .green
                    )
                    
                    MetricCard(
                        title: "Lifetime Cost",
                        value: usageManager.lifetimeUsage.totalCost.formatted(.currency(code: "USD")),
                        icon: "banknote.fill",
                        color: .blue
                    )
                    
                    MetricCard(
                        title: "Total Tokens",
                        value: usageManager.lifetimeUsage.totalTokens.formatted(),
                        icon: "number.circle.fill",
                        color: .orange
                    )
                }
                
                // Charts Section
                HStack(spacing: 16) {
                    VStack(alignment: .leading) {
                        Text("Token Distribution")
                            .font(.headline)
                        
                        Chart {
                            SectorMark(
                                angle: .value("Input", usageManager.lifetimeUsage.inputTokens),
                                innerRadius: .ratio(0.6),
                                angularInset: 1.5
                            )
                            .foregroundStyle(.purple)
                            .annotation(position: .overlay) {
                                Text("\(formatTokens(usageManager.lifetimeUsage.inputTokens)) In")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                            }
                            
                            SectorMark(
                                angle: .value("Output", usageManager.lifetimeUsage.outputTokens),
                                innerRadius: .ratio(0.6),
                                angularInset: 1.5
                            )
                            .foregroundStyle(.teal)
                            .annotation(position: .overlay) {
                                Text("\(formatTokens(usageManager.lifetimeUsage.outputTokens)) Out")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(height: 200)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
                    
                    VStack(alignment: .leading) {
                        Text("Monthly Activity")
                            .font(.headline)
                        
                        if usageManager.monthlyUsage.isEmpty {
                            ContentUnavailableView("No Data", systemImage: "chart.bar")
                        } else {
                            Chart {
                                ForEach(usageManager.monthlyUsage.keys.sorted(), id: \.self) { month in
                                    if let stats = usageManager.monthlyUsage[month] {
                                        BarMark(
                                            x: .value("Month", month),
                                            y: .value("Cost", stats.totalCost)
                                        )
                                        .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .bottom, endPoint: .top))
                                    }
                                }
                            }
                            .frame(height: 200)
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
                }
                
                // Pricing Reference
                VStack(alignment: .leading, spacing: 16) {
                    Text("Model Pricing (per 1M tokens)")
                        .font(.headline)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible(), alignment: .leading),
                        GridItem(.fixed(100), alignment: .trailing),
                        GridItem(.fixed(100), alignment: .trailing)
                    ], spacing: 12) {
                        // Header row
                        Text("Model").font(.caption).foregroundStyle(.secondary)
                        Text("Input").font(.caption).foregroundStyle(.secondary)
                        Text("Output").font(.caption).foregroundStyle(.secondary)
                        
                        Divider()
                        
                        ForEach(usageManager.pricing.keys.sorted(), id: \.self) { model in
                            if let price = usageManager.pricing[model] {
                                Text(model)
                                    .font(.system(.body, design: .monospaced))
                                
                                Text(price.inputRate.formatted(.currency(code: "USD")))
                                    .foregroundStyle(.secondary)
                                
                                Text(price.outputRate.formatted(.currency(code: "USD")))
                                    .foregroundStyle(.secondary)
                                
                                Divider()
                            }
                        }
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
            }
            .padding(32)
        }
    }
    
    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.title2)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}
