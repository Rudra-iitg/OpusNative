import SwiftUI
import Charts

struct GenerateResultView: View {
    @Bindable var viewModel: EmbeddingWorkspaceViewModel
    
    var body: some View {
        if let stats = viewModel.currentStats {
            VStack(alignment: .leading, spacing: 20) {
                
                Text(viewModel.generateInputText)
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                    .cornerRadius(8)
                    .padding(.horizontal)
                
                // Vector Waveform View
                if let vector = viewModel.currentEmbedding?.vector {
                    VStack(alignment: .leading) {
                        Label("Vector Waveform", systemImage: "waveform.path.ecg")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Chart {
                            ForEach(Array(vector.enumerated()), id: \.offset) { index, value in
                                AreaMark(
                                    x: .value("Dimension", index),
                                    y: .value("Magnitude", value)
                                )
                                .foregroundStyle(LinearGradient(colors: [.indigo, .cyan.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                            }
                        }
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .frame(height: 200)
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                
                // Stats Dashboard (Premium Metric Cards)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    WorkspaceMetricCard(title: "Dimensions", value: "\(viewModel.currentEmbedding?.vector.count ?? 0)", icon: "ruler", color: .blue)
                    WorkspaceMetricCard(title: "Sparsity", value: String(format: "%.1f%%", stats.sparsity * 100), icon: "circle.grid.cross", color: .purple)
                    WorkspaceMetricCard(title: "L2 Norm", value: String(format: "%.4f", stats.norm), icon: "function", color: .orange)
                    WorkspaceMetricCard(title: "Variance", value: String(format: "%.6f", stats.variance), icon: "chart.bar.xaxis", color: .green)
                    WorkspaceMetricCard(title: "Max Value", value: String(format: "%.4f", stats.max), icon: "arrow.up.to.line", color: .red)
                    WorkspaceMetricCard(title: "Min Value", value: String(format: "%.4f", stats.min), icon: "arrow.down.to.line", color: .indigo)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top)
        } else {
            ContentUnavailableView {
                Label("Generate Embedding", systemImage: "text.badge.plus")
            } description: {
                Text("Enter text and generate an embedding to view its vector waveform and detailed statistics.")
            } actions: {
                // Empty state actions
            }
        }
    }
}

struct WorkspaceMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title2.monospacedDigit().bold())
                    .foregroundStyle(color)
            }
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}
