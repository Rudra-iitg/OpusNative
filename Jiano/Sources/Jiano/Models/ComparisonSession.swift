import Foundation
import SwiftData

@Model
final class ComparisonSession: Identifiable {
    @Attribute(.unique) var id: UUID
    var prompt: String
    var createdAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \ComparisonResult.session)
    var results: [ComparisonResult] = []
    
    init(prompt: String, createdAt: Date = Date()) {
        self.id = UUID()
        self.prompt = prompt
        self.createdAt = createdAt
    }
}

@Model
final class ComparisonResult: Identifiable {
    @Attribute(.unique) var id: UUID
    var session: ComparisonSession?
    var providerID: String
    var modelID: String
    var response: String
    var tokenCount: Int?
    var latencyMs: Double?
    var costUSD: Double?
    var rank: Int?
    
    init(providerID: String, modelID: String, response: String, tokenCount: Int? = nil, latencyMs: Double? = nil, costUSD: Double? = nil, rank: Int? = nil) {
        self.id = UUID()
        self.providerID = providerID
        self.modelID = modelID
        self.response = response
        self.tokenCount = tokenCount
        self.latencyMs = latencyMs
        self.costUSD = costUSD
        self.rank = rank
    }
}
