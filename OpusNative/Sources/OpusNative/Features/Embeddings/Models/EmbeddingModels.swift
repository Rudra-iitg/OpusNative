import Foundation
import SwiftData

/// Represents a single embedding entry.
/// Stores the input text, the generated vector, and metadata about the model used.
@Model
final class EmbeddingItem {
    /// Unique identifier for the embedding item.
    var id: UUID
    
    /// The original text input used to generate the embedding.
    var text: String
    
    /// The high-dimensional vector representation.
    /// Storage: We store this as a standard array of Doubles.
    /// Note: SwiftData handles simple arrays of standard types efficiently.
    var vector: [Double]
    
    /// The name of the model used (e.g., "nomic-embed-text").
    var model: String
    
    /// The dimension size of the vector (e.g., 768).
    var dimension: Int
    
    /// When this embedding was created.
    var createdAt: Date
    
    /// Optional relationship to a collection.
    var collection: EmbeddingCollection?
    
    init(text: String, vector: [Double], model: String) {
        self.id = UUID()
        self.text = text
        self.vector = vector
        self.model = model
        self.dimension = vector.count
        self.createdAt = Date()
    }
}

/// Represents a group of embeddings (e.g., a specific dataset or session).
@Model
final class EmbeddingCollection {
    var id: UUID
    var name: String
    var items: [EmbeddingItem]?
    var createdAt: Date
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.items = []
    }
}
