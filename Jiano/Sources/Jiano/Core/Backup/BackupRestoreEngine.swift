import Foundation
import SwiftData

@MainActor
class BackupRestoreEngine {
    
    struct RestoreOptions {
        var restoreConversations: Bool = true
        var restoreComparisons: Bool = true
        var restoreCodeSessions: Bool = true
        var restoreEmbeddings: Bool = true
        var restoreToolAnalyses: Bool = true
        var restoreUsageLogs: Bool = true
        var restoreSettings: Bool = false
    }
    
    struct RestoreResult {
        var addedConversations: Int = 0
        var addedComparisons: Int = 0
        var addedCodeSessions: Int = 0
        var addedEmbeddings: Int = 0
        var addedToolAnalyses: Int = 0
        var addedUsageLogs: Int = 0
    }
    
    let s3Manager = S3BackupManager.shared
    
    func restore(
        manifestFile: BackupManifestFile,
        options: RestoreOptions,
        context: ModelContext,
        onProgress: @escaping (String, Double) -> Void
    ) async throws -> RestoreResult {
        
        guard let config = s3Manager.getS3Config() else {
            throw NSError(domain: "Restore", code: 1, userInfo: [NSLocalizedDescriptionKey: "S3 credentials missing"])
        }
        var result = RestoreResult()
        
        // 1. Download
        onProgress("Downloading backup payload...", 0.1)
        let encryptedData = try await s3Manager.downloadFromS3(key: manifestFile.payloadKey, config: config)
        
        // 2. Decrypt
        onProgress("Decrypting payload...", 0.3)
        let jsonData = try s3Manager.decrypt(data: encryptedData)
        
        // 3. Decode
        onProgress("Decoding payload...", 0.4)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let master = try decoder.decode(MasterBackup.self, from: jsonData)
        
        // 4. Restore Items
        let totalSteps = 6.0
        var currentStep = 0.0
        
        func stepProgress(msg: String) {
            currentStep += 1.0
            onProgress(msg, 0.4 + 0.6 * (currentStep / totalSteps))
        }
        
        if options.restoreConversations {
            stepProgress(msg: "Restoring conversations...")
            result.addedConversations = try restoreConversations(master.sections.conversations, context: context)
        } else { stepProgress(msg: "Skipping conversations...") }
        
        if options.restoreComparisons {
            stepProgress(msg: "Restoring comparisons...")
            result.addedComparisons = try restoreComparisons(master.sections.comparisons, context: context)
        } else { stepProgress(msg: "Skipping comparisons...") }
        
        if options.restoreCodeSessions {
            stepProgress(msg: "Restoring code sessions...")
            result.addedCodeSessions = try restoreCodeSessions(master.sections.codeSessions, context: context)
        } else { stepProgress(msg: "Skipping code sessions...") }
        
        if options.restoreEmbeddings {
            stepProgress(msg: "Restoring document embeddings...")
            result.addedEmbeddings = await restoreEmbeddings(master.sections.embeddings)
        } else { stepProgress(msg: "Skipping embeddings...") }
        
        if options.restoreToolAnalyses {
            stepProgress(msg: "Restoring tool analyses...")
            result.addedToolAnalyses = try restoreToolAnalyses(master.sections.toolAnalyses, context: context)
        } else { stepProgress(msg: "Skipping tool analyses...") }
        
        if options.restoreUsageLogs {
            stepProgress(msg: "Restoring usage statistics...")
            result.addedUsageLogs = try restoreUsageLogs(master.sections.usageLogs, context: context)
        } else { stepProgress(msg: "Skipping usage statistics...") }
        
        if options.restoreSettings {
            // Usually, overriding current system settings/keys can be dangerous.
            // As per requirements, we will implement this minimally.
            restoreSettings(master.sections.settings)
        }
        
        try context.save()
        onProgress("Restore complete!", 1.0)
        return result
    }
    
    // MARK: - Restore Logic
    
    private func restoreConversations(_ items: [BackedUpConversation], context: ModelContext) throws -> Int {
        let existing = try context.fetch(FetchDescriptor<Conversation>())
        let existingIDs = Set(existing.map(\.id))
        var count = 0
        
        for item in items {
            guard !existingIDs.contains(item.id) else { continue }
            let conv = Conversation(title: item.title, providerID: item.providerID)
            conv.id = item.id
            conv.createdAt = item.createdAt
            conv.updatedAt = item.updatedAt
            conv.activeBranchLeafID = item.activeBranchLeafID
            
            context.insert(conv)
            
            for msg in item.messages {
                let m = ChatMessage(role: msg.role, content: msg.content, conversation: conv, providerID: msg.providerID, tokenCount: msg.tokenCount, latencyMs: msg.latencyMs)
                m.id = msg.id
                m.timestamp = msg.timestamp
                m.model = msg.model
                m.parentMessageID = msg.parentMessageID
                context.insert(m)
                conv.messages.append(m)
            }
            count += 1
        }
        return count
    }
    
