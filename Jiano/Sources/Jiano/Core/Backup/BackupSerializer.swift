import Foundation
import SwiftData

@MainActor
class BackupSerializer {
    
    func serialize(context: ModelContext) async throws -> MasterBackup {
        let conversations = try await serializeConversations(context: context)
        let comparisons = try await serializeComparisons(context: context)
        let codeSessions = try await serializeCodeSessions(context: context)
        let embeddings = try await serializeEmbeddings()
        let toolAnalyses = try await serializeToolAnalyses(context: context)
        let usageLogs = try await serializeUsageLogs(context: context)
        let settings = serializeSettings()
        
        let sections = BackupSections(
            conversations: conversations,
            comparisons: comparisons,
            codeSessions: codeSessions,
            embeddings: embeddings,
            toolAnalyses: toolAnalyses,
            usageLogs: usageLogs,
            settings: settings,
            manifest: buildManifest(
                conversations: conversations,
                comparisons: comparisons,
                codeSessions: codeSessions,
                embeddings: embeddings,
                toolAnalyses: toolAnalyses,
                usageLogs: usageLogs
            )
        )
        
        return MasterBackup(
            schemaVersion: 2,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            createdAt: Date(),
            deviceName: Host.current().localizedName ?? "Mac",
            backupID: UUID(),
            sections: sections
        )
    }
    
    private func serializeConversations(context: ModelContext) async throws -> [BackedUpConversation] {
        let descriptor = FetchDescriptor<Conversation>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        let conversations = try context.fetch(descriptor)
        
        return conversations.map { conv in
            BackedUpConversation(
                id: conv.id,
                title: conv.title,
                createdAt: conv.createdAt,
                updatedAt: conv.updatedAt,
                providerID: conv.providerID,
                activeBranchLeafID: conv.activeBranchLeafID,
                messages: conv.messages.map { msg in
                    BackedUpMessage(
                        id: msg.id,
                        role: msg.role,
                        content: msg.content,
                        timestamp: msg.timestamp,
                        parentMessageID: msg.parentMessageID,
                        providerID: msg.providerID,
                        tokenCount: msg.tokenCount,
                        latencyMs: msg.latencyMs,
                        model: msg.model
                    )
                }
            )
        }
    }
    
    private func serializeComparisons(context: ModelContext) async throws -> [BackedUpComparisonSession] {
        let descriptor = FetchDescriptor<ComparisonSession>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let sessions = try context.fetch(descriptor)
        
        return sessions.map { session in
            BackedUpComparisonSession(
                id: session.id,
                prompt: session.prompt,
                createdAt: session.createdAt,
                results: session.results.map { res in
                    BackedUpComparisonResult(
                        id: res.id,
                        sessionID: session.id,
                        providerID: res.providerID,
                        modelID: res.modelID,
                        response: res.response,
                        tokenCount: res.tokenCount,
                        latencyMs: res.latencyMs,
                        costUSD: res.costUSD,
                        rank: res.rank
                    )
                }
            )
        }
    }
    
    private func serializeCodeSessions(context: ModelContext) async throws -> [BackedUpCodeSession] {
        let descriptor = FetchDescriptor<CodeSession>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let sessions = try context.fetch(descriptor)
        
        return sessions.map { session in
            BackedUpCodeSession(
                id: session.id,
                originalCode: session.originalCode,
                language: session.language,
                action: session.action,
                aiResponse: session.aiResponse,
                providerID: session.providerID,
                modelID: session.modelID,
                createdAt: session.createdAt
            )
        }
    }
    
    private func serializeEmbeddings() async throws -> [BackedUpEmbeddingDocument] {
        let docs = await VectorStore.shared.allDocuments
        return docs.map { doc in
            BackedUpEmbeddingDocument(
                id: doc.id,
                sourceText: doc.text,
                label: doc.metadata["label"],
                vector: doc.vector,
                model: doc.metadata["model"],
                metadata: doc.metadata
            )
        }
    }
    
