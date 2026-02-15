import Foundation
import CryptoKit
import SwiftData

// MARK: - Backup Data Models

/// Codable model representing a complete backup payload —
/// conversations, clipboard analyses, file analyses, and screenshot analyses.
struct BackupPayload: Codable {
    let timestamp: Date
    let appVersion: String
    let conversations: [ConversationBackup]
    let toolAnalyses: ToolAnalysesBackup
}

struct ConversationBackup: Codable {
    let id: String
    let title: String
    let createdAt: Date
    let updatedAt: Date
    let providerID: String
    let messages: [MessageBackup]
}

struct MessageBackup: Codable {
    let id: String
    let role: String
    let content: String
    let timestamp: Date
    let providerID: String?
    let tokenCount: Int?
    let latencyMs: Double?
}

struct ToolAnalysesBackup: Codable {
    let clipboard: [ToolAnalysisEntry]
    let files: [ToolAnalysisEntry]
    let screenshots: [ToolAnalysisEntry]
}

/// A single tool analysis entry (clipboard, file, or screenshot result)
struct ToolAnalysisEntry: Codable, Identifiable {
    let id: String
    let type: String          // "clipboard", "file", "screenshot"
    let title: String
    let content: String
    let providerID: String
    let modelName: String
    let timestamp: Date
}

// MARK: - Backup Date Info

struct BackupDateInfo: Identifiable {
    let id: String
    let date: String           // "2026-02-15"
    let displayDate: String    // "Feb 15, 2026"
    let key: String            // Full S3 key
}

// MARK: - S3 Backup Manager

/// Manages full data backup to AWS S3 with AES-256-GCM encryption.
/// Supports: conversations, clipboard/file/screenshot analyses.
/// Features: date-based organization, auto-backup, merge restore.
@Observable
@MainActor
final class S3BackupManager {
    static let shared = S3BackupManager()

    var isBackingUp = false
    var isRestoring = false
    var isListingBackups = false
    var progress: Double = 0.0
    var statusMessage: String = ""
    var errorMessage: String?
    var availableBackups: [BackupDateInfo] = []
    var lastBackupDate: Date?

