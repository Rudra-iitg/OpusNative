import SwiftUI
import SwiftData

struct EmbeddingDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    
    // Instantiate all ViewModels here to persist state across tab switches
    @State private var generatorViewModel = EmbeddingViewModel()
    @State private var visualizationViewModel = EmbeddingVisualizationViewModel()
    @State private var comparisonViewModel = EmbeddingComparisonViewModel()
    @State private var playgroundViewModel = EmbeddingPlaygroundViewModel()
    
    var body: some View {
        NavigationSplitView {
            List {
                NavigationLink(destination: EmbeddingGeneratorView(viewModel: generatorViewModel)) {
                    Label("Generator", systemImage: "sparkles")
                }
                NavigationLink(destination: VisualizationView(viewModel: visualizationViewModel)) {
                    Label("Visualization", systemImage: "chart.xyaxis.line")
                }
                NavigationLink(destination: ComparisonView(viewModel: comparisonViewModel)) {
                    Label("Comparison", systemImage: "arrow.left.and.right")
                }
                NavigationLink(destination: PlaygroundView(viewModel: playgroundViewModel)) {
                    Label("Playground", systemImage: "flask")
                }
                NavigationLink(destination: SemanticSearchView()) {
                    Label("Semantic Search", systemImage: "magnifyingglass")
                }
            }
            .navigationTitle("Embeddings")
        } detail: {
            EmbeddingGeneratorView(viewModel: generatorViewModel)
        }
        .onAppear {
            generatorViewModel.setModelContext(modelContext)
            
            // Initial fetch
            Task {
                await generatorViewModel.fetchModels()
            }
        }
    }
}
