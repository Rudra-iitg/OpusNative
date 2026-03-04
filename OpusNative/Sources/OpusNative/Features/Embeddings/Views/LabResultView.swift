import SwiftUI
import Charts
import SwiftData
import UniformTypeIdentifiers

// MARK: - Export Document Helper
struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var text: String
    
    init(text: String = "") {
        self.text = text
    }
    
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let string = String(data: data, encoding: .utf8) {
            text = string
        } else {
            throw CocoaError(.fileReadCorruptFile)
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}

struct LabResultView: View {
    @Bindable var viewModel: EmbeddingWorkspaceViewModel
    @State private var hoveredPoint: EmbeddingPlaygroundViewModel.ClusterPoint?
    @State private var isExporting = false
    @State private var exportDocument: JSONDocument?
    
    var body: some View {
        if viewModel.labPoints.isEmpty {
            ContentUnavailableView {
                Label("Lab Analysis", systemImage: "flask")
            } description: {
                Text("Enter batch text and run analysis to cluster and visualize embeddings.")
            } actions: {
                // Empty state actions
            }
        } else {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Dimensionality Reduction", systemImage: "chart.scatter")
                        .font(.headline)
                    Spacer()
                    Picker("Method", selection: $viewModel.labReductionMethod) {
                        ForEach(ReductionMethod.allCases, id: \.self) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                    .onChange(of: viewModel.labReductionMethod) { _, _ in
                        Task { await viewModel.runBatchAnalysis() }
                    }
                    
                    Button("Export JSON") {
                        if let jsonString = viewModel.getExportJSON() {
                            exportDocument = JSONDocument(text: jsonString)
                            isExporting = true
                        }
                    }
                    .buttonStyle(.bordered)
                    .fileExporter(
                        isPresented: $isExporting,
                        document: exportDocument,
                        contentType: .json,
                        defaultFilename: "lab_results_\(Int(Date().timeIntervalSince1970))"
                    ) { result in
                        // Result handles success/failure internally
                    }
                }
                
                // Scatter Plot
                Chart {
                    ForEach(viewModel.labPoints) { point in
                        PointMark(
                            x: .value("Dim 1", point.x),
                            y: .value("Dim 2", point.y)
                        )
                        .foregroundStyle(by: .value("Cluster", "Cluster \(point.clusterIndex + 1)"))
                        // Anomaly styling
                        .symbol(point.isAnomaly ? .cross : .circle)
                        .symbolSize(point.isAnomaly ? 150 : 80)
                    }
                }
                .chartForegroundStyleScale(range: clusterColors)
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    if let (x, y) = proxy.value(at: location, as: (Double, Double).self) {
                                        findClosestPoint(x: x, y: y)
                                    }
                                case .ended:
                                    hoveredPoint = nil
                                }
                            }
                    }
                }
                .frame(maxHeight: .infinity)
                .padding()
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)
                .overlay(
                    Group {
                        if let point = hoveredPoint {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(point.text)
                                    .font(.caption)
                                    .lineLimit(3)
                                    .frame(maxWidth: 250, alignment: .leading)
                                
                                HStack {
                                    Text("Cluster \(point.clusterIndex + 1)")
                                        .font(.caption2.bold())
                                        .foregroundStyle(clusterColors[point.clusterIndex % clusterColors.count])
                                    if point.isAnomaly {
                                        Text("• Anomaly")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.red)
                                    }
                                }
                            }
                            .padding(8)
                            .background(.regularMaterial)
                            .cornerRadius(8)
                            .shadow(radius: 4)
                            .position(x: 150, y: 50) // Simplified fixed pos for tooltip
                        }
                    }
                )
                
                // Details / Inspector
                HStack {
                    Text("Clusters Found: \(viewModel.labClusters.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    let anomalyCount = viewModel.labPoints.filter({ $0.isAnomaly }).count
                    if anomalyCount > 0 {
                        Text("\(anomalyCount) Anomalies Detected")
                            .font(.subheadline.bold())
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding()
        }
    }
    
    let clusterColors: [Color] = [.indigo, .cyan, .teal, .orange, .pink, .purple, .yellow, .mint, .green, .red]
    
    private func findClosestPoint(x: Double, y: Double) {
        var closest: EmbeddingPlaygroundViewModel.ClusterPoint? = nil
        var minDistance = Double.infinity
        
        for point in viewModel.labPoints {
            let dx = point.x - x
            let dy = point.y - y
            let dist = dx*dx + dy*dy
            if dist < minDistance {
                minDistance = dist
                closest = point
            }
        }
        
        // Only show if reasonably close
        if minDistance < 10.0 { // adjust based on scale
            hoveredPoint = closest
        } else {
            hoveredPoint = nil
        }
    }
}
