import Foundation
import SwiftData
import SwiftUI
import Charts

@Observable
final class EmbeddingVisualizationViewModel {
    
    // MARK: - State
    var isProcessing: Bool = false
    var errorMessage: String?
    
    // PCA
    var pcaPoints: [PCADataPoint] = []
    
    // Detailed Analysis
    var selectedPointID: UUID?
    var selectedStats: EmbeddingStatsEngine.VectorStats?
    var histogramData: [HistogramBin] = []
    
    // Performance Metrics
    var processingTime: TimeInterval = 0
    var memoryUsageEstimate: String = "0 MB"
    
    // MARK: - Models
    struct PCADataPoint: Identifiable {
        let id: UUID
        let x: Double
        let y: Double
        let color: Color // Based on cluster or model
        let label: String
        let fullText: String
    }
    
    struct HistogramBin: Identifiable {
        let id = UUID()
        let range: Range<Double>
        let count: Int
        let label: String
    }
    
    // MARK: - Actions
    
    /// Processes a list of embeddings for visualization.
    /// Runs PCA and updates the scatter plot data.
    @MainActor
    func processEmbeddings(_ items: [EmbeddingItem]) async {
        guard !items.isEmpty else {
            self.pcaPoints = []
            return
        }
        
        isProcessing = true
        let startTime = Date()
        
        // Run on background priority
        let (points, memory) = await Task.detached(priority: .userInitiated) {
            // 1. Extract vectors
            let vectors = items.map { $0.vector }
            
            // 2. Run PCA
            let reduced = DimensionalityReducer.performPCA(vectors, targetDimension: 2)
            
            // 3. Map to View Data
            var result: [PCADataPoint] = []
            for (index, row) in reduced.enumerated() {
                if index < items.count {
                    let item = items[index]
                    result.append(PCADataPoint(
                        id: item.id,
                        x: row[0],
                        y: row[1],
                        color: .indigo, // Todo: Color by cluster
                        label: String(item.text.prefix(20)),
                        fullText: item.text
                    ))
                }
            }
            
            // Est. Memory (Double = 8 bytes)
            let totalDoubles = vectors.reduce(0) { $0 + $1.count }
            let bytes = totalDoubles * 8
            let mb = Double(bytes) / (1024 * 1024)
            
            return (result, String(format: "%.2f MB", mb))
        }.value
        
        self.pcaPoints = points
        self.memoryUsageEstimate = memory
        self.processingTime = Date().timeIntervalSince(startTime)
        self.isProcessing = false
    }
    
    /// Selects a point and runs detailed analysis (Stats, Histogram).
    @MainActor
    func selectPoint(_ item: EmbeddingItem) async {
        self.selectedPointID = item.id
        
        // Compute Stats
        let stats = EmbeddingStatsEngine.analyze(item.vector)
        self.selectedStats = stats
        
        // Compute Histogram
        self.histogramData = computeHistogram(item.vector, min: stats.min, max: stats.max)
    }
    
    private func computeHistogram(_ vector: [Double], min: Double, max: Double) -> [HistogramBin] {
        let binCount = 20
        guard binCount > 0, max > min else { return [] }
        
        let range = max - min
        let width = range / Double(binCount)
        var bins = [Int](repeating: 0, count: binCount)
        
        for val in vector {
            let idx = Int((val - min) / width)
            if idx >= 0 && idx < binCount {
                bins[idx] += 1
            } else if idx == binCount {
                bins[binCount - 1] += 1
            }
        }
        
        var result: [HistogramBin] = []
        for i in 0..<binCount {
            let start = min + (Double(i) * width)
            let end = start + width
            result.append(HistogramBin(
                range: start..<end,
                count: bins[i],
                label: String(format: "%.2f", start)
            ))
        }
        
        return result
    }
}