    private func restoreComparisons(_ items: [BackedUpComparisonSession], context: ModelContext) throws -> Int {
        let existing = try context.fetch(FetchDescriptor<ComparisonSession>())
        let existingIDs = Set(existing.map(\.id))
        var count = 0
        
        for item in items {
            guard !existingIDs.contains(item.id) else { continue }
            let session = ComparisonSession(prompt: item.prompt)
            session.id = item.id
            session.createdAt = item.createdAt
            context.insert(session)
            
            for res in item.results {
                let result = ComparisonResult(providerID: res.providerID, modelID: res.modelID, response: res.response, tokenCount: res.tokenCount, latencyMs: res.latencyMs, costUSD: res.costUSD, rank: res.rank)
                result.id = res.id
                result.session = session
                context.insert(result)
                session.results.append(result)
            }
            count += 1
        }
        return count
    }
    
    private func restoreCodeSessions(_ items: [BackedUpCodeSession], context: ModelContext) throws -> Int {
        let existing = try context.fetch(FetchDescriptor<CodeSession>())
        let existingIDs = Set(existing.map(\.id))
        var count = 0
        
        for item in items {
            guard !existingIDs.contains(item.id) else { continue }
            let session = CodeSession(
                originalCode: item.originalCode,
                language: item.language,
                action: item.action,
                aiResponse: item.aiResponse,
                providerID: item.providerID,
                modelID: item.modelID,
                createdAt: item.createdAt
            )
            session.id = item.id
            context.insert(session)
            count += 1
        }
        return count
    }
    
    private func restoreEmbeddings(_ items: [BackedUpEmbeddingDocument]) async -> Int {
        let store = VectorStore.shared
        // Optimization: since VectorStore is an in-memory or custom construct,
        // we can fetch existing IDs and only insert new ones.
        let existingDocs = await store.allDocuments
        let existingIDs = Set(existingDocs.map(\.id))
        var count = 0
        
        for item in items {
            guard !existingIDs.contains(item.id) else { continue }
            let doc = VectorDocument(
                id: item.id,
                text: item.sourceText,
                vector: item.vector,
                metadata: item.metadata
            )
            await store.add(document: doc)
            count += 1
        }
        return count
    }
    
    private func restoreToolAnalyses(_ items: [BackedUpToolAnalysis], context: ModelContext) throws -> Int {
        let existing = try context.fetch(FetchDescriptor<ToolAnalysis>())
        let existingIDs = Set(existing.map(\.id.uuidString))
        var count = 0
        
        for item in items {
            guard !existingIDs.contains(item.id) else { continue }
            if let uuid = UUID(uuidString: item.id) {
                let analysis = ToolAnalysis(
                    id: uuid,
                    type: item.type,
                    title: item.title,
                    content: item.content,
                    providerID: item.providerID,
                    modelName: item.modelName,
                    timestamp: item.timestamp
                )
                context.insert(analysis)
                count += 1
            }
        }
        return count
    }
    
    private func restoreUsageLogs(_ items: [BackedUpUsageRecord], context: ModelContext) throws -> Int {
        let existing = try context.fetch(FetchDescriptor<UsageRecord>())
        let existingIDs = Set(existing.map(\.id))
        var count = 0
        
        for item in items {
            guard !existingIDs.contains(item.id) else { continue }
            let rec = UsageRecord(
                id: item.id,
                date: item.date,
                providerID: item.providerID,
                modelID: item.modelID,
                promptTokens: item.promptTokens,
                completionTokens: item.completionTokens,
                totalCostUSD: item.totalCostUSD,
                requestCount: item.requestCount,
                avgLatencyMs: item.avgLatencyMs
            )
            context.insert(rec)
            count += 1
        }
        return count
    }
    
    private func restoreSettings(_ settings: BackedUpSettings) {
        let defaults = UserDefaults.standard
        if defaults.string(forKey: "personaName") == nil {
            if let pName = settings.personaName { defaults.set(pName, forKey: "personaName") }
            if let pPrompt = settings.personaSystemPrompt { defaults.set(pPrompt, forKey: "personaSystemPrompt") }
        }
        if defaults.object(forKey: "autoBackupEnabled") == nil {
            defaults.set(settings.autoBackupEnabled, forKey: "autoBackupEnabled")
        }
        if defaults.object(forKey: "autoBackupInterval") == nil {
            defaults.set(settings.autoBackupIntervalMinutes, forKey: "autoBackupInterval")
        }
    }
}
