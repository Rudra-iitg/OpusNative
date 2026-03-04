import Foundation
import SwiftData
import SwiftUI
import Charts
import UniformTypeIdentifiers

/// Modes for the unified Embedding Workspace
enum EmbeddingWorkspaceMode: String, CaseIterable, Identifiable {
    case generate = "Generate"
    case explore = "Explore"
    case compare = "Compare"
    case lab = "Lab"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .generate: return "text.badge.plus"
        case .explore: return "chart.scatter"
        case .compare: return "arrow.left.and.right"
        case .lab: return "flask"
        }
    }
}

enum ReductionMethod: String, CaseIterable {
    case pca = "PCA"
    case tsne = "t-SNE"
}

@Observable
final class EmbeddingWorkspaceViewModel {
    
    // MARK: - Global State
    var currentMode: EmbeddingWorkspaceMode = .generate
    var availableModels: [String] = []
    var selectedModel: String = ""
    var isProcessing: Bool = false
    var errorMessage: String?
    
    // Performance
    var processingTime: TimeInterval = 0
    var memoryUsageEstimate: String = "0 MB"
    
    // Dependencies
    private let diContainer: AppDIContainer
    private var service: EmbeddingService { diContainer.embeddingService }
    private var modelContext: ModelContext?
    
    // MARK: - Mode: Generate State
    var generateInputText: String = ""
    var currentEmbedding: EmbeddingItem?
    var currentStats: EmbeddingAnalyticsEngine.VectorStats?
    
    // MARK: - Mode: Explore State
    var exploreItems: [EmbeddingItem] = []
    var pcaData: [EmbeddingVisualizationViewModel.PCADataPoint] = []
    var selectedPointID: UUID?
    var selectedPointStats: EmbeddingStatsEngine.VectorStats?
    var histogramData: [EmbeddingVisualizationViewModel.HistogramBin] = []
    
    // MARK: - Mode: Compare State
    var compareSourceText: String = ""
    var compareTargetText: String = ""
    var comparisonMetrics: [SimilarityEngine.Metric: Double] = [:]
    var comparisonLabel: String = ""
    var comparisonColor: Color = .gray
    var comparisonDescription: String = ""
    var comparisonHistory: [EmbeddingComparisonViewModel.ComparisonResult] = []
    
    // MARK: - Mode: Lab State
    var labBatchInput: String = ""
    var labClusterCount: Int = 3
    var labReductionMethod: ReductionMethod = .pca
    var labClusters: [KMeansEngine.Cluster] = []
    var labPoints: [EmbeddingPlaygroundViewModel.ClusterPoint] = []
    
