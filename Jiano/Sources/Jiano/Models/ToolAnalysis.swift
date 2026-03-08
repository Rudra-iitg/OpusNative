import Foundation
import SwiftData

@Model
final class ToolAnalysis: Identifiable {
    @Attribute(.unique) var id: UUID
    var type: String          // "clipboard", "file", "screenshot"
    var title: String
    var content: String
    var providerID: String
    var modelName: String
    var timestamp: Date
    
    // Optional base64 encoded image string if it's a screenshot
    @Attribute(.externalStorage) var base64Image: String?

    init(id: UUID = UUID(), type: String, title: String, content: String, providerID: String, modelName: String, timestamp: Date = Date(), base64Image: String? = nil) {
        self.id = id
        self.type = type
        self.title = title
        self.content = content
        self.providerID = providerID
        self.modelName = modelName
        self.timestamp = timestamp
        self.base64Image = base64Image
    }
}

// MARK: - Legacy UserDefaults Representation
struct ToolAnalysisEntry: Codable, Identifiable {
    let id: String
    let type: String          // "clipboard", "file", "screenshot"
    let title: String
    let content: String
    let providerID: String
    let modelName: String
    let timestamp: Date
}
