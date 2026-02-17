import Foundation
import SwiftData
import SwiftUI

@Observable
final class EmbeddingPlaygroundViewModel {
    
    // MARK: - State
    var batchInput: String = "" // Multi-line input
    var clusterCount: Int = 3
    var isProcessing: Bool = false
    var errorMessage: String?
    
    // Results
    var clusters: [KMeansEngine.Cluster] = []
    var clusteredPoints: [ClusterPoint] = []
    
    // Models
    struct ClusterPoint: Identifiable {
        let id: UUID
        let x: Double
        let y: Double
        let clusterIndex: Int
        let text: String
        let isAnomaly: Bool
    }
    
    // Dependencies
    private let service = EmbeddingService.shared
    
    // MARK: - Actions
    
    @MainActor
    func runBatchAnalysis(model: String) async {
        guard !batchInput.isEmpty else { return }
        let lines = batchInput.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !lines.isEmpty else { return }
        
        isProcessing = true
        clusters = []
        clusteredPoints = []
        
        do {
            // 1. Batch Generate Embeddings
            // Process in parallel with TaskGroup
            var vectors: [[Double]] = []
            var texts: [String] = []
            
            // Simple sequential for now to assume order, or use indexed task group
            // Ideally should use service.generateEmbeddings(batch:) if supported, else loop
            for line in lines {
                let vec = try await service.generateEmbedding(prompt: line, model: model)
                vectors.append(vec)
                texts.append(line)
            }
            
            // 2. Perform Clustering
            // Run K-Means
            let k = self.clusterCount // Capture on MainActor
            let kMeansResults = await Task.detached {
                KMeansEngine.cluster(vectors, k: k)
            }.value
            
            // 3. Perform PCA for Visualization
            let reduced = await Task.detached {
                DimensionalityReducer.performPCA(vectors)
            }.value
            
            // 4. Map Results
            var newPoints: [ClusterPoint] = []
            
            // Create a mapping from index to cluster ID
            var indexToCluster: [Int: Int] = [:]
            for (cIndex, cluster) in kMeansResults.enumerated() {
                for memberIdx in cluster.memberIndices {
                    indexToCluster[memberIdx] = cIndex
                }
            }
            
            for (i, row) in reduced.enumerated() {
                let cIndex = indexToCluster[i] ?? -1
                
                // Anomaly Detection (Placeholder)
                let isAnomaly = false
                
                newPoints.append(ClusterPoint(
                    id: UUID(),
                    x: row[0],
                    y: row[1],
                    clusterIndex: cIndex,
                    text: texts[i],
                    isAnomaly: isAnomaly
                ))
            }
            
            self.clusters = kMeansResults
            self.clusteredPoints = newPoints
            self.isProcessing = false
            
        } catch {
            self.errorMessage = "Analysis failed: \(error.localizedDescription)"
            self.isProcessing = false
        }
    }
}
