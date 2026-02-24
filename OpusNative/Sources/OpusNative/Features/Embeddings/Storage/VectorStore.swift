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

    /// Binary format magic bytes and version for forward compatibility
    private static let magicBytes: UInt32 = 0x4F505553  // "OPUS"
    private static let formatVersion: UInt32 = 1

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("OpusNative", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.storageURL = dir.appendingPathComponent("vectors.bin")

        // Load persisted documents (try binary first, fall back to legacy JSON)
        if FileManager.default.fileExists(atPath: storageURL.path),
           let data = try? Data(contentsOf: storageURL) {
            if let loaded = Self.decodeBinary(data) {
                self.documents = loaded
            } else if let loaded = try? JSONDecoder().decode([VectorDocument].self, from: data) {
                // Legacy JSON migration — mark dirty so next save writes binary
                self.documents = loaded
                self.isDirty = true
            }
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

    /// Serialize documents to disk in binary format
    private func saveToDisk() {
        do {
            let data = Self.encodeBinary(documents)
            try data.write(to: storageURL, options: .atomic)
            isDirty = false
        } catch {
            print("[VectorStore] Save failed: \(error.localizedDescription)")
        }
    }

    /// Force an immediate save (call before app termination)
    func flush() {
        if isDirty {
            saveToDisk()
        }
    }

    // MARK: - Binary Format
    //
    // Layout:
    //   [magic: UInt32] [version: UInt32] [docCount: UInt32]
    //   For each document:
    //     [metadataLen: UInt32] [metadataJSON: bytes]  (id, text, metadata as JSON — no vector)
    //     [vectorCount: UInt32] [floats: vectorCount * 4 bytes]

    /// Lightweight Codable shell used to persist everything except the vector
    private struct DocumentMeta: Codable {
        let id: UUID
        let text: String
        let metadata: [String: String]
    }

    private static func encodeBinary(_ documents: [VectorDocument]) -> Data {
        var data = Data()

        // Header
        var magic = magicBytes
        data.append(Data(bytes: &magic, count: 4))
        var version = formatVersion
        data.append(Data(bytes: &version, count: 4))
        var count = UInt32(documents.count)
        data.append(Data(bytes: &count, count: 4))

        let encoder = JSONEncoder()

        for doc in documents {
            // Metadata (JSON, compact)
            let meta = DocumentMeta(id: doc.id, text: doc.text, metadata: doc.metadata)
            let metaData = (try? encoder.encode(meta)) ?? Data()
            var metaLen = UInt32(metaData.count)
            data.append(Data(bytes: &metaLen, count: 4))
            data.append(metaData)

            // Vector (raw Float32 bytes)
            var vecCount = UInt32(doc.vector.count)
            data.append(Data(bytes: &vecCount, count: 4))
            doc.vector.withUnsafeBufferPointer { buffer in
                data.append(UnsafeBufferPointer(start: buffer.baseAddress, count: buffer.count))
            }
        }

        return data
    }

    private static func decodeBinary(_ data: Data) -> [VectorDocument]? {
        guard data.count >= 12 else { return nil }

        var offset = 0

        func readUInt32() -> UInt32? {
            guard offset + 4 <= data.count else { return nil }
            let value = data[offset..<offset+4].withUnsafeBytes { $0.load(as: UInt32.self) }
            offset += 4
            return value
        }

        guard let magic = readUInt32(), magic == magicBytes else { return nil }
        guard let version = readUInt32(), version == formatVersion else { return nil }
        guard let docCount = readUInt32() else { return nil }

        let decoder = JSONDecoder()
        var documents: [VectorDocument] = []
        documents.reserveCapacity(Int(docCount))

        for _ in 0..<docCount {
            guard let metaLen = readUInt32() else { return nil }
            guard offset + Int(metaLen) <= data.count else { return nil }
            let metaData = data[offset..<offset+Int(metaLen)]
            offset += Int(metaLen)

            guard let meta = try? decoder.decode(DocumentMeta.self, from: metaData) else { return nil }

            guard let vecCount = readUInt32() else { return nil }
            let floatBytes = Int(vecCount) * MemoryLayout<Float>.size
            guard offset + floatBytes <= data.count else { return nil }

            let vector: [Float] = data[offset..<offset+floatBytes].withUnsafeBytes { rawBuffer in
                Array(rawBuffer.bindMemory(to: Float.self))
            }
            offset += floatBytes

            documents.append(VectorDocument(id: meta.id, text: meta.text, vector: vector, metadata: meta.metadata))
        }

        return documents
    }
}