    private func serializeToolAnalyses(context: ModelContext) async throws -> [BackedUpToolAnalysis] {
        let descriptor = FetchDescriptor<ToolAnalysis>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        let analyses = try context.fetch(descriptor)
        
        return analyses.map { analysis in
            BackedUpToolAnalysis(
                id: analysis.id.uuidString,
                type: analysis.type,
                title: analysis.title,
                content: analysis.content,
                providerID: analysis.providerID,
                modelName: analysis.modelName,
                timestamp: analysis.timestamp
            )
        }
    }
    
    private func serializeUsageLogs(context: ModelContext) async throws -> [BackedUpUsageRecord] {
        let descriptor = FetchDescriptor<UsageRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let records = try context.fetch(descriptor)
        
        return records.map { rec in
            BackedUpUsageRecord(
                id: rec.id,
                date: rec.date,
                providerID: rec.providerID,
                modelID: rec.modelID,
                promptTokens: rec.promptTokens,
                completionTokens: rec.completionTokens,
                totalCostUSD: rec.totalCostUSD,
                requestCount: rec.requestCount,
                avgLatencyMs: rec.avgLatencyMs
            )
        }
    }
    
    private func serializeSettings() -> BackedUpSettings {
        let defaults = UserDefaults.standard
        // Extract basic logic (adjust as needed based on actual standard setup)
        var selectedModelPerProvider: [String: String] = [:]
        
        // This is a naive fetch. A deeper fetch based on how they're stored is needed.
        // Assuming they are stored per provider IDs if accessible.
        let autoBackupEnabled = defaults.bool(forKey: "autoBackupEnabled")
        let autoBackupIntervalMinutes = defaults.integer(forKey: "autoBackupInterval") > 0 ? defaults.integer(forKey: "autoBackupInterval") : 60
        let personaName = defaults.string(forKey: "personaName")
        let personaSystemPrompt = defaults.string(forKey: "personaSystemPrompt")
        
        return BackedUpSettings(
            selectedModelPerProvider: selectedModelPerProvider,
            personaName: personaName,
            personaSystemPrompt: personaSystemPrompt,
            autoBackupEnabled: autoBackupEnabled,
            autoBackupIntervalMinutes: autoBackupIntervalMinutes
        )
    }
    
    private func buildManifest(
        conversations: [BackedUpConversation],
        comparisons: [BackedUpComparisonSession],
        codeSessions: [BackedUpCodeSession],
        embeddings: [BackedUpEmbeddingDocument],
        toolAnalyses: [BackedUpToolAnalysis],
        usageLogs: [BackedUpUsageRecord]
    ) -> BackupManifest {
        
        let messageCount = conversations.reduce(0) { $0 + $1.messages.count }
        
        var providers = Set<String>()
        conversations.compactMap(\.providerID).forEach { providers.insert($0) }
        comparisons.flatMap(\.results).map(\.providerID).forEach { providers.insert($0) }
        codeSessions.map(\.providerID).forEach { providers.insert($0) }
        toolAnalyses.map(\.providerID).forEach { providers.insert($0) }
        usageLogs.map(\.providerID).forEach { providers.insert($0) }
        
        let allDates = conversations.map(\.createdAt) +
                       comparisons.map(\.createdAt) +
                       codeSessions.map(\.createdAt) +
                       toolAnalyses.map(\.timestamp) +
                       usageLogs.map(\.date)
        
        let minDate = allDates.min() ?? Date()
        let maxDate = allDates.max() ?? Date()
        
        return BackupManifest(
            conversationCount: conversations.count,
            messageCount: messageCount,
            comparisonCount: comparisons.count,
            codeSessionCount: codeSessions.count,
            embeddingCount: embeddings.count,
            toolAnalysisCount: toolAnalyses.count,
            usageRecordCount: usageLogs.count,
            totalSizeBytes: 0, // Calculated after JSON encoding
            providersIncluded: Array(providers).sorted(),
            dateRange: DateRange(from: minDate, to: maxDate)
        )
    }
}
