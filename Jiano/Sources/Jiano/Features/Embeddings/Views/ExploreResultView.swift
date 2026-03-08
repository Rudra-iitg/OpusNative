import SwiftUI
import SwiftData
import Charts

struct ExploreResultView: View {
    @Bindable var viewModel: EmbeddingWorkspaceViewModel
    @State private var hoveredPoint: EmbeddingVisualizationViewModel.PCADataPoint?
    
    var body: some View {
        if viewModel.pcaData.isEmpty {
            emptyStateView
        } else {
            contentView
        }
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView("Explore Vectors", systemImage: "chart.scatter", description: Text("Select an embedding model to map saved workspace vectors."))
    }
    
    private var contentView: some View {
        VStack {
            headerView
            
            // Scatter Plot
            Chart {
                ForEach(viewModel.pcaData) { point in
                    PointMark(
                        x: .value("PCA 1", point.x),
                        y: .value("PCA 2", point.y)
                    )
                    .foregroundStyle(Color.indigo)
                    .symbolSize(hoveredPoint?.id == point.id ? 200.0 : 80.0)
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            handleHover(phase: phase, proxy: proxy)
                        }
                }
            }
            .frame(maxHeight: .infinity)
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .padding()
            .overlay(alignment: .topLeading) {
                tooltipView
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Label("Vector Space Explorer", systemImage: "globe")
                .font(.headline)
            Spacer()
            Text("\(viewModel.pcaData.count) embeddings loaded")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    @ViewBuilder
    private var tooltipView: some View {
        if let point = hoveredPoint {
            VStack(alignment: .leading) {
                Text(point.fullText)
                    .font(.caption)
                    .lineLimit(4)
                    .frame(maxWidth: 300, alignment: .leading)
            }
            .padding(12)
            .background(Color(nsColor: .windowBackgroundColor))
            .cornerRadius(8)
            .shadow(radius: 8)
            .padding(20)
        }
    }
    
    private func handleHover(phase: HoverPhase, proxy: ChartProxy) {
        switch phase {
        case .active(let location):
            if let (x, y) = proxy.value(at: location, as: (Double, Double).self) {
                findClosestPoint(x: x, y: y)
            }
        case .ended:
            hoveredPoint = nil
        }
    }
    
    private func findClosestPoint(x: Double, y: Double) {
        var closest: EmbeddingVisualizationViewModel.PCADataPoint? = nil
        var minDistance = Double.infinity
        for point in viewModel.pcaData {
            let dx = point.x - x
            let dy = point.y - y
            let dist = dx*dx + dy*dy
            if dist < minDistance {
                minDistance = dist
                closest = point
            }
        }
        if minDistance < 10.0 { hoveredPoint = closest } else { hoveredPoint = nil }
    }
}
