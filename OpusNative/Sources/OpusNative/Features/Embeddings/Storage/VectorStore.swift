import Foundation
import Accelerate

struct VectorDocument: Identifiable, Codable {
    let id: UUID
    let text: String
    let vector: [Float]
    let metadata: [String: String]
    
    init(id: UUID = UUID(), text: String, vector: [Float], metadata: [String: String] = [:]) {
        self.id = id
        self.text = text
        self.vector = vector
        self.metadata = metadata
    }
}

struct VectorSearchResult: Identifiable {
    let id = UUID()
    let document: VectorDocument
    let score: Float
}

actor VectorStore {
    static let shared = VectorStore()
    
    private var documents: [VectorDocument] = []
    
    // MARK: - Management
    
    func add(document: VectorDocument) {
        documents.append(document)
    }
    
    func add(text: String, vector: [Float], metadata: [String: String] = [:]) {
        let doc = VectorDocument(text: text, vector: vector, metadata: metadata)
        documents.append(doc)
    }
    
    func clear() {
        documents.removeAll()
    }
    
    var count: Int {
        documents.count
    }
    
    // MARK: - Search
    
    func search(query: [Float], topK: Int = 5) -> [VectorSearchResult] {
        guard !documents.isEmpty else { return [] }
        
        // Compute cosine similarity for all docs
        // Optimization: Use Accelerate for batch processing if performance is critical
        // For now, simple loop is sufficient for small N
        
        let results = documents.map { doc -> VectorSearchResult in
            let score = cosineSimilarity(query, doc.vector)
            return VectorSearchResult(document: doc, score: score)
        }
        
        // Sort descending by score
        let sorted = results.sorted { $0.score > $1.score }
        return Array(sorted.prefix(topK))
    }
    
    // MARK: - Math
    
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0.0 }
        
        // Accelerate implementation for speed
        var dot: Float = 0.0
        vDSP_dotpr(a, 1, b, 1, &dot, vDSP_Length(a.count))
        
        var magA: Float = 0.0
        vDSP_svesq(a, 1, &magA, vDSP_Length(a.count))
        
        var magB: Float = 0.0
        vDSP_svesq(b, 1, &magB, vDSP_Length(b.count))
        
        let denominator = sqrt(magA) * sqrt(magB)
        return denominator == 0 ? 0.0 : dot / denominator
    }
}
