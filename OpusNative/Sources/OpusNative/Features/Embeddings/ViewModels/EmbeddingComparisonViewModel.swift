import Foundation
import SwiftData
import SwiftUI

@Observable
final class EmbeddingComparisonViewModel {
    
    // MARK: - State
    var sourceText: String = ""
    var targetText: String = ""
    var selectedModel: String = ""
    var availableModels: [String] = []
    
    var isComparing: Bool = false
    var errorMessage: String?
    
    // Results
    var similarityMetrics: [SimilarityEngine.Metric: Double] = [:]
    var comparisonDescription: String = ""
    var similarityLabel: String = ""
    var similarityColor: Color = .gray
    
    // Comparison History
    var comparisonHistory: [ComparisonResult] = []
    
    struct ComparisonResult: Identifiable {
        let id = UUID()
        let source: String
        let target: String
        let score: Double
        let timestamp: Date
    }
    
    struct RadarChartData: Identifiable {
        let id = UUID()
        let metric: String
        let value: Double // Normalized 0-1 for radar chart
    }
    
    var radarData: [RadarChartData] {
        // Normalize metrics for visualization
        // Cosine is -1 to 1 -> map to 0 to 1
        // Distances are 0 to infinity -> inverse map?
        // For now, let's just visualize Cosine and maybe normalized Euclidean (1 / (1+d))
        
        var data: [RadarChartData] = []
        
        if let cosine = similarityMetrics[.cosine] {
            // Map -1...1 to 0...1
            let normalized = (cosine + 1) / 2
            data.append(RadarChartData(metric: "Cosine", value: normalized))
        }
        
        if let euclidean = similarityMetrics[.euclidean] {
            // 1 / (1 + d)
            let normalized = 1.0 / (1.0 + euclidean)
            data.append(RadarChartData(metric: "Euclidean (Inv)", value: normalized))
        }
        
        if let manhattan = similarityMetrics[.manhattan] {
            let normalized = 1.0 / (1.0 + (manhattan / 10.0)) // Rough scaling
            data.append(RadarChartData(metric: "Manhattan (Inv)", value: normalized))
        }
        
        if let dot = similarityMetrics[.dotProduct] {
            // Sigmoid? or just cap
            let normalized = 1.0 / (1.0 + exp(-dot)) // Sigmoid
            data.append(RadarChartData(metric: "Dot (Sigmoid)", value: normalized))
        }
        
        return data
    }
    
    // MARK: - Dependencies
    private let service = EmbeddingService.shared
    
    // MARK: - Actions
    func fetchModels() async {
        do {
            let models = try await service.fetchEmbeddingModels()
            await MainActor.run {
                self.availableModels = models
                if self.selectedModel.isEmpty {
                    self.selectedModel = models.first ?? ""
                }
            }
        } catch {
            print("Failed to fetch models: \(error)")
        }
    }
    
    func compare() async {
        guard !sourceText.isEmpty, !targetText.isEmpty, !selectedModel.isEmpty else { return }
        
        await MainActor.run {
            self.isComparing = true
            self.errorMessage = nil
            self.similarityMetrics = [:]
        }
        
        do {
            async let v1 = service.generateEmbedding(prompt: sourceText, model: selectedModel)
            async let v2 = service.generateEmbedding(prompt: targetText, model: selectedModel)
            
            let (vector1, vector2) = try await (v1, v2)
            
            // Run Analytics
            let metrics = SimilarityEngine.compare(vector1, vector2)
            let cosine = metrics[.cosine] ?? 0.0
            let desc = SimilarityEngine.describeSimilarity(cosine)
            
            await MainActor.run {
                self.similarityMetrics = metrics
                self.similarityLabel = desc
                self.similarityColor = self.colorForScore(cosine)
                self.comparisonDescription = self.generateExplanation(score: cosine)
                
                self.comparisonHistory.insert(ComparisonResult(
                    source: sourceText,
                    target: targetText,
                    score: cosine,
                    timestamp: Date()
                ), at: 0)
                
                self.isComparing = false
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Comparison failed: \(error.localizedDescription)"
                self.isComparing = false
            }
        }
    }
    
    private func colorForScore(_ score: Double) -> Color {
        switch score {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .blue
        case 0.4..<0.6: return .orange
        default: return .red
        }
    }
    
    private func generateExplanation(score: Double) -> String {
        if score > 0.9 {
            return "These texts are semantically almost identical. They likely share the same core meaning, topic, and vocabulary."
        } else if score > 0.7 {
            return "These texts are strongly related. They discuss similar topics but might differ in nuance or specific details."
        } else if score > 0.5 {
            return "These texts share some semantic overlap. They might be in the same broad domain but focus on different aspects."
        } else if score > 0.0 {
            return "These texts have little in common. Any similarity might be coincidental or due to common stopwords."
        } else {
            return "These texts calculate as semantically opposite or unrelated in the vector space."
        }
    }
}
