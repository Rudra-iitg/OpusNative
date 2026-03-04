import Foundation
import Accelerate

/// Provides mathematical algorithms for detecting anomalies in a dataset of high-dimensional vectors.
struct AnomalyDetectionEngine: Sendable {
    
    /// Detects anomalies using a Z-Score approach based on distance to the centroid.
    /// Returns an array of booleans where `true` indicates an outlier.
    /// - Parameters:
    ///   - vectors: The high-dimensional embedding vectors
    ///   - threshold: The Z-Score threshold (default 2.0 or 3.0 standard deviations)
    nonisolated static func detectAnomaliesZScore(vectors: [[Double]], threshold: Double = 2.0) -> [Bool] {
        guard !vectors.isEmpty else { return [] }
        let count = vectors.count
        let dim = vectors[0].count
        
        // 1. Calculate centroid
        var centroid = Array(repeating: 0.0, count: dim)
        for vec in vectors {
            for i in 0..<dim {
                centroid[i] += vec[i]
            }
        }
        for i in 0..<dim {
            centroid[i] /= Double(count)
        }
        
        // 2. Calculate Euclidean distance from each point to the centroid
        var distances: [Double] = []
        for vec in vectors {
            distances.append(EmbeddingAnalyticsEngine.euclideanDistance(vec, centroid))
        }
        
        // 3. Simple Z-score: calculate mean and std dev of distances
        let meanDist = distances.reduce(0, +) / Double(count)
        let varianceDist = distances.map { ($0 - meanDist) * ($0 - meanDist) }.reduce(0, +) / Double(count)
        let stdDevDist = sqrt(varianceDist)
        
        // If stdDev is 0, everything is identical
        if stdDevDist == 0 {
            return Array(repeating: false, count: count)
        }
        
        // 4. Mark points with high Z-score as anomalies
        return distances.map { dist in
            let zScore = abs(dist - meanDist) / stdDevDist
            return zScore > threshold
        }
    }
}
