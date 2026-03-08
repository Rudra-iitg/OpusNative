import Foundation
import Accelerate

/// dedicated engine for calculating similarity and distance metrics between vectors.
struct SimilarityEngine: Sendable {
    
    enum Metric: String, CaseIterable, Identifiable {
        case cosine = "Cosine Similarity"
        case euclidean = "Euclidean Distance"
        case manhattan = "Manhattan Distance"
        case chebyshev = "Chebyshev Distance"
        case dotProduct = "Dot Product"
        
        var id: String { rawValue }
    }
    
    // MARK: - Core Metrics
    
    /// Calculates Cosine Similarity: (A . B) / (||A|| * ||B||)
    nonisolated static func cosineSimilarity(_ v1: [Double], _ v2: [Double]) -> Double {
        guard v1.count == v2.count, !v1.isEmpty else { return 0.0 }
        let count = vDSP_Length(v1.count)
        
        // Dot product
        var dot: Double = 0
        vDSP_dotprD(v1, 1, v2, 1, &dot, count)
        
        // Norms
        var normSq1: Double = 0
        vDSP_svesqD(v1, 1, &normSq1, count)
        
        var normSq2: Double = 0
        vDSP_svesqD(v2, 1, &normSq2, count)
        
        let norm1 = sqrt(normSq1)
        let norm2 = sqrt(normSq2)
        
        if norm1 == 0 || norm2 == 0 { return 0.0 }
        
        return dot / (norm1 * norm2)
    }
    
    /// Calculates Euclidean Distance (L2): sqrt(sum((a - b)^2))
    nonisolated static func euclideanDistance(_ v1: [Double], _ v2: [Double]) -> Double {
        guard v1.count == v2.count else { return 0.0 }
        let count = vDSP_Length(v1.count)
        
        var vSub = [Double](repeating: 0, count: v1.count)
        vDSP_vsubD(v1, 1, v2, 1, &vSub, 1, count)
        
        var sqSum: Double = 0
        vDSP_svesqD(vSub, 1, &sqSum, count)
        
        return sqrt(sqSum)
    }
    
    /// Calculates Manhattan Distance (L1): sum(|a - b|)
    nonisolated static func manhattanDistance(_ v1: [Double], _ v2: [Double]) -> Double {
        guard v1.count == v2.count else { return 0.0 }
        
        // |v1 - v2|
        var dist: Double = 0
        for i in 0..<v1.count {
            dist += abs(v1[i] - v2[i])
        }
        return dist
    }
    
    /// Calculates Chebyshev Distance (L_infinity): max(|a - b|)
    nonisolated static func chebyshevDistance(_ v1: [Double], _ v2: [Double]) -> Double {
        guard v1.count == v2.count else { return 0.0 }
        
        var maxDist: Double = 0
        for i in 0..<v1.count {
            let d = abs(v1[i] - v2[i])
            if d > maxDist { maxDist = d }
        }
        return maxDist
    }
    
    /// Calculates Dot Product: sum(a * b)
    nonisolated static func dotProduct(_ v1: [Double], _ v2: [Double]) -> Double {
        guard v1.count == v2.count else { return 0.0 }
        var dot: Double = 0
        vDSP_dotprD(v1, 1, v2, 1, &dot, vDSP_Length(v1.count))
        return dot
    }
    
    // MARK: - Advanced Analytics
    
    /// Returns a set of metrics comparing two vectors.
    static func compare(_ v1: [Double], _ v2: [Double]) -> [Metric: Double] {
        return [
            .cosine: cosineSimilarity(v1, v2),
            .euclidean: euclideanDistance(v1, v2),
            .manhattan: manhattanDistance(v1, v2),
            .chebyshev: chebyshevDistance(v1, v2),
            .dotProduct: dotProduct(v1, v2)
        ]
    }
    
    /// Returns a similarity description string based on Cosine Similarity.
    static func describeSimilarity(_ score: Double) -> String {
        switch score {
        case 0.9...1.0: return "Mathematically Identical"
        case 0.8..<0.9: return "Highly Similar"
        case 0.6..<0.8: return "Semantically Related"
        case 0.4..<0.6: return "Weakly Related"
        case 0.0..<0.4: return "Unrelated"
        case -1.0..<0.0: return "Opposite"
        default: return "Unknown"
        }
    }
}
