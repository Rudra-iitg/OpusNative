import Foundation
import Accelerate

/// Handles clustering of embedding vectors.
struct KMeansEngine: Sendable {
    
    struct Cluster: Identifiable, Sendable {
        let id = UUID()
        let center: [Double]
        let memberIndices: [Int]
        // Anomaly Score could be distance of farthest member
    }
    
    /// Performs K-Means clustering.
    /// - Parameters:
    ///   - vectors: Array of N vectors.
    ///   - k: Number of clusters (default 3, or min(k, n)).
    ///   - maxIterations: Max iterations to run (default 20).
    nonisolated static func cluster(_ vectors: [[Double]], k: Int, maxIterations: Int = 20) -> [Cluster] {
        guard !vectors.isEmpty, k > 0 else { return [] }
        let n = vectors.count
        let safeK = min(k, n)
        
        // 1. Initialization (K-Means++ style or random)
        // Simple Random Sampling for stat
        var centroids = vectors.shuffled().prefix(safeK).map { $0 }
        var assignments = [Int](repeating: 0, count: n)
        
        for _ in 0..<maxIterations {
            var changes = 0
            
            // 2. Assignment Step
            for (i, vec) in vectors.enumerated() {
                var bestCluster = 0
                var minDistance = Double.infinity
                
                for (cIndex, centroid) in centroids.enumerated() {
                    // Start with Euclidean Distance squared (faster, no sqrt needed for comparison)
                    let distSq = euclideanDistanceSquared(vec, centroid)
                    if distSq < minDistance {
                        minDistance = distSq
                        bestCluster = cIndex
                    }
                }
                
                if assignments[i] != bestCluster {
                    assignments[i] = bestCluster
                    changes += 1
                }
            }
            
            if changes == 0 { break }
            
            // 3. Update Step
            var newCentroids = [[Double]](repeating: [Double](repeating: 0, count: vectors[0].count), count: safeK)
            var counts = [Int](repeating: 0, count: safeK)
            
            for (i, clusterIndex) in assignments.enumerated() {
                let vec = vectors[i]
                vDSP_vaddD(newCentroids[clusterIndex], 1, vec, 1, &newCentroids[clusterIndex], 1, vDSP_Length(vec.count))
                counts[clusterIndex] += 1
            }
            
            for c in 0..<safeK {
                if counts[c] > 0 {
                    var scale = 1.0 / Double(counts[c])
                    vDSP_vsmulD(newCentroids[c], 1, &scale, &newCentroids[c], 1, vDSP_Length(centroids[0].count))
                } else {
                    // Handle empty cluster (re-init)
                    if let randomParams = vectors.randomElement() {
                        newCentroids[c] = randomParams
                    }
                }
            }
            centroids = newCentroids
        }
        
        // 4. Build Results
        var clusters = [Cluster]()
        for c in 0..<safeK {
            let members = assignments.enumerated().filter { $0.element == c }.map { $0.offset }
            clusters.append(Cluster(center: centroids[c], memberIndices: members))
        }
        
        return clusters
    }
    
    // Helper to avoid sqrt cost in inner loop
    nonisolated private static func euclideanDistanceSquared(_ v1: [Double], _ v2: [Double]) -> Double {
        var sub = [Double](repeating: 0, count: v1.count)
        vDSP_vsubD(v1, 1, v2, 1, &sub, 1, vDSP_Length(v1.count))
        var sqSum: Double = 0
        vDSP_svesqD(sub, 1, &sqSum, vDSP_Length(v1.count))
        return sqSum
    }
}