    /// Auto-backup settings
    var autoBackupEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "autoBackupEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "autoBackupEnabled") }
    }

    var autoBackupIntervalMinutes: Int {
        get {
            let val = UserDefaults.standard.integer(forKey: "autoBackupInterval")
            return val > 0 ? val : 60
        }
        set { UserDefaults.standard.set(newValue, forKey: "autoBackupInterval") }
    }

    private let session = URLSession.shared
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f
    }()

    private let displayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private init() {
        // Load last backup date
        if let ts = UserDefaults.standard.object(forKey: "lastBackupTimestamp") as? Date {
            lastBackupDate = ts
        }
    }

    // MARK: - Manual Backup

    /// Full backup: serialize all data → encrypt → upload to S3 under today's date
    func backup(modelContext: ModelContext) async {
        guard let config = getS3Config() else {
            errorMessage = "S3 credentials not configured. Open Settings → Cloud Backup."
            return
        }

        isBackingUp = true
        progress = 0.0
        statusMessage = "Preparing backup..."
        errorMessage = nil

        do {
            // 1. Serialize conversations from SwiftData
            progress = 0.1
            statusMessage = "Reading conversations..."

            let descriptor = FetchDescriptor<Conversation>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
            let conversations = try modelContext.fetch(descriptor)
            let conversationBackups = conversations.map { serializeConversation($0) }

            // 2. Gather tool analyses from UserDefaults
            progress = 0.25
            statusMessage = "Reading tool analyses..."

            let toolAnalyses = ToolAnalysesBackup(
                clipboard: loadToolHistory(key: "clipboardAnalysisHistory"),
                files: loadToolHistory(key: "fileAnalysisHistory"),
                screenshots: loadToolHistory(key: "screenshotAnalysisHistory")
            )

            // 3. Build payload
            progress = 0.35
            statusMessage = "Building payload..."

            let payload = BackupPayload(
                timestamp: Date(),
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
                conversations: conversationBackups,
                toolAnalyses: toolAnalyses
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(payload)

            // 4. Encrypt
            progress = 0.5
            statusMessage = "Encrypting (\(ByteCountFormatter.string(fromByteCount: Int64(jsonData.count), countStyle: .file)))..."

            let encryptedData = try encrypt(data: jsonData)

            // 5. Upload
            progress = 0.65
            statusMessage = "Uploading to S3..."

            let dateKey = dateFormatter.string(from: Date())
            let s3Key = "opusnative/\(dateKey)/backup.enc"
            try await uploadToS3(data: encryptedData, key: s3Key, config: config)

            // 6. Done
            progress = 1.0
            let convCount = conversationBackups.count
            let toolCount = toolAnalyses.clipboard.count + toolAnalyses.files.count + toolAnalyses.screenshots.count
            statusMessage = "✓ Backed up \(convCount) conversations, \(toolCount) analyses"

            lastBackupDate = Date()
            UserDefaults.standard.set(lastBackupDate, forKey: "lastBackupTimestamp")

        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Backup failed"
        }

        isBackingUp = false
    }

    // MARK: - Auto Backup

    /// Check if auto-backup is enabled and enough time has passed, then backup
    func autoBackupIfNeeded(modelContext: ModelContext) async {
        guard autoBackupEnabled else { return }
        guard getS3Config() != nil else { return }

        let interval = TimeInterval(autoBackupIntervalMinutes * 60)

        if let last = lastBackupDate {
            guard Date().timeIntervalSince(last) > interval else { return }
        }

        // Run quietly in background (don't update UI aggressively)
        await backup(modelContext: modelContext)
    }

    // MARK: - List Available Backup Dates

    func listBackupDates() async {
        guard let config = getS3Config() else {
            errorMessage = "S3 credentials not configured."
            return
        }

        isListingBackups = true
        errorMessage = nil
        availableBackups = []

        do {
            let dates = try await listS3BackupDates(config: config)
            availableBackups = dates
        } catch {
            errorMessage = "Failed to list backups: \(error.localizedDescription)"
        }

        isListingBackups = false
    }

    // MARK: - Restore from S3

    /// Download, decrypt, and merge a specific date's backup into local data
    func restore(date: String, modelContext: ModelContext) async {
        guard let config = getS3Config() else {
            errorMessage = "S3 credentials not configured."
            return
        }

        isRestoring = true
        progress = 0.0
        statusMessage = "Downloading backup for \(date)..."
        errorMessage = nil

        do {
            // 1. Download
            progress = 0.2
            let s3Key = "opusnative/\(date)/backup.enc"
            let encryptedData = try await downloadFromS3(key: s3Key, config: config)

            // 2. Decrypt
            progress = 0.4
            statusMessage = "Decrypting..."
            let jsonData = try decrypt(data: encryptedData)

            // 3. Parse
            progress = 0.6
            statusMessage = "Parsing backup..."
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let payload = try decoder.decode(BackupPayload.self, from: jsonData)

            // 4. Merge conversations (skip existing)
            progress = 0.75
            statusMessage = "Merging conversations..."
            let mergeResult = try mergeConversations(payload.conversations, into: modelContext)

            // 5. Merge tool analyses
            progress = 0.9
            statusMessage = "Merging tool analyses..."
            mergeToolAnalyses(payload.toolAnalyses)

            // 6. Done
            progress = 1.0
            statusMessage = "✓ Restored: \(mergeResult.added) new conversations, \(mergeResult.skipped) already existed"

        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Restore failed"
        }

        isRestoring = false
    }

    // MARK: - Serialization

    private func serializeConversation(_ conversation: Conversation) -> ConversationBackup {
        let messages = conversation.sortedMessages.map { msg in
            MessageBackup(
                id: msg.id.uuidString,
                role: msg.role,
                content: msg.content,
                timestamp: msg.timestamp,
                providerID: msg.providerID,
                tokenCount: msg.tokenCount,
                latencyMs: msg.latencyMs
            )
        }

        return ConversationBackup(
            id: conversation.id.uuidString,
            title: conversation.title,
            createdAt: conversation.createdAt,
            updatedAt: conversation.updatedAt,
            providerID: conversation.providerID ?? "",
            messages: messages
        )
    }

    // MARK: - Merge Logic

    private struct MergeResult {
        let added: Int
        let skipped: Int
    }

    private func mergeConversations(_ backups: [ConversationBackup], into modelContext: ModelContext) throws -> MergeResult {
        // Get existing conversation IDs
        let descriptor = FetchDescriptor<Conversation>()
        let existing = try modelContext.fetch(descriptor)
        let existingIDs = Set(existing.map { $0.id.uuidString })

        var added = 0
        var skipped = 0

        for backup in backups {
            if existingIDs.contains(backup.id) {
                skipped += 1
                continue
            }

            // Create new conversation
            let conversation = Conversation(title: backup.title, providerID: backup.providerID.isEmpty ? nil : backup.providerID)
            if let uuid = UUID(uuidString: backup.id) {
                conversation.id = uuid
            }
            conversation.createdAt = backup.createdAt
            conversation.updatedAt = backup.updatedAt
            modelContext.insert(conversation)

            // Create messages
            for msgBackup in backup.messages {
                let message = ChatMessage(
                    role: msgBackup.role,
                    content: msgBackup.content,
                    conversation: conversation,
                    providerID: msgBackup.providerID,
                    tokenCount: msgBackup.tokenCount,
                    latencyMs: msgBackup.latencyMs
                )
                if let uuid = UUID(uuidString: msgBackup.id) {
                    message.id = uuid
                }
                message.timestamp = msgBackup.timestamp
                modelContext.insert(message)
                conversation.messages.append(message)
            }

            added += 1
        }

        try modelContext.save()
        return MergeResult(added: added, skipped: skipped)
    }

    // MARK: - Tool Analysis Persistence

    private func loadToolHistory(key: String) -> [ToolAnalysisEntry] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([ToolAnalysisEntry].self, from: data)) ?? []
    }

    private func mergeToolAnalyses(_ backup: ToolAnalysesBackup) {
        mergeToolEntries(backup.clipboard, key: "clipboardAnalysisHistory")
        mergeToolEntries(backup.files, key: "fileAnalysisHistory")
        mergeToolEntries(backup.screenshots, key: "screenshotAnalysisHistory")
    }

    private func mergeToolEntries(_ entries: [ToolAnalysisEntry], key: String) {
        var existing = loadToolHistory(key: key)
        let existingIDs = Set(existing.map { $0.id })

        for entry in entries {
            if !existingIDs.contains(entry.id) {
                existing.append(entry)
            }
        }

        if let data = try? JSONEncoder().encode(existing) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Save a tool analysis entry (called by ClipboardMonitor, FileAnalyzer, ScreenshotAnalyzer)
    static func saveToolAnalysis(type: String, title: String, content: String, toKey key: String) {
        let entry = ToolAnalysisEntry(
            id: UUID().uuidString,
            type: type,
            title: title,
            content: content,
            providerID: AIManager.shared.activeProvider?.id ?? "unknown",
            modelName: AIManager.shared.settings.modelName,
            timestamp: Date()
        )

        var history: [ToolAnalysisEntry] = []
        if let data = UserDefaults.standard.data(forKey: key) {
            history = (try? JSONDecoder().decode([ToolAnalysisEntry].self, from: data)) ?? []
        }
        history.append(entry)

        // Keep last 200 entries to avoid bloating UserDefaults
        if history.count > 200 {
            history = Array(history.suffix(200))
        }

        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // MARK: - AES-256-GCM Encryption

    private func encrypt(data: Data) throws -> Data {
        let key = getOrCreateEncryptionKey()
        let symmetricKey = SymmetricKey(data: key)
        let sealedBox = try AES.GCM.seal(data, using: symmetricKey)
        guard let combined = sealedBox.combined else {
            throw NSError(domain: "S3Backup", code: 0, userInfo: [NSLocalizedDescriptionKey: "Encryption failed"])
        }
        return combined
    }

    private func decrypt(data: Data) throws -> Data {
        let key = getOrCreateEncryptionKey()
        let symmetricKey = SymmetricKey(data: key)
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: symmetricKey)
    }

    private func getOrCreateEncryptionKey() -> Data {
        if let existingKey = KeychainService.shared.load(key: KeychainService.backupEncryptionKey),
           let keyData = Data(base64Encoded: existingKey), keyData.count == 32 {
            return keyData
        }

        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        let keyBase64 = keyData.base64EncodedString()
        KeychainService.shared.save(key: KeychainService.backupEncryptionKey, value: keyBase64)
        return keyData
    }

    // MARK: - S3 Config

    private struct S3Config {
        let accessKey: String
        let secretKey: String
        let bucket: String
        let region: String
    }

    private func getS3Config() -> S3Config? {
        guard let accessKey = KeychainService.shared.load(key: KeychainService.s3AccessKey),
              let secretKey = KeychainService.shared.load(key: KeychainService.s3SecretKey),
              !accessKey.isEmpty, !secretKey.isEmpty else {
            return nil
        }

        let bucket = KeychainService.shared.load(key: KeychainService.s3BucketName) ?? "opusnative-backups"
        let region = KeychainService.shared.load(key: KeychainService.s3Region) ?? "us-east-1"

        return S3Config(accessKey: accessKey, secretKey: secretKey, bucket: bucket, region: region)
    }

    var isConfigured: Bool {
        getS3Config() != nil
    }

    // MARK: - S3 Operations

    private func uploadToS3(data: Data, key: String, config: S3Config) async throws {
        let endpoint = "https://\(config.bucket).s3.\(config.region).amazonaws.com/\(key)"
        guard let url = URL(string: endpoint) else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = data
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        try signS3Request(request: &request, body: data, config: config, httpMethod: "PUT", path: "/\(key)", queryString: "")

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw NSError(domain: "S3", code: code, userInfo: [NSLocalizedDescriptionKey: "S3 upload failed (HTTP \(code))"])
        }
    }

    private func downloadFromS3(key: String, config: S3Config) async throws -> Data {
        let endpoint = "https://\(config.bucket).s3.\(config.region).amazonaws.com/\(key)"
        guard let url = URL(string: endpoint) else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        try signS3Request(request: &request, body: Data(), config: config, httpMethod: "GET", path: "/\(key)", queryString: "")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw NSError(domain: "S3", code: code, userInfo: [NSLocalizedDescriptionKey: "S3 download failed (HTTP \(code))"])
        }

        return data
    }

    private func listS3BackupDates(config: S3Config) async throws -> [BackupDateInfo] {
        let prefix = "opusnative/"
        let queryString = "delimiter=%2F&list-type=2&prefix=\(prefix)"
        let endpoint = "https://\(config.bucket).s3.\(config.region).amazonaws.com/?\(queryString)"
        guard let url = URL(string: endpoint) else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        try signS3Request(request: &request, body: Data(), config: config, httpMethod: "GET", path: "/", queryString: queryString)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw NSError(domain: "S3", code: code, userInfo: [NSLocalizedDescriptionKey: "Failed to list S3 objects (HTTP \(code))"])
        }

        // Parse XML response to find CommonPrefixes (date folders)
        let xml = String(data: data, encoding: .utf8) ?? ""
        return parseBackupDates(from: xml)
    }

    private func parseBackupDates(from xml: String) -> [BackupDateInfo] {
        var dates: [BackupDateInfo] = []

        // Extract <Prefix> values from <CommonPrefixes> blocks
        var remaining = xml
        while let prefixStart = remaining.range(of: "<Prefix>"),
              let prefixEnd = remaining.range(of: "</Prefix>") {
            let prefix = String(remaining[prefixStart.upperBound..<prefixEnd.lowerBound])
            remaining = String(remaining[prefixEnd.upperBound...])

            // Extract date from "opusnative/2026-02-15/"
            let parts = prefix.split(separator: "/")
            if parts.count >= 2 {
                let dateStr = String(parts[1])

                // Convert to display date
                let displayDate: String
                if let date = dateFormatter.date(from: dateStr) {
                    displayDate = displayDateFormatter.string(from: date)
                } else {
                    displayDate = dateStr
                }

                dates.append(BackupDateInfo(
                    id: dateStr,
                    date: dateStr,
                    displayDate: displayDate,
                    key: "opusnative/\(dateStr)/backup.enc"
                ))
            }
        }

        return dates.sorted { $0.date > $1.date } // newest first
    }

    // MARK: - SigV4 Signing

    private func signS3Request(request: inout URLRequest, body: Data, config: S3Config, httpMethod: String, path: String, queryString: String) throws {
        let date = Date()
        let amzDateFormatter = DateFormatter()
        amzDateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        amzDateFormatter.timeZone = TimeZone(identifier: "UTC")
        let amzDate = amzDateFormatter.string(from: date)

        let shortDateFormatter = DateFormatter()
        shortDateFormatter.dateFormat = "yyyyMMdd"
        shortDateFormatter.timeZone = TimeZone(identifier: "UTC")
        let dateShort = shortDateFormatter.string(from: date)

        let host = "\(config.bucket).s3.\(config.region).amazonaws.com"
        request.setValue(amzDate, forHTTPHeaderField: "x-amz-date")
        request.setValue(host, forHTTPHeaderField: "host")

        let payloadHash = SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined()
        request.setValue(payloadHash, forHTTPHeaderField: "x-amz-content-sha256")

        let signedHeaders = "host;x-amz-content-sha256;x-amz-date"
        let canonicalHeaders = "host:\(host)\nx-amz-content-sha256:\(payloadHash)\nx-amz-date:\(amzDate)\n"

        let canonicalRequest = [
            httpMethod,
            path,
            queryString,
            canonicalHeaders,
            signedHeaders,
            payloadHash
        ].joined(separator: "\n")

        let credentialScope = "\(dateShort)/\(config.region)/s3/aws4_request"
        let canonicalRequestHash = SHA256.hash(data: Data(canonicalRequest.utf8)).map { String(format: "%02x", $0) }.joined()
        let stringToSign = "AWS4-HMAC-SHA256\n\(amzDate)\n\(credentialScope)\n\(canonicalRequestHash)"

        let kDate = hmac(key: ("AWS4" + config.secretKey).data(using: .utf8)!, data: dateShort.data(using: .utf8)!)
        let kRegion = hmac(key: kDate, data: config.region.data(using: .utf8)!)
        let kService = hmac(key: kRegion, data: "s3".data(using: .utf8)!)
        let kSigning = hmac(key: kService, data: "aws4_request".data(using: .utf8)!)
        let signature = hmac(key: kSigning, data: stringToSign.data(using: .utf8)!)
            .map { String(format: "%02x", $0) }.joined()

        let authHeader = "AWS4-HMAC-SHA256 Credential=\(config.accessKey)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)"
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
    }

    private func hmac(key: Data, data: Data) -> Data {
        let symmetricKey = SymmetricKey(data: key)
        return Data(HMAC<SHA256>.authenticationCode(for: data, using: symmetricKey))
    }
}
