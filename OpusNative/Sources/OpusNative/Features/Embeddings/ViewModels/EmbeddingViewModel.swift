import Foundation
import SwiftData
import SwiftUI

struct PCADataPoint: Identifiable {
    let id: UUID
    let x: Double
    let y: Double
    let model: String
    let text: String
}

@Observable
final class EmbeddingViewModel {
    // MARK: - State
    var availableModels: [String] = []
    var selectedModel: String = ""
    var inputText: String = ""
    var isGenerating: Bool = false
    var errorMessage: String?
    
    // Analytics State
    var currentEmbedding: EmbeddingItem?
    var currentStats: EmbeddingAnalyticsEngine.VectorStats?
    
    // Visualization State
    var pcaData: [PCADataPoint] = []
    
    // Comparison State
    var comparisonText: String = ""
    var comparisonResult: Double? // Cosine Similarity
    
    // MARK: - Dependencies
    private let service = EmbeddingService.shared
    private var modelContext: ModelContext?
    
    // MARK: - Initialization
    init() { }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    // MARK: - Actions
    
    /// Fetches available embedding models from Ollama.
    func fetchModels() async {
        do {
            let models = try await service.fetchEmbeddingModels()
            await MainActor.run {
                self.availableModels = models
                if self.selectedModel.isEmpty, let first = models.first {
                    self.selectedModel = first
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch models: \(error.localizedDescription)"
            }
        }
    }
    
    /// Generates an embedding for the current input text.
    func generateEmbedding() async {
        guard !inputText.isEmpty else { return }
        
        await MainActor.run {
            self.isGenerating = true
            self.errorMessage = nil
            self.currentEmbedding = nil // Reset previous
            self.currentStats = nil
        }
        
        do {
            let vector = try await service.generateEmbedding(prompt: inputText, model: selectedModel)
            
            // Analyze immediately
            let stats = EmbeddingAnalyticsEngine.analyzeVector(vector)
            
            await MainActor.run {
                // Create Item
                let item = EmbeddingItem(text: inputText, vector: vector, model: selectedModel)
                self.currentEmbedding = item
                self.currentStats = stats
                self.isGenerating = false
                
                // Save to SwiftData
                if let context = self.modelContext {
                    context.insert(item)
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Generation failed: \(error.localizedDescription)"
                self.isGenerating = false
            }
        }
    }
    
    /// Compares the current embedding with a new text.
    func compareWith(_ text: String) async {
        guard let current = currentEmbedding, !text.isEmpty else { return }
        
        do {
            let newVector = try await service.generateEmbedding(prompt: text, model: selectedModel)
            let similarity = EmbeddingAnalyticsEngine.cosineSimilarity(current.vector, newVector)
            
            await MainActor.run {
                self.comparisonResult = similarity
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Comparison failed: \(error.localizedDescription)"
            }
        }
    }
    
    /// Refreshes PCA visualization for a list of items.
    func refreshPCA(items: [EmbeddingItem]) {
        guard !items.isEmpty else { return }
        
        // Extract vectors
        let vectors = items.map { $0.vector }
        
        // Run PCA
        let points = EmbeddingAnalyticsEngine.performPCA(vectors: vectors)
        
        // Map back to Data Points
        var newData: [PCADataPoint] = []
        for (index, point) in points.enumerated() {
            if index < items.count {
                let item = items[index]
                newData.append(PCADataPoint(
                    id: item.id,
                    x: point.x,
                    y: point.y,
                    model: item.model,
                    text: item.text
                ))
            }
        }
        
        self.pcaData = newData
    }
}
