import Foundation
import CryptoKit

// MARK: - S3 Backup Manager

/// Manages conversation backup to AWS S3 with AES-256-GCM encryption.
/// Uses SigV4 signed requests (same pattern as BedrockService).
@Observable
@MainActor
final class S3BackupManager {
    var isBackingUp = false
    var isRestoring = false
    var progress: Double = 0.0
    var statusMessage: String = ""
    var errorMessage: String?

    private let session = URLSession.shared

    // MARK: - Backup Conversations

    /// Export all conversations as JSON, encrypt, and upload to S3
    func backup(conversations: [Conversation]) async {
        guard let config = getS3Config() else {
            errorMessage = "S3 credentials not configured. Open Settings to add them."
            return
        }

        isBackingUp = true
        progress = 0.0
        statusMessage = "Preparing backup..."
        errorMessage = nil

        do {
            // 1. Serialize conversations
            progress = 0.1
            statusMessage = "Serializing \(conversations.count) conversations..."

            let backupData = serializeConversations(conversations)
            let jsonData = try JSONSerialization.data(withJSONObject: backupData, options: .prettyPrinted)

            // 2. Encrypt
            progress = 0.3
            statusMessage = "Encrypting data..."

            let encryptedData = try encrypt(data: jsonData)

            // 3. Upload to S3
            progress = 0.5
            statusMessage = "Uploading to S3..."

            let key = "opusnative-backups/backup-\(ISO8601DateFormatter().string(from: Date())).enc"
            try await uploadToS3(data: encryptedData, key: key, config: config)

            progress = 1.0
            statusMessage = "✓ Backup complete (\(conversations.count) conversations)"
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Backup failed"
        }

        isBackingUp = false
    }

    // MARK: - Restore from S3

    /// Download, decrypt, and restore conversations from S3
    func restore() async -> [[String: Any]]? {
        guard let config = getS3Config() else {
            errorMessage = "S3 credentials not configured."
            return nil
        }

        isRestoring = true
        progress = 0.0
        statusMessage = "Listing backups..."
        errorMessage = nil

        do {
            // List the latest backup
            progress = 0.3
            statusMessage = "Downloading latest backup..."

            let key = "opusnative-backups/"
            let data = try await downloadFromS3(prefix: key, config: config)

            progress = 0.6
            statusMessage = "Decrypting..."

            let decryptedData = try decrypt(data: data)

            progress = 0.9
            statusMessage = "Parsing..."

            guard let backup = try? JSONSerialization.jsonObject(with: decryptedData) as? [[String: Any]] else {
                throw NSError(domain: "S3Backup", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid backup format"])
            }

            progress = 1.0
            statusMessage = "✓ Restore complete"
            isRestoring = false
            return backup
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Restore failed"
            isRestoring = false
            return nil
        }
    }

    // MARK: - Serialization

    private func serializeConversations(_ conversations: [Conversation]) -> [[String: Any]] {
        return conversations.map { conversation in
            let messages: [[String: Any]] = conversation.sortedMessages.map { msg in
                var dict: [String: Any] = [
                    "role": msg.role,
                    "content": msg.content,
                    "timestamp": ISO8601DateFormatter().string(from: msg.timestamp)
                ]
                if let provider = msg.providerID { dict["providerID"] = provider }
                if let tokens = msg.tokenCount { dict["tokenCount"] = tokens }
                if let latency = msg.latencyMs { dict["latencyMs"] = latency }
                return dict
            }

            return [
                "id": conversation.id.uuidString,
                "title": conversation.title,
                "createdAt": ISO8601DateFormatter().string(from: conversation.createdAt),
                "updatedAt": ISO8601DateFormatter().string(from: conversation.updatedAt),
                "providerID": conversation.providerID ?? "",
                "messages": messages
            ]
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

        // Generate new 256-bit key
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        let keyBase64 = keyData.base64EncodedString()
        KeychainService.shared.save(key: KeychainService.backupEncryptionKey, value: keyBase64)
        return keyData
    }

    // MARK: - S3 Operations

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

    private func uploadToS3(data: Data, key: String, config: S3Config) async throws {
        let endpoint = "https://\(config.bucket).s3.\(config.region).amazonaws.com/\(key)"
        guard let url = URL(string: endpoint) else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = data
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        try signS3Request(request: &request, body: data, config: config, httpMethod: "PUT", key: key)

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw NSError(domain: "S3", code: code, userInfo: [NSLocalizedDescriptionKey: "S3 upload failed (HTTP \(code))"])
        }
    }

    private func downloadFromS3(prefix: String, config: S3Config) async throws -> Data {
        // List objects to find the latest backup
        let listEndpoint = "https://\(config.bucket).s3.\(config.region).amazonaws.com/?prefix=\(prefix)&max-keys=1"
        guard let listURL = URL(string: listEndpoint) else { throw URLError(.badURL) }

        var listRequest = URLRequest(url: listURL)
        listRequest.httpMethod = "GET"
        try signS3Request(request: &listRequest, body: Data(), config: config, httpMethod: "GET", key: "")

        let (listData, _) = try await session.data(for: listRequest)

        // Parse XML to find the latest object key
        let xmlString = String(data: listData, encoding: .utf8) ?? ""
        guard let keyRange = xmlString.range(of: "<Key>"),
              let keyEndRange = xmlString.range(of: "</Key>") else {
            throw NSError(domain: "S3", code: 0, userInfo: [NSLocalizedDescriptionKey: "No backups found in S3."])
        }

        let objectKey = String(xmlString[keyRange.upperBound..<keyEndRange.lowerBound])

        // Download the object
        let getEndpoint = "https://\(config.bucket).s3.\(config.region).amazonaws.com/\(objectKey)"
        guard let getURL = URL(string: getEndpoint) else { throw URLError(.badURL) }

        var getRequest = URLRequest(url: getURL)
        getRequest.httpMethod = "GET"
        try signS3Request(request: &getRequest, body: Data(), config: config, httpMethod: "GET", key: objectKey)

        let (data, response) = try await session.data(for: getRequest)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "S3", code: 0, userInfo: [NSLocalizedDescriptionKey: "S3 download failed."])
        }

        return data
    }

    // MARK: - SigV4 Signing (S3)

    private func signS3Request(request: inout URLRequest, body: Data, config: S3Config, httpMethod: String, key: String) throws {
        let date = Date()
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        isoFormatter.timeZone = TimeZone(identifier: "UTC")
        let amzDate = isoFormatter.string(from: date)
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ":", with: "")
        let dateShort = String(amzDate.prefix(8))

        let host = "\(config.bucket).s3.\(config.region).amazonaws.com"
        request.setValue(amzDate, forHTTPHeaderField: "x-amz-date")
        request.setValue(host, forHTTPHeaderField: "host")

        let payloadHash = SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined()
        request.setValue(payloadHash, forHTTPHeaderField: "x-amz-content-sha256")

        let canonicalURI = "/" + key
        let headers = "host:\(host)\nx-amz-content-sha256:\(payloadHash)\nx-amz-date:\(amzDate)"
        let signedHeaders = "host;x-amz-content-sha256;x-amz-date"

        let canonicalRequest = """
        \(httpMethod)
        \(canonicalURI)

        \(headers)

        \(signedHeaders)
        \(payloadHash)
        """

        let credentialScope = "\(dateShort)/\(config.region)/s3/aws4_request"
        let stringToSign = """
        AWS4-HMAC-SHA256
        \(amzDate)
        \(credentialScope)
        \(SHA256.hash(data: Data(canonicalRequest.utf8)).map { String(format: "%02x", $0) }.joined())
        """

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
