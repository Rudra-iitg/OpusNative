import Foundation
import CryptoKit
import SwiftData

// MARK: - Backup Manifest Info

struct BackupManifestFile: Codable, Identifiable {
    var id: UUID { backupID }
    let backupID: UUID
    let createdAt: Date
    let deviceName: String
    let appVersion: String
    var schemaVersion: Int = 1
    let payloadKey: String
    let manifest: BackupManifest
    
    enum CodingKeys: String, CodingKey {
        case backupID, createdAt, deviceName, appVersion, schemaVersion, payloadKey, manifest
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        backupID = try container.decodeIfPresent(UUID.self, forKey: .backupID) ?? UUID()
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        deviceName = try container.decodeIfPresent(String.self, forKey: .deviceName) ?? "Unknown Device"
        appVersion = try container.decodeIfPresent(String.self, forKey: .appVersion) ?? "1.0"
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        payloadKey = try container.decodeIfPresent(String.self, forKey: .payloadKey) ?? ""
        manifest = try container.decodeIfPresent(BackupManifest.self, forKey: .manifest) ?? BackupManifest(
            conversationCount: 0, messageCount: 0, comparisonCount: 0, codeSessionCount: 0,
            embeddingCount: 0, toolAnalysisCount: 0, usageRecordCount: 0, totalSizeBytes: 0,
            providersIncluded: [], dateRange: DateRange(from: Date(), to: Date())
        )
    }
    
    init(backupID: UUID, createdAt: Date, deviceName: String, appVersion: String, schemaVersion: Int, payloadKey: String, manifest: BackupManifest) {
        self.backupID = backupID
        self.createdAt = createdAt
        self.deviceName = deviceName
        self.appVersion = appVersion
        self.schemaVersion = schemaVersion
        self.payloadKey = payloadKey
        self.manifest = manifest
    }
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
    /// Errors during last backup/restore
    var errorMessage: String?
    
