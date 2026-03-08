import Foundation
import SwiftData

@Model
final class UsageRecord: Identifiable {
    @Attribute(.unique) var id: UUID
    var date: Date
    var providerID: String
    var modelID: String
    var promptTokens: Int
    var completionTokens: Int
    var totalCostUSD: Double
    var requestCount: Int
    var avgLatencyMs: Double
    
    init(id: UUID = UUID(), date: Date = Date(), providerID: String, modelID: String, promptTokens: Int = 0, completionTokens: Int = 0, totalCostUSD: Double = 0.0, requestCount: Int = 1, avgLatencyMs: Double = 0.0) {
        self.id = id
        self.date = date
        self.providerID = providerID
        self.modelID = modelID
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalCostUSD = totalCostUSD
        self.requestCount = requestCount
        self.avgLatencyMs = avgLatencyMs
    }
}
