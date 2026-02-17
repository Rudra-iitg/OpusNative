import Foundation
import Accelerate

/// Performs mathematical operations and statistical analysis on embedding vectors.
struct EmbeddingAnalyticsEngine: Sendable {
    // MARK: - Vector Math
    
    /// Calculates the Cosine Similarity between two vectors.
    /// Range: -1.0 to 1.0 (1.0 = identical direction).
    nonisolated static func cosineSimilarity(_ v1: [Double], _ v2: [Double]) -> Double {
        guard v1.count == v2.count, !v1.isEmpty else { return 0.0 }
        
        var dotProduct = 0.0
        var normA = 0.0
        var normB = 0.0
        
        for i in 0..<v1.count {
            dotProduct += v1[i] * v2[i]
            normA += v1[i] * v1[i]
            normB += v2[i] * v2[i]
        }
        
        if normA == 0 || normB == 0 { return 0.0 }
        
        return dotProduct / (sqrt(normA) * sqrt(normB))
    }
    
    /// Calculates Euclidean Distance between two vectors.
    static func euclideanDistance(_ v1: [Double], _ v2: [Double]) -> Double {
        guard v1.count == v2.count else { return Double.infinity }
        
        var sum = 0.0
        for i in 0..<v1.count {
            let diff = v1[i] - v2[i]
            sum += diff * diff
        }
        return sqrt(sum)
    }
    
    // MARK: - Statistics
    
    struct VectorStats {
        let min: Double
        let max: Double
        let mean: Double
        let variance: Double
        let norm: Double
        let sparsity: Double // Percentage of near-zero values
    }
    
    static func analyzeVector(_ vector: [Double]) -> VectorStats {
        guard !vector.isEmpty else {
            return VectorStats(min: 0, max: 0, mean: 0, variance: 0, norm: 0, sparsity: 0)
        }
        
        var minVal = vector[0]
        var maxVal = vector[0]
        var sum = 0.0
        var sqSum = 0.0
        var nearZeroCount = 0
        
        for val in vector {
            if val < minVal { minVal = val }
            if val > maxVal { maxVal = val }
            sum += val
            sqSum += val * val
            if abs(val) < 1e-6 { nearZeroCount += 1 }
        }
        
        let mean = sum / Double(vector.count)
        let variance = (sqSum / Double(vector.count)) - (mean * mean)
        let norm = sqrt(sqSum)
        let sparsity = Double(nearZeroCount) / Double(vector.count)
        
        return VectorStats(
            min: minVal,
            max: maxVal,
            mean: mean,
            variance: variance,
            norm: norm,
            sparsity: sparsity
        )
    }
    
    // MARK: - Dimensionality Reduction (PCA)
    
    static func performPCA(vectors: [[Double]]) -> [CGPoint] {
        guard !vectors.isEmpty else { return [] }
        let dimension = vectors[0].count
        guard dimension > 2 else {
            return vectors.map { vec in
                CGPoint(x: vec.indices.contains(0) ? vec[0] : 0,
                        y: vec.indices.contains(1) ? vec[1] : 0)
            }
        }
        
        let r1 = randomUnitVector(dim: dimension)
        let r2 = randomUnitVector(dim: dimension)
        
        let dot = zip(r1, r2).map(*).reduce(0, +)
        let r2Orthogonal = zip(r2, r1).map { v2, v1 in v2 - dot * v1 }
        let r2Norm = sqrt(r2Orthogonal.map { $0 * $0 }.reduce(0, +))
        let r2Final = r2Orthogonal.map { $0 / r2Norm }
        
        return vectors.map { vec in
            let x = zip(vec, r1).map(*).reduce(0, +)
            let y = zip(vec, r2Final).map(*).reduce(0, +)
            return CGPoint(x: x, y: y)
        }
    }
    
    private static func randomUnitVector(dim: Int) -> [Double] {
        let vec = (0..<dim).map { _ in Double.random(in: -1...1) }
        let norm = sqrt(vec.map { $0 * $0 }.reduce(0, +))
        return vec.map { $0 / norm }
    }
    
    // MARK: - Clustering (K-Means)
    
    struct Cluster {
        let center: [Double]
        var points: [Int]
    }
    
    static func kMeansClustering(vectors: [[Double]], k: Int, maxIterations: Int = 10) -> [Cluster] {
        guard !vectors.isEmpty, k > 0 else { return [] }
        let dim = vectors[0].count
        
        var centroids = vectors.shuffled().prefix(k).map { $0 }
        
        if centroids.count < k {
            return (0..<centroids.count).map { Cluster(center: centroids[$0], points: [$0]) }
        }
        
        var assignments = Array(repeating: 0, count: vectors.count)
        var clusters: [Cluster] = []
        
        for _ in 0..<maxIterations {
            var changeCount = 0
            for (i, vec) in vectors.enumerated() {
                var minDist = Double.infinity
                var bestCluster = 0
                
                for (cIndex, centroid) in centroids.enumerated() {
                    let dist = euclideanDistance(vec, centroid)
                    if dist < minDist {
                        minDist = dist
                        bestCluster = cIndex
                    }
                }
                
                if assignments[i] != bestCluster {
                    assignments[i] = bestCluster
                    changeCount += 1
                }
            }
            
            if changeCount == 0 { break }
            
            var newCentroids = Array(repeating: Array(repeating: 0.0, count: dim), count: k)
            var counts = Array(repeating: 0, count: k)
            
            for (i, clusterIndex) in assignments.enumerated() {
                let vec = vectors[i]
                for d in 0..<dim {
                    newCentroids[clusterIndex][d] += vec[d]
                }
                counts[clusterIndex] += 1
            }
            
            for c in 0..<k {
                if counts[c] > 0 {
                    for d in 0..<dim {
                        newCentroids[c][d] /= Double(counts[c])
                    }
                } else {
                    if let randomVec = vectors.randomElement() {
                        newCentroids[c] = randomVec
                    }
                }
            }
            centroids = newCentroids
        }
        
        for c in 0..<k {
            let memberIndices = assignments.enumerated().filter { $0.element == c }.map { $0.offset }
            clusters.append(Cluster(center: centroids[c], points: memberIndices))
        }
        
        return clusters
    }
}