    var aiManager: AIManager!
    var availableBackups: [BackupManifestFile] = []
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
    private let s3DateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private let s3TimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH-mm-ss"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    init() {
        // Load last backup date
        if let ts = UserDefaults.standard.object(forKey: "lastBackupTimestamp") as? Date {
            lastBackupDate = ts
        }
    }

    // MARK: - Manual Backup

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
            // 1. Serialize all data
            progress = 0.2
            statusMessage = "Serializing app data..."
            let serializer = BackupSerializer()
            let masterBackup = try await serializer.serialize(context: modelContext)
            
            // 2. Encode payload
            progress = 0.4
            statusMessage = "Building payload..."
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let payloadData = try encoder.encode(masterBackup)
            
            // 3. Encrypt payload
            progress = 0.5
            statusMessage = "Encrypting (\(ByteCountFormatter.string(fromByteCount: Int64(payloadData.count), countStyle: .file)))..."
            let encryptedData = try encrypt(data: payloadData)
            
            // 4. Generate metadata & keys
            let dateStr = s3DateFormatter.string(from: masterBackup.createdAt)
            let timeStr = s3TimeFormatter.string(from: masterBackup.createdAt)
            let idStr = masterBackup.backupID.uuidString.lowercased()
            
            let payloadKey = "opusnative-backups/backups/\(dateStr)/\(timeStr)-\(idStr).enc"
            let manifestKey = "opusnative-backups/manifests/\(idStr).json"
            
            let manifestFile = BackupManifestFile(
                backupID: masterBackup.backupID,
                createdAt: masterBackup.createdAt,
                deviceName: masterBackup.deviceName,
                appVersion: masterBackup.appVersion,
                schemaVersion: masterBackup.schemaVersion,
                payloadKey: payloadKey,
                manifest: masterBackup.sections.manifest
            )
            let manifestData = try encoder.encode(manifestFile)
            
            // 5. Upload Encrypted Payload
            progress = 0.7
            statusMessage = "Uploading encrypted payload..."
            try await uploadToS3(data: encryptedData, key: payloadKey, config: config)
            
            // 6. Upload Manifest
            progress = 0.9
            statusMessage = "Uploading manifest..."
            try await uploadToS3(data: manifestData, key: manifestKey, config: config)

            progress = 1.0
            let convCount = masterBackup.sections.manifest.conversationCount
            let totalRecords = convCount + masterBackup.sections.manifest.codeSessionCount
            statusMessage = "✓ Backed up \(totalRecords) items"

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
            // First fetch manifest list
            let manifestKeys = try await listS3ManifestKeys(config: config)
            
            // Fetch each manifest concurrently
            var manifests: [BackupManifestFile] = []
            try await withThrowingTaskGroup(of: BackupManifestFile?.self) { group in
                for key in manifestKeys {
                    group.addTask {
                        let data = try await self.downloadFromS3(key: key, config: config)
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .iso8601
                        do {
                            return try decoder.decode(BackupManifestFile.self, from: data)
                        } catch {
                            print("S3 Backup Decode Error for \(key): \(error)")
                            return nil
                        }
                    }
                }
                for try await manifest in group {
                    if let manifest = manifest {
                        manifests.append(manifest)
                    }
                }
            }
            
            availableBackups = manifests.sorted { $0.createdAt > $1.createdAt }
        } catch {
            errorMessage = "Failed to list backups: \(error.localizedDescription)"
        }

        isListingBackups = false
    }

    // MARK: - Legacy methods replacing restore

    /// Deprecated, left stub for refactoring BackupRestoreEngine
    func restore(date: String, modelContext: ModelContext) async {
        errorMessage = "Use BackupRestoreEngine instead"
    }

    /// Save a tool analysis entry (called by legacy UserDefaults methods locally)
    func saveLegacyToolAnalysis(type: String, title: String, content: String, toKey key: String) {
        let entry = ToolAnalysisEntry(
            id: UUID().uuidString,
            type: type,
            title: title,
            content: content,
            providerID: aiManager.activeProvider?.id ?? "unknown",
            modelName: aiManager.settings.modelName,
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

    func encrypt(data: Data) throws -> Data {
        let key = getOrCreateEncryptionKey()
        let symmetricKey = SymmetricKey(data: key)
        let sealedBox = try AES.GCM.seal(data, using: symmetricKey)
        guard let combined = sealedBox.combined else {
            throw NSError(domain: "S3Backup", code: 0, userInfo: [NSLocalizedDescriptionKey: "Encryption failed"])
        }
        return combined
    }

    func decrypt(data: Data) throws -> Data {
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

    struct S3Config {
        let accessKey: String
        let secretKey: String
        let bucket: String
        let region: String
    }

    func getS3Config() -> S3Config? {
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

    func uploadToS3(data: Data, key: String, config: S3Config) async throws {
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

    func downloadFromS3(key: String, config: S3Config) async throws -> Data {
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

    private func listS3ManifestKeys(config: S3Config) async throws -> [String] {
        let prefix = "opusnative-backups/manifests/"
        // AWS SigV4 requires exact RFC 3986 encoding for query parameters.
        // Specifically, '/' must be encoded as '%2F' in the canonical query string.
        let encodedPrefix = prefix.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        
        let path = "/"
        let queryString = "list-type=2&prefix=\(encodedPrefix)"
        let endpoint = "https://\(config.bucket).s3.\(config.region).amazonaws.com/?\(queryString)"
        
        guard let url = URL(string: endpoint) else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        try signS3Request(request: &request, body: Data(), config: config, httpMethod: "GET", path: path, queryString: queryString)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "S3", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response from S3"])
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            let errorXml = String(data: data, encoding: .utf8) ?? "Unknown Error"
            print("S3 Error: \(errorXml)") // Useful for debugging AWS Signature errors
            throw NSError(domain: "S3", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to list S3 objects (HTTP \(httpResponse.statusCode))"])
        }

        let xml = String(data: data, encoding: .utf8) ?? ""
        return parseS3ManifestKeys(from: xml)
    }
    
    private func parseS3ManifestKeys(from xml: String) -> [String] {
        var keys: [String] = []
        var remaining = xml
        while let keyStart = remaining.range(of: "<Key>"),
              let keyEnd = remaining.range(of: "</Key>") {
            let key = String(remaining[keyStart.upperBound..<keyEnd.lowerBound])
            if key.hasSuffix(".json") {
                keys.append(key)
            }
            remaining = String(remaining[keyEnd.upperBound...])
        }
        return keys
    }
    
    func deleteFromS3(key: String, config: S3Config) async throws {
        let endpoint = "https://\(config.bucket).s3.\(config.region).amazonaws.com/\(key)"
        guard let url = URL(string: endpoint) else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        try signS3Request(request: &request, body: Data(), config: config, httpMethod: "DELETE", path: "/\(key)", queryString: "")

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw NSError(domain: "S3", code: code, userInfo: [NSLocalizedDescriptionKey: "S3 delete failed (HTTP \(code))"])
        }
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
