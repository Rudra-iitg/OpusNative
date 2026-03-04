import SwiftUI
import Charts

struct CompareResultView: View {
    @Bindable var viewModel: EmbeddingWorkspaceViewModel
    
    var body: some View {
        if viewModel.comparisonMetrics.isEmpty {
            ContentUnavailableView {
                Label("Semantic Comparison", systemImage: "arrow.left.and.right")
            } description: {
                Text("Enter two pieces of text and select a model to compare their semantic similarity in the vector space.")
            } actions: {
                // Empty state actions
            }
        } else {
            VStack(alignment: .leading, spacing: 20) {
                // High Level Result
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(viewModel.comparisonColor.opacity(0.2), lineWidth: 8)
                            .frame(width: 100, height: 100)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat((viewModel.comparisonMetrics[.cosine] ?? 0 + 1) / 2)) // rudimentary map to 0-1
                            .stroke(viewModel.comparisonColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))
                        
                        Text(String(format: "%.2f", viewModel.comparisonMetrics[.cosine] ?? 0.0))
                            .font(.title.bold())
                    }
                    
                    VStack(alignment: .leading) {
                        Text(viewModel.comparisonLabel)
                            .font(.title2.bold())
                            .foregroundStyle(viewModel.comparisonColor)
                        
                        Text(viewModel.comparisonDescription)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                
                // Detailed Metrics Chart
                VStack(alignment: .leading) {
                    Label("Distance Metrics", systemImage: "chart.bar.xaxis")
                        .font(.headline)
                    
                    Chart {
                        let sortedMetrics = viewModel.comparisonMetrics.sorted { $0.key.rawValue < $1.key.rawValue }
                        ForEach(sortedMetrics, id: \.key) { key, value in
                            BarMark(
                                x: .value("Value", value),
                                y: .value("Metric", key.rawValue)
                            )
                            .foregroundStyle(by: .value("Metric", key.rawValue))
                            .annotation(position: .trailing) {
                                Text(String(format: "%.4f", value))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .chartLegend(.hidden)
                    .frame(height: 200)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
        }
    }
}
