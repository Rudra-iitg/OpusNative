import Foundation

// MARK: - Master Backup

struct MasterBackup: Codable {
    let schemaVersion: Int
    let appVersion: String
    let createdAt: Date
    let deviceName: String
    let backupID: UUID
    let sections: BackupSections
}

struct BackupSections: Codable {
    let conversations: [BackedUpConversation]
    let comparisons: [BackedUpComparisonSession]
    let codeSessions: [BackedUpCodeSession]
    let embeddings: [BackedUpEmbeddingDocument]
    let toolAnalyses: [BackedUpToolAnalysis]
    let usageLogs: [BackedUpUsageRecord]
    let settings: BackedUpSettings
    let manifest: BackupManifest
}

struct BackupManifest: Codable {
    let conversationCount: Int
    let messageCount: Int
    let comparisonCount: Int
    let codeSessionCount: Int
    let embeddingCount: Int
    let toolAnalysisCount: Int
    let usageRecordCount: Int
    let totalSizeBytes: Int
    let providersIncluded: [String]
    let dateRange: DateRange
}

struct DateRange: Codable {
    let from: Date
    let to: Date
}

// MARK: - Backed Up Entities

struct BackedUpConversation: Codable, Identifiable {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var providerID: String?
    var activeBranchLeafID: UUID?
    var messages: [BackedUpMessage]
}

struct BackedUpMessage: Codable, Identifiable {
    var id: UUID
    var role: String
    var content: String
    var timestamp: Date
    var parentMessageID: UUID?
    var providerID: String?
    var tokenCount: Int?
    var latencyMs: Double?
    var model: String?
}

struct BackedUpComparisonSession: Codable, Identifiable {
    var id: UUID
    var prompt: String
    var createdAt: Date
    var results: [BackedUpComparisonResult]
}

struct BackedUpComparisonResult: Codable, Identifiable {
    var id: UUID
    var sessionID: UUID
    var providerID: String
    var modelID: String
    var response: String
    var tokenCount: Int?
    var latencyMs: Double?
    var costUSD: Double?
    var rank: Int?
}

struct BackedUpCodeSession: Codable, Identifiable {
    var id: UUID
    var originalCode: String
    var language: String
    var action: String
    var aiResponse: String
    var providerID: String
    var modelID: String
    var createdAt: Date
}

struct BackedUpEmbeddingDocument: Codable, Identifiable {
    var id: UUID
    var sourceText: String
    var label: String?
    var vector: [Float]
    var model: String?
    var metadata: [String: String]
}

struct BackedUpToolAnalysis: Codable, Identifiable {
    var id: String
    var type: String
    var title: String
    var content: String
    var providerID: String
    var modelName: String
    var timestamp: Date
}

struct BackedUpUsageRecord: Codable, Identifiable {
    var id: UUID
    var date: Date
    var providerID: String
    var modelID: String
    var promptTokens: Int
    var completionTokens: Int
    var totalCostUSD: Double
    var requestCount: Int
    var avgLatencyMs: Double
}

struct BackedUpSettings: Codable {
    var selectedModelPerProvider: [String: String]
    var personaName: String?
    var personaSystemPrompt: String?
    var autoBackupEnabled: Bool
    var autoBackupIntervalMinutes: Int
    // Additional settings can be added here
}
