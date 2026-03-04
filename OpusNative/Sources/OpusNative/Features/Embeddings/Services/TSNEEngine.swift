import Foundation
import Accelerate

/// A pure Swift implementation of t-Distributed Stochastic Neighbor Embedding (t-SNE)
/// Optimized for small batch sizes (N < 500) typical in a playground environment.
struct TSNEEngine: Sendable {
    
    /// Configuration parameters for t-SNE
    struct Config {
        var perplexity: Double = 30.0
        var learningRate: Double = 200.0
        var maxIterations: Int = 1000
        var momentum: Double = 0.5
        var finalMomentum: Double = 0.8
        var momentumSwitchIter: Int = 250
    }
    
    /// Performs dimensionality reduction using t-SNE.
    /// Returns an array of 2D points.
    nonisolated static func reduce(vectors: [[Double]], config: Config = Config()) -> [[Double]] {
        let n = vectors.count
        guard n > 1 else { return vectors.map { [$0.first ?? 0, $0.dropFirst().first ?? 0] } }
        
        let perplexity = min(config.perplexity, Double(n - 1) / 3.0)
        
        // 1. Compute Pairwise Euclidean Distances (Squared)
        var sum_X = [Double](repeating: 0.0, count: n)
        for i in 0..<n {
            sum_X[i] = vectors[i].reduce(0) { $0 + $1 * $1 }
        }
        
        var D = [Double](repeating: 0.0, count: n * n)
        for i in 0..<n {
            for j in 0..<n {
                if i != j {
                    var dist = 0.0
                    for k in 0..<vectors[i].count {
                        let diff = vectors[i][k] - vectors[j][k]
                        dist += diff * diff
                    }
                    D[i * n + j] = dist
                }
            }
        }
        
        // 2. Compute P-values (Affinities) with binary search for precision
        var P = [Double](repeating: 0.0, count: n * n)
        let targetH = log(perplexity)
        let tol = 1e-5
        
        for i in 0..<n {
            var betaMin = -Double.infinity
            var betaMax = Double.infinity
            var beta = 1.0
            
            for _ in 0..<50 {
                var sumP = 0.0
                var H = 0.0
                var pRow = [Double](repeating: 0.0, count: n)
                
                for j in 0..<n {
                    if i != j {
                        let p = exp(-D[i * n + j] * beta)
                        pRow[j] = p
                        sumP += p
                    }
                }
                
                if sumP == 0 { sumP = 1e-10 }
                for j in 0..<n {
                    pRow[j] /= sumP
                    if pRow[j] > 1e-10 {
                        H -= pRow[j] * log(pRow[j])
                    }
                }
                
                let Hdiff = H - targetH
                if abs(Hdiff) < tol {
                    for j in 0..<n { P[i * n + j] = pRow[j] }
                    break
                }
                
                if Hdiff > 0 {
                    betaMin = beta
                    beta = betaMax == .infinity ? beta * 2.0 : (beta + betaMax) / 2.0
                } else {
                    betaMax = beta
                    beta = betaMin == -.infinity ? beta / 2.0 : (beta + betaMin) / 2.0
                }
                
                for j in 0..<n { P[i * n + j] = pRow[j] }
            }
        }
        
        // Symmetrize P
        for i in 0..<n {
            for j in 0..<n {
                let p_ij = P[i * n + j]
                let p_ji = P[j * n + i]
                let sym = (p_ij + p_ji) / Double(2 * n)
                P[i * n + j] = max(sym, 1e-12)
            }
        }
        
        // Early exaggeration
        for i in 0..<P.count { P[i] *= 4.0 }
        
        // 3. Initialize Y (Embedding) randomly
        var Y = (0..<n).map { _ in
            [Double.random(in: -0.0001...0.0001), Double.random(in: -0.0001...0.0001)]
        }
        var dY = (0..<n).map { _ in [0.0, 0.0] }
        var iY = (0..<n).map { _ in [0.0, 0.0] } // gains
        var gains = (0..<n).map { _ in [1.0, 1.0] }
        
        let minGain = 0.01
        
        // 4. Gradient Descent
        for iter in 0..<config.maxIterations {
            let momentum = iter < config.momentumSwitchIter ? config.momentum : config.finalMomentum
            
            // Stop early exaggeration
            if iter == 100 {
                for i in 0..<P.count { P[i] /= 4.0 }
            }
            
            // Compute Q (Student-t distribution)
            var num = [Double](repeating: 0.0, count: n * n)
            var sumQ = 0.0
            
            for i in 0..<n {
                for j in 0..<n {
                    if i != j {
                        let dx = Y[i][0] - Y[j][0]
                        let dy = Y[i][1] - Y[j][1]
                        let dist2 = dx * dx + dy * dy
                        let q = 1.0 / (1.0 + dist2)
                        num[i * n + j] = q
                        sumQ += q
                    }
                }
            }
            
            if sumQ == 0 { sumQ = 1e-10 }
            
            // Compute gradient
            for i in 0..<n {
                dY[i][0] = 0
                dY[i][1] = 0
                for j in 0..<n {
                    if i != j {
                        let q = num[i * n + j]
                        let Q_ij = q / sumQ
                        let mult = 4.0 * (P[i * n + j] - Q_ij) * q
                        dY[i][0] += mult * (Y[i][0] - Y[j][0])
                        dY[i][1] += mult * (Y[i][1] - Y[j][1])
                    }
                }
            }
            
            // Update Y
            for i in 0..<n {
                for d in 0..<2 {
                    let dir1 = dY[i][d] > 0
                    let dir2 = iY[i][d] > 0
                    gains[i][d] = (dir1 != dir2) ? (gains[i][d] + 0.2) : (gains[i][d] * 0.8)
                    gains[i][d] = max(minGain, gains[i][d])
                    
                    iY[i][d] = momentum * iY[i][d] - config.learningRate * gains[i][d] * dY[i][d]
                    Y[i][d] += iY[i][d]
                }
            }
            
            // Zero-mean Y
            var meanX = 0.0
            var meanY = 0.0
            for i in 0..<n {
                meanX += Y[i][0]
                meanY += Y[i][1]
            }
            meanX /= Double(n)
            meanY /= Double(n)
            for i in 0..<n {
                Y[i][0] -= meanX
                Y[i][1] -= meanY
            }
        }
        
        return Y
    }
}
