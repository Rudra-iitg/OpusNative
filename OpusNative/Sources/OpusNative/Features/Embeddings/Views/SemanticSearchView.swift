import SwiftUI

struct SemanticSearchView: View {
    @State private var query: String = ""
    @State private var results: [VectorSearchResult] = []
    @State private var isSearching: Bool = false
    @State private var embeddingModel: String = "nomic-embed-text"
    
    // Dependencies (Injected or Singleton)
    private var vectorStore: VectorStore { VectorStore.shared }
    private var embeddingService: EmbeddingGenerator { AIManager.shared.provider(for: "ollama") as? EmbeddingGenerator ?? OllamaProvider() }
    
    var body: some View {
        VStack(spacing: 20) {
            // Search Input
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search meaningfully...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title2)
                    .onSubmit {
                        Task { await performSearch() }
                    }
                
                if !query.isEmpty {
                    Button(action: { query = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
            
            // Stats
            HStack {
                Text("\(vectorStore.count) documents indexed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if isSearching {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal)
            
            // Results
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(results) { result in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(String(format: "%.1f%% Match", result.score * 100))
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(scoreColor(result.score).opacity(0.2))
                                    .foregroundStyle(scoreColor(result.score))
                                    .clipShape(Capsule())
                                
                                Spacer()
                                
                                Text(result.document.metadata["source"] ?? "Unknown")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Text(result.document.text)
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.9))
                                .lineLimit(3)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
                    }
                }
            }
        }
        .padding()
    }
    
    private func performSearch() async {
        guard !query.isEmpty else { return }
        isSearching = true
        
        // 1. Generate embedding for query
        if let vector = try? await embeddingService.generateEmbedding(prompt: query, model: embeddingModel) {
            // 2. Search store
            let matches: [VectorSearchResult] = await vectorStore.search(query: vector, topK: 10)
            withAnimation {
                self.results = matches
            }
        }
        
        isSearching = false
    }
    
    private func scoreColor(_ score: Float) -> Color {
        if score > 0.8 { return .green }
        if score > 0.6 { return .yellow }
        return .orange
    }
}

// Protocol for embedding service (if not already defined)
// Protocol for embedding service (if not already defined)
protocol EmbeddingGenerator {
    func generateEmbedding(prompt: String, model: String) async throws -> [Float]
}


