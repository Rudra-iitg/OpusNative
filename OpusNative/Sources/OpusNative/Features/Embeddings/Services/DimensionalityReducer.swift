import Foundation
import Accelerate

/// Handles dimensionality reduction for visualization.
struct DimensionalityReducer: Sendable {
    
    /// Performs Principal Component Analysis (PCA) to reduce vectors to `targetDimension`.
    /// - Parameters:
    ///   - vectors: Array of high-dimensional vectors (N x D).
    ///   - targetDimension: The number of dimensions to preserve (typically 2 or 3).
    /// - Returns: Array of reduced vectors (N x targetDimension).
    nonisolated static func performPCA(_ vectors: [[Double]], targetDimension: Int = 2) -> [[Double]] {
        let n = vectors.count
        guard n > 0 else { return [] }
        let d = vectors[0].count
        guard d > targetDimension else { return vectors } // No reduction needed
        
        // 1. Center the data (Mean subtraction)
        // Calculating mean vector
        var meanVector = [Double](repeating: 0, count: d)
        for vec in vectors {
            vDSP_vaddD(meanVector, 1, vec, 1, &meanVector, 1, vDSP_Length(d))
        }
        var scale = 1.0 / Double(n)
        vDSP_vsmulD(meanVector, 1, &scale, &meanVector, 1, vDSP_Length(d))
        
        // Subtract mean from all vectors
        var centeredData = [Double]()
        centeredData.reserveCapacity(n * d)
        for vec in vectors {
            var centered = [Double](repeating: 0, count: d)
            vDSP_vsubD(meanVector, 1, vec, 1, &centered, 1, vDSP_Length(d))
            centeredData.append(contentsOf: centered)
        }
        
        // 2. Compute Covariance Matrix (D x D) = (X^T * X) / (n - 1)
        // Since N is usually small (< 100) for local viz, we can computing this directly.
        // For larger N, SVD would be better but requires complex LAPACK glue code.
        // Swift's Accelerate does not have a one-line Covariance function for generic matrices.
        
        // Simplified approach for generic Swift app using Accelerate for performance:
        // We will compute Covariance Matrix manually using vDSP dot products.
        // C[i][j] = dot(column_i, column_j) / (n-1)
        
        var covarianceMatrix = [Double](repeating: 0.0, count: d * d)
        let normalization = 1.0 / Double(n - 1)
        
        // Transpose data to get columns for easier dot product
        // Transpose data to get columns for easier dot product
        var columns = [[Double]](repeating: [Double](repeating: 0, count: n), count: d)
        
        // Manual chunking to avoid MainActor warning on extension
        for i in stride(from: 0, to: centeredData.count, by: d) {
            let row = centeredData[i..<min(i + d, centeredData.count)]
            let rowIndex = i / d
            for colIndex in 0..<d {
                 columns[colIndex][rowIndex] = row[row.startIndex + colIndex]
            }
        }
        
        // Compute upper triangle of covariance matrix
        for i in 0..<d {
            for j in i..<d {
                var dot: Double = 0
                vDSP_dotprD(columns[i], 1, columns[j], 1, &dot, vDSP_Length(n))
                let val = dot * normalization
                covarianceMatrix[i * d + j] = val
                covarianceMatrix[j * d + i] = val // Symmetric
            }
        }
        
        // 3. Eigen Decomposition
        // Using LAPACK dsyev via Accelerate would be ideal but is unsafe/complex in pure Swift without bridging.
        // Fallback: Power Iteration to find top k eigenvectors.
        // This is robust and implementation-friendly for k=2.
        
        var eigenVectors = [[Double]]()
        
        // Find 1st Principal Component
        let pc1 = powerIteration(matrix: covarianceMatrix, dim: d)
        eigenVectors.append(pc1)
        
        // Deflate matrix to find 2nd PC: A' = A - lambda * v * v^T
        // Estimate eigenvalue (Rayleigh quotient): (v^T A v) / (v^T v)
        // Since v is normalized, just v^T A v
        let lambda1 = rayleighQuotient(matrix: covarianceMatrix, vec: pc1, dim: d)
        let deflatedMatrix = deflate(matrix: covarianceMatrix, vec: pc1, lambda: lambda1, dim: d)
        
        // Find 2nd Principal Component
        let pc2 = powerIteration(matrix: deflatedMatrix, dim: d)
        eigenVectors.append(pc2)
        
        // 4. Project Data
        // Result[i] = [ dot(row_i, pc1), dot(row_i, pc2) ]
        var result = [[Double]]()
        for row in vectors { // Use original or centered? PCA typically projects centered data.
            // Let's project centered data
            var centered = [Double](repeating: 0, count: d)
            vDSP_vsubD(meanVector, 1, row, 1, &centered, 1, vDSP_Length(d))
            
            var x: Double = 0
            vDSP_dotprD(centered, 1, pc1, 1, &x, vDSP_Length(d))
            
            var y: Double = 0
            vDSP_dotprD(centered, 1, pc2, 1, &y, vDSP_Length(d))
            
            result.append([x, y])
        }
        
        return result
    }
    
    // MARK: - Helpers
    
    /// Finds the dominant eigenvector using Power Iteration method.
    nonisolated private static func powerIteration(matrix: [Double], dim: Int, maxIter: Int = 100) -> [Double] {
        // Random start vector
        var b = (0..<dim).map { _ in Double.random(in: -1...1) }
        normalize(&b)
        
        for _ in 0..<maxIter {
            // b_new = A * b
            var b_new = [Double](repeating: 0, count: dim)
            vDSP_mmulD(matrix, 1, b, 1, &b_new, 1, vDSP_Length(dim), 1, vDSP_Length(dim))
            
            // Normalize
            normalize(&b_new)
            
            // Check convergence (optional, skipped for speed)
            b = b_new
        }
        
        return b
    }
    
    nonisolated private static func normalize(_ v: inout [Double]) {
        var sqSum: Double = 0
        vDSP_svesqD(v, 1, &sqSum, vDSP_Length(v.count))
        let norm = sqrt(sqSum)
        if norm > 0 {
            var scale = 1.0 / norm
            vDSP_vsmulD(v, 1, &scale, &v, 1, vDSP_Length(v.count))
        }
    }
    
    nonisolated private static func rayleighQuotient(matrix: [Double], vec: [Double], dim: Int) -> Double {
        // numerator = v^T * A * v
        var Av = [Double](repeating: 0, count: dim)
        vDSP_mmulD(matrix, 1, vec, 1, &Av, 1, vDSP_Length(dim), 1, vDSP_Length(dim))
        
        var num: Double = 0
        vDSP_dotprD(vec, 1, Av, 1, &num, vDSP_Length(dim))
        
        return num // Assuming v is normalized
    }
    
    nonisolated private static func deflate(matrix: [Double], vec: [Double], lambda: Double, dim: Int) -> [Double] {
        // A' = A - lambda * (v * v^T)
        // vvT is a matrix where (i,j) = v[i]*v[j]
        var newMatrix = matrix
        for i in 0..<dim {
            for j in 0..<dim {
                let val = lambda * vec[i] * vec[j]
                newMatrix[i * dim + j] -= val
            }
        }
        return newMatrix
    }
}


