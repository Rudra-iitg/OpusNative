import Foundation
import Security

/// Thread-safe Keychain wrapper for storing sensitive credentials
final class KeychainService: @unchecked Sendable {
    static let shared = KeychainService()
    private let service = "com.opusnative.credentials"

    private init() {}

    // MARK: - Public API

    @discardableResult
    func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // Delete existing item first
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    @discardableResult
    func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

// MARK: - Keychain Key Constants

extension KeychainService {
    // AWS Bedrock
    static let accessKeyID = "aws-access-key"
    static let secretAccessKey = "aws-secret-key"

    // Anthropic
    static let anthropicAPIKey = "anthropic-api-key"

    // OpenAI
    static let openaiAPIKey = "openai-api-key"

    // HuggingFace
    static let huggingfaceToken = "huggingface-token"

    // Gemini
    static let geminiAPIKey = "gemini-api-key"

    // Grok (xAI)
    static let grokAPIKey = "grok-api-key"

    // Ollama
    static let ollamaBaseURL = "ollama-base-url"

    // S3 Backup
    static let s3AccessKey = "s3-access-key"
    static let s3SecretKey = "s3-secret-key"
    static let s3BucketName = "s3-bucket-name"
    static let s3Region = "s3-region"

    // Encryption
    static let backupEncryptionKey = "backup-encryption-key"
}
