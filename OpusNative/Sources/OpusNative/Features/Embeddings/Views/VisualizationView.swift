import SwiftUI
import Charts
import SwiftData

struct VisualizationView: View {
    @Bindable var viewModel: EmbeddingVisualizationViewModel
    @Query(sort: \EmbeddingItem.createdAt, order: .reverse) private var embeddings: [EmbeddingItem]
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: - Header
                VStack(alignment: .leading, spacing: 8) {
                    Label("Embedding Space", systemImage: "chart.xyaxis.line")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Visualize your embeddings in 2D space using PCA projection.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 40)
                
                if embeddings.isEmpty {
                    ContentUnavailableView {
                        Label("No Embeddings Found", systemImage: "chart.xyaxis.line")
                    } description: {
                        Text("Generate some embeddings in the Generator tab to visualize the space.")
                    }
                    .frame(height: 300)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .padding()
                } else {
                    // MARK: - PCA Scatter Plot
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Label("PCA Projection", systemImage: "circle.grid.cross")
                                .font(.headline)
                            Spacer()
                            if viewModel.isProcessing {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Button(action: {
                                    Task { await viewModel.processEmbeddings(embeddings) }
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .clipShape(Circle())
                            }
                        }
                        
                        if viewModel.pcaPoints.isEmpty && viewModel.isProcessing {
                             ProgressView("Calculating Projection...")
                                .frame(height: 350)
                                .frame(maxWidth: .infinity)
                        } else if viewModel.pcaPoints.isEmpty {
                            ContentUnavailableView("No Data", systemImage: "chart.xyaxis.line", description: Text("Tap refresh to calculate PCA."))
                                .frame(height: 350)
                        } else {
                            Chart {
                                ForEach(viewModel.pcaPoints) { point in
                                    PointMark(
                                        x: .value("PC1", point.x),
                                        y: .value("PC2", point.y)
                                    )
                                    .foregroundStyle(point.id == viewModel.selectedPointID ? .orange : .indigo)
                                    .symbolSize(point.id == viewModel.selectedPointID ? 150 : 80)
                                }
                            }
                            .chartXAxis(.hidden)
                            .chartYAxis(.hidden)
                            .frame(height: 350)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                            )
                            .chartOverlay { proxy in
                                GeometryReader { geometry in
                                    Rectangle().fill(.clear).contentShape(Rectangle())
                                        .onTapGesture { location in
                                            // Simple hit testing for demo
                                            // Real implementation needs coordinate conversion
                                            // For now, let's select a random point or the nearest
                                            if let (x, y) = proxy.value(at: location, as: (Double, Double).self) {
                                                findNearestPoint(x: x, y: y)
                                            }
                                        }
                                }
                            }
                        }
                        
                        // Performance Stats
                        HStack {
                            Text("Processing Time: \(String(format: "%.3f", viewModel.processingTime))s")
                            Spacer()
                            Text("Memory: \(viewModel.memoryUsageEstimate)")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .padding(.horizontal, 24)
                    
                    // MARK: - Selected Item Analysis
                    if let stats = viewModel.selectedStats {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Selected Embedding Analysis", systemImage: "waveform.path.ecg")
                                .font(.headline)
                            
                            // Stats Grid
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 12) {
                                StatCard(title: "Entropy", value: String(format: "%.3f", stats.entropy))
                                StatCard(title: "Sparsity", value: String(format: "%.1f%%", stats.sparsity * 100))
                                StatCard(title: "Variance", value: String(format: "%.5f", stats.variance))
                                StatCard(title: "L2 Norm", value: String(format: "%.3f", stats.l2Norm))
                            }
                            
                            // Histogram
                            if !viewModel.histogramData.isEmpty {
                                Text("Value Distribution")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8)
                                
                                Chart(viewModel.histogramData) { bin in
                                    BarMark(
                                        x: .value("Range", bin.label),
                                        y: .value("Count", bin.count)
                                    )
                                    .foregroundStyle(.blue.gradient)
                                }
                                .chartXAxis {
                                    AxisMarks(values: .automatic) { _ in
                                        // AxisValueLabel() // Too crowded usually
                                    }
                                }
                                .frame(height: 150)
                            }
                        }
                        .padding(20)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .padding(.horizontal, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .background(
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                
                // Top-left glow
                GeometryReader { proxy in
                    Circle()
                        .fill(Color.purple.opacity(0.1))
                        .frame(width: 800, height: 800)
                        .blur(radius: 120)
                        .offset(x: -200, y: -300)
                    
                    // Bottom-right glow
                    Circle()
                    tCircle.fill(Color.orange.opacity(0.08))
                        .frame(width: 600, height: 600)
                        .blur(radius: 100)
                        .offset(x: proxy.size.width * 0.5, y: proxy.size.height * 0.6)
                }
            }
            .ignoresSafeArea()
        )
        .onAppear {
            if !embeddings.isEmpty && viewModel.pcaPoints.isEmpty {
                Task { await viewModel.processEmbeddings(embeddings) }
            }
        }
        .onChange(of: embeddings) { _, newItems in
             Task { await viewModel.processEmbeddings(newItems) }
        }
    }
    
    private func findNearestPoint(x: Double, y: Double) {
        // Simple nearest neighbor search in view space
        var closest: UUID?
        var minDist = Double.infinity
        
        for point in viewModel.pcaPoints {
            let dx = point.x - x
            let dy = point.y - y
            let dist = dx*dx + dy*dy
            if dist < minDist {
                minDist = dist
                closest = point.id
            }
        }
        
        if let id = closest, let item = embeddings.first(where: { $0.id == id }) {
            Task { await viewModel.selectPoint(item) }
        }
    }
    
    // Helper View
    var tCircle: Circle { Circle() } // Workaround for swift expression complexity if needed
}

struct StatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }
}