    // MARK: - Initialization
    init(diContainer: AppDIContainer) {
        self.diContainer = diContainer
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    // MARK: - Global Actions
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
            await MainActor.run {
                self.errorMessage = "Failed to fetch models: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Generate Actions
    func generateSingleEmbedding() async {
        guard !generateInputText.isEmpty, !selectedModel.isEmpty else { return }
        
        await MainActor.run {
            self.isProcessing = true
            self.errorMessage = nil
            self.currentEmbedding = nil
            self.currentStats = nil
        }
        
        let start = Date()
        do {
            let vector = try await service.generateEmbedding(prompt: generateInputText, model: selectedModel)
            let stats = EmbeddingAnalyticsEngine.analyzeVector(vector)
            
            await MainActor.run {
                let item = EmbeddingItem(text: self.generateInputText, vector: vector, model: self.selectedModel)
                self.currentEmbedding = item
                self.currentStats = stats
                self.processingTime = Date().timeIntervalSince(start)
                self.isProcessing = false
                
                if let context = self.modelContext {
                    context.insert(item)
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Generation failed: \(error.localizedDescription)"
                self.isProcessing = false
            }
        }
    }
    
    // MARK: - Explore Actions
    func loadExploreItems(from items: [EmbeddingItem]) async {
        guard !items.isEmpty else {
            await MainActor.run { self.pcaData = [] }
            return
        }
        
        await MainActor.run { 
            self.exploreItems = items
            self.isProcessing = true 
        }
        
        let start = Date()
        let (points, memory) = await Task.detached(priority: .userInitiated) {
            let vectors = items.map { $0.vector }
            let reduced = DimensionalityReducer.performPCA(vectors, targetDimension: 2)
            
            var result: [EmbeddingVisualizationViewModel.PCADataPoint] = []
            for (index, row) in reduced.enumerated() {
                if index < items.count {
                    let item = items[index]
                    result.append(EmbeddingVisualizationViewModel.PCADataPoint(
                        id: item.id,
                        x: row[0],
                        y: row[1],
                        color: .indigo,
                        label: String(item.text.prefix(20)),
                        fullText: item.text
                    ))
                }
            }
            
            let mb = Double(vectors.reduce(0) { $0 + $1.count } * 8) / (1024 * 1024)
            return (result, String(format: "%.2f MB", mb))
        }.value
        
        await MainActor.run {
            self.pcaData = points
            self.memoryUsageEstimate = memory
            self.processingTime = Date().timeIntervalSince(start)
            self.isProcessing = false
        }
    }
    
    func selectExplorePoint(_ item: EmbeddingItem) async {
        // Just keeping it simple for now as it's a consolidation
        await MainActor.run {
            self.selectedPointID = item.id
            let stats = EmbeddingStatsEngine.analyze(item.vector)
            self.selectedPointStats = stats
            // Histogram logic (from previous Implementation) can be added here
        }
    }
    
    // MARK: - Compare Actions
    func runComparison() async {
        guard !compareSourceText.isEmpty, !compareTargetText.isEmpty, !selectedModel.isEmpty else { return }
        
        await MainActor.run {
            self.isProcessing = true
            self.errorMessage = nil
            self.comparisonMetrics = [:]
        }
        
        let start = Date()
        do {
            async let v1 = service.generateEmbedding(prompt: compareSourceText, model: selectedModel)
            async let v2 = service.generateEmbedding(prompt: compareTargetText, model: selectedModel)
            let (vec1, vec2) = try await (v1, v2)
            
            let metrics = SimilarityEngine.compare(vec1, vec2)
            let cosine = metrics[.cosine] ?? 0.0
            
            await MainActor.run {
                self.comparisonMetrics = metrics
                self.comparisonLabel = SimilarityEngine.describeSimilarity(cosine)
                self.comparisonColor = self.colorForScore(cosine)
                self.processingTime = Date().timeIntervalSince(start)
                
                self.comparisonHistory.insert(EmbeddingComparisonViewModel.ComparisonResult(
                    source: self.compareSourceText,
                    target: self.compareTargetText,
                    score: cosine,
                    timestamp: Date()
                ), at: 0)
                
                self.isProcessing = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Comparison failed: \(error.localizedDescription)"
                self.isProcessing = false
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
    
    // MARK: - Lab Actions
    func runBatchAnalysis() async {
        guard !labBatchInput.isEmpty, !selectedModel.isEmpty else { return }
        let lines = labBatchInput.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !lines.isEmpty else { return }
        
        await MainActor.run {
            self.isProcessing = true
            self.labClusters = []
            self.labPoints = []
            self.errorMessage = nil
        }
        
        let start = Date()
        do {
            var vectors: [[Double]] = []
            var texts: [String] = []
            
            for line in lines {
                let vec = try await service.generateEmbedding(prompt: line, model: selectedModel)
                vectors.append(vec)
                texts.append(line)
            }
            
            let k = labClusterCount
            let kMeansResults = await Task.detached { KMeansEngine.cluster(vectors, k: k) }.value
            
            let reductionMethod = labReductionMethod
            let reduced = await Task.detached {
                if reductionMethod == .tsne {
                    return TSNEEngine.reduce(vectors: vectors)
                } else {
                    return DimensionalityReducer.performPCA(vectors)
                }
            }.value
            
            let anomalies = await Task.detached {
                AnomalyDetectionEngine.detectAnomaliesZScore(vectors: vectors, threshold: 2.0)
            }.value
            
            var newPoints: [EmbeddingPlaygroundViewModel.ClusterPoint] = []
            var indexToCluster: [Int: Int] = [:]
            for (cIndex, cluster) in kMeansResults.enumerated() {
                for memberIdx in cluster.memberIndices {
                    indexToCluster[memberIdx] = cIndex
                }
            }
            
            for (i, row) in reduced.enumerated() {
                let cIndex = indexToCluster[i] ?? -1
                newPoints.append(EmbeddingPlaygroundViewModel.ClusterPoint(
                    id: UUID(),
                    x: row[0],
                    y: row[1],
                    clusterIndex: cIndex,
                    text: texts[i],
                    isAnomaly: anomalies[i]
                ))
            }
            
            let totalDoubles = vectors.reduce(0) { $0 + $1.count }
            let mb = Double(totalDoubles * 8) / (1024 * 1024)
            
            await MainActor.run {
                self.labClusters = kMeansResults
                self.labPoints = newPoints
                self.memoryUsageEstimate = String(format: "%.2f MB", mb)
                self.processingTime = Date().timeIntervalSince(start)
                self.isProcessing = false
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Analysis failed: \(error.localizedDescription)"
                self.isProcessing = false
            }
        }
    }
    
    // MARK: - Export
    func getExportJSON() -> String? {
        guard !labPoints.isEmpty else { return nil }
        
        var jsonArray: [[String: Any]] = []
        for point in labPoints {
            jsonArray.append([
                "text": point.text,
                "x": point.x,
                "y": point.y,
                "cluster": point.clusterIndex,
                "isAnomaly": point.isAnomaly
            ])
        }
        
        guard let data = try? JSONSerialization.data(withJSONObject: jsonArray, options: .prettyPrinted) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
