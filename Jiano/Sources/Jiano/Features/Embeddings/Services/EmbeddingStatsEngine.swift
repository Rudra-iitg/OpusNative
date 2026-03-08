import Foundation
import Accelerate

/// Performs comprehensive statistical analysis on embedding vectors.
struct EmbeddingStatsEngine: Sendable {
    
    struct VectorStats: Sendable {
        let dimension: Int
        let l2Norm: Double
        let mean: Double
        let variance: Double
        let standardDeviation: Double
        let min: Double
        let max: Double
        let sparsity: Double // Percentage of values close to zero (< 1e-6)
        let entropy: Double // Shannon entropy estimate
    }
    
    /// Analyzes a vector to extract statistical insights.
    /// - Parameter vector: The high-dimensional embedding vector.
    /// - Returns: A `VectorStats` struct containing analysis results.
    static func analyze(_ vector: [Double]) -> VectorStats {
        guard !vector.isEmpty else {
            return VectorStats(
                dimension: 0, l2Norm: 0, mean: 0, variance: 0,
                standardDeviation: 0, min: 0, max: 0, sparsity: 0, entropy: 0
            )
        }
        
        let count = vDSP_Length(vector.count)
        
        // 1. Min / Max
        var minVal: Double = 0
        var maxVal: Double = 0
        vDSP_minvD(vector, 1, &minVal, count)
        vDSP_maxvD(vector, 1, &maxVal, count)
        
        // 2. Mean
        var mean: Double = 0
        vDSP_meanvD(vector, 1, &mean, count)
        
        // 3. Variance & Std Dev
        var stdDev: Double = 0
        var meanDiffSqSum: Double = 0
        
        // vDSP_normalize can calculate mean and stdDev efficiently
        // But for variance we can use direct calculation
        // Variance = sum((x - mean)^2) / N
        let minusMean = vector.map { $0 - mean }
        var sqDiffs = [Double](repeating: 0, count: vector.count)
        vDSP_vsqD(minusMean, 1, &sqDiffs, 1, count)
        vDSP_sveD(sqDiffs, 1, &meanDiffSqSum, count)
        let variance = meanDiffSqSum / Double(vector.count)
        stdDev = sqrt(variance)
        
        // 4. L2 Norm
        // Norm = sqrt(sum(x^2))
        var sqSum: Double = 0
        vDSP_sveD(vector.map { $0 * $0 }, 1, &sqSum, count)
        let l2Norm = sqrt(sqSum)
        
        // 5. Sparsity
        // Count values with absolute magnitude < epsilon
        let epsilon = 1e-6
        let zeroCount = vector.filter { abs($0) < epsilon }.count
        let sparsity = Double(zeroCount) / Double(vector.count)
        
        // 6. Entropy (Histogram estimation)
        // Simplest approach: Bin values and compute Shannon entropy of the distribution
        let entropy = calculateEntropy(vector, min: minVal, max: maxVal)
        
        return VectorStats(
            dimension: vector.count,
            l2Norm: l2Norm,
            mean: mean,
            variance: variance,
            standardDeviation: stdDev,
            min: minVal,
            max: maxVal,
            sparsity: sparsity,
            entropy: entropy
        )
    }
    
    /// Estimates Shannon entropy using a histogram approach.
    private static func calculateEntropy(_ vector: [Double], min: Double, max: Double) -> Double {
        let binCount = 50
        guard binCount > 0, max > min else { return 0.0 }
        
        let range = max - min
        let binWidth = range / Double(binCount)
        var bins = [Int](repeating: 0, count: binCount)
        
        for value in vector {
            let binIndex = Int((value - min) / binWidth)
            if binIndex >= 0 && binIndex < binCount {
                bins[binIndex] += 1
            } else if binIndex == binCount {
                bins[binCount - 1] += 1
            }
        }
        
        // Compute probabilities
        let total = Double(vector.count)
        let probs = bins.map { Double($0) / total }.filter { $0 > 0 }
        
        // Shannon Entropy H = -sum(p * log2(p))
        let entropy = -probs.reduce(0.0) { result, p in
            result + (p * log2(p))
        }
        
        return entropy
    }
}
