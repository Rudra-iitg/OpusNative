import Foundation
import SwiftData

@Model
final class CodeSession: Identifiable {
    @Attribute(.unique) var id: UUID
    var originalCode: String
    var language: String
    var action: String
    var aiResponse: String
    var providerID: String
    var modelID: String
    var createdAt: Date
    
    init(originalCode: String, language: String, action: String, aiResponse: String, providerID: String, modelID: String, createdAt: Date = Date()) {
        self.id = UUID()
        self.originalCode = originalCode
        self.language = language
        self.action = action
        self.aiResponse = aiResponse
        self.providerID = providerID
        self.modelID = modelID
        self.createdAt = createdAt
    }
}
