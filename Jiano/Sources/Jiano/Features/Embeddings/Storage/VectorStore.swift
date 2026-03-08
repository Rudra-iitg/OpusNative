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

// MARK: - Binary format metadata (stored in vectors.meta.json)
private struct VectorMeta: Codable, Sendable {
    struct Entry: Codable, Sendable {
        let id: UUID
        let text: String
        let metadata: [String: String]
        let dimension: Int
        let byteOffset: Int  // Offset into vectors.bin
    }
    var entries: [Entry]
    var version: Int = 1
}

actor VectorStore {
    static let shared = VectorStore()

    private var documents: [VectorDocument] = []
    private var isDirty = false

    private nonisolated let binURL: URL      // Raw Float32 vectors
    private nonisolated let metaURL: URL     // JSON metadata index
    private nonisolated let legacyURL: URL   // Old single-file JSON (for migration)

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("OpusNative", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        self.binURL  = dir.appendingPathComponent("vectors.bin")
        self.metaURL = dir.appendingPathComponent("vectors.meta.json")
        self.legacyURL = dir.appendingPathComponent("vectors_legacy.json")

        // Load: try binary format first, fall back to legacy JSON
        if let loaded = Self.loadBinary(binURL: binURL, metaURL: metaURL) {
            self.documents = loaded
        } else if FileManager.default.fileExists(atPath: legacyURL.path),
                  let data = try? Data(contentsOf: legacyURL),
                  let loaded = try? JSONDecoder().decode([VectorDocument].self, from: data) {
            // Migrate legacy JSON → binary on next save
            self.documents = loaded
        } else if FileManager.default.fileExists(atPath: binURL.path),
                  let data = try? Data(contentsOf: binURL),
                  let loaded = try? JSONDecoder().decode([VectorDocument].self, from: data) {
            // Migrate old single-file JSON (vectors.bin was JSON before this fix)
            self.documents = loaded
            // Rename old file so we don't re-read it
            try? FileManager.default.moveItem(at: binURL, to: legacyURL)
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

    var count: Int { documents.count }
    var allDocuments: [VectorDocument] { documents }

    // MARK: - Search

    func search(query: [Float], topK: Int = 5) -> [VectorSearchResult] {
        guard !documents.isEmpty else { return [] }
        let results = documents.map { doc -> VectorSearchResult in
            VectorSearchResult(document: doc, score: cosineSimilarity(query, doc.vector))
        }
        return Array(results.sorted { $0.score > $1.score }.prefix(topK))
    }

    // MARK: - Cosine Similarity

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0.0 }
        var dot: Float = 0.0
        vDSP_dotpr(a, 1, b, 1, &dot, vDSP_Length(a.count))
        var magA: Float = 0.0
        vDSP_svesq(a, 1, &magA, vDSP_Length(a.count))
        var magB: Float = 0.0
        vDSP_svesq(b, 1, &magB, vDSP_Length(b.count))
        let denom = sqrt(magA) * sqrt(magB)
        return denom == 0 ? 0.0 : dot / denom
    }

    // MARK: - Persistence

    private func scheduleSave() {
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
            if isDirty { saveToDisk() }
        }
    }

    func flush() {
        if isDirty { saveToDisk() }
    }

    private func saveToDisk() {
        guard !documents.isEmpty else {
            isDirty = false
            return
        }

        // Build binary blob + metadata index simultaneously
        var binData = Data()
        var metaEntries: [VectorMeta.Entry] = []

        for doc in documents {
            guard !doc.vector.isEmpty else { continue }
            let byteOffset = binData.count
            let dimension = doc.vector.count

            // Append raw Float32 bytes
            doc.vector.withUnsafeBytes { ptr in
                binData.append(contentsOf: ptr)
            }

            metaEntries.append(VectorMeta.Entry(
                id: doc.id,
                text: doc.text,
                metadata: doc.metadata,
                dimension: dimension,
                byteOffset: byteOffset
            ))
        }

        let meta = VectorMeta(entries: metaEntries)

        do {
            try binData.write(to: binURL, options: .atomic)
            let metaData = try JSONEncoder().encode(meta)
            try metaData.write(to: metaURL, options: .atomic)
            isDirty = false
        } catch {
            print("[VectorStore] Save failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Binary Load (static — called from init before isolation)

    private static func loadBinary(binURL: URL, metaURL: URL) -> [VectorDocument]? {
        guard FileManager.default.fileExists(atPath: binURL.path),
              FileManager.default.fileExists(atPath: metaURL.path),
              let binData = try? Data(contentsOf: binURL),
              let metaData = try? Data(contentsOf: metaURL),
              let meta = try? JSONDecoder().decode(VectorMeta.self, from: metaData),
              meta.version == 1 else {
            return nil
        }

        var loaded: [VectorDocument] = []

        for entry in meta.entries {
            let byteCount = entry.dimension * MemoryLayout<Float>.size
            let start = entry.byteOffset
            let end = start + byteCount

            guard end <= binData.count else { continue }

            let vectorBytes = binData[start..<end]
            let vector: [Float] = vectorBytes.withUnsafeBytes { ptr in
                Array(ptr.bindMemory(to: Float.self))
            }

            loaded.append(VectorDocument(
                id: entry.id,
                text: entry.text,
                vector: vector,
                metadata: entry.metadata
            ))
        }

        return loaded.isEmpty ? nil : loaded
    }
}
