import Foundation
import Accelerate

struct VectorDocument: Identifiable, Codable, Sendable {
    let id: UUID
    let text: String
    let vector: [Float]
    let metadata: [String: String]
    
    nonisolated init(id: UUID = UUID(), text: String, vector: [Float], metadata: [String: String] = [:]) {
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
    private var isDirty = false

    /// File URL for persistent storage
    private nonisolated let storageURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("OpusNative", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.storageURL = dir.appendingPathComponent("vectors.bin")

        // Load persisted documents synchronously (safe — no other references to this actor yet)
        if FileManager.default.fileExists(atPath: storageURL.path),
           let data = try? Data(contentsOf: storageURL),
           let loaded = try? JSONDecoder().decode([VectorDocument].self, from: data) {
            self.documents = loaded
        }
    }
    
    // MARK: - Management
    
    func add(document: VectorDocument) {
        documents.append(document)
        isDirty = true
        scheduleSave()
    }
    
    func add(text: String, vector: [Float], metadata: [String: String] = [:]) {
        let doc = VectorDocument(text: text, vector: vector, metadata: metadata)
        documents.append(doc)
        isDirty = true
        scheduleSave()
    }
    
    func clear() {
        documents.removeAll()
        isDirty = true
        saveToDisk()
    }
    
    var count: Int {
        documents.count
    }

    /// All stored documents
    var allDocuments: [VectorDocument] {
        documents
    }
    
    // MARK: - Search
    
    func search(query: [Float], topK: Int = 5) -> [VectorSearchResult] {
        guard !documents.isEmpty else { return [] }
        
        let results = documents.map { doc -> VectorSearchResult in
            let score = cosineSimilarity(query, doc.vector)
            return VectorSearchResult(document: doc, score: score)
        }
        
        let sorted = results.sorted { $0.score > $1.score }
        return Array(sorted.prefix(topK))
    }
    
    // MARK: - Math
    
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0.0 }
        
        var dot: Float = 0.0
        vDSP_dotpr(a, 1, b, 1, &dot, vDSP_Length(a.count))
        
        var magA: Float = 0.0
        vDSP_svesq(a, 1, &magA, vDSP_Length(a.count))
        
        var magB: Float = 0.0
        vDSP_svesq(b, 1, &magB, vDSP_Length(b.count))
        
        let denominator = sqrt(magA) * sqrt(magB)
        return denominator == 0 ? 0.0 : dot / denominator
    }

    // MARK: - Persistence

    /// Save a pending write (debounced)
    private func scheduleSave() {
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
            if isDirty {
                saveToDisk()
            }
        }
    }

    /// Serialize documents to disk as JSON
    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(documents)
            try data.write(to: storageURL, options: .atomic)
            isDirty = false
        } catch {
            // Silent failure — in-memory is still valid
            print("[VectorStore] Save failed: \(error.localizedDescription)")
        }
    }

    /// Load documents from disk
    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            documents = try JSONDecoder().decode([VectorDocument].self, from: data)
        } catch {
            print("[VectorStore] Load failed: \(error.localizedDescription)")
        }
    }

    /// Force an immediate save (call before app termination)
    func flush() {
        if isDirty {
            saveToDisk()
        }
    }
}

