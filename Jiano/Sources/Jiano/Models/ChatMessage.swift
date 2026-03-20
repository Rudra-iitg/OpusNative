import Foundation
import SwiftData

@Model
final class ChatMessage: Identifiable, Codable {
    @Attribute(.unique) var id: UUID
    var role: String  // "user" or "assistant"
    var content: String
    var timestamp: Date
    var conversation: Conversation?

    /// Parent message ID for conversation branching.
    /// `nil` = root message (first in conversation).
    /// When a user forks at message N, the new branch message gets `parentMessageID = N.id`.
    var parentMessageID: UUID?

    /// Provider that generated this response (nil for user messages)
    var providerID: String?

    /// Approximate token count for this message
    var tokenCount: Int?

    /// Response latency in milliseconds (assistant messages only)
    var latencyMs: Double?

    /// Model used for this message
    var model: String?

    /// Raw image bytes for attachments, stored outside the SQLite store to avoid bloat.
    @Attribute(.externalStorage) var imageData: [Data] = []

    /// Parallel array of MIME type strings for each image in imageData.
    /// Index i corresponds to imageData[i].
    var imageMIMETypes: [String] = []

    init(role: String, content: String, conversation: Conversation? = nil, parentMessageID: UUID? = nil, providerID: String? = nil, tokenCount: Int? = nil, latencyMs: Double? = nil, model: String? = nil, imageData: [Data] = [], imageMIMETypes: [String] = []) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.conversation = conversation
        self.parentMessageID = parentMessageID
        self.providerID = providerID
        self.tokenCount = tokenCount
        self.latencyMs = latencyMs
        self.model = model
        self.imageData = imageData
        self.imageMIMETypes = imageMIMETypes
    }

    var isUser: Bool {
        role == "user"
    }

    var isAssistant: Bool {
        role == "assistant"
    }

    /// Extract all fenced code blocks from the message content
    var codeBlocks: [CodeBlock] {
        var blocks: [CodeBlock] = []
        let lines = content.components(separatedBy: "\n")
        var inCodeBlock = false
        var currentLanguage = "text"
        var currentCode: [String] = []

        for line in lines {
            if line.hasPrefix("```") && !inCodeBlock {
                inCodeBlock = true
                let lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                currentLanguage = lang.isEmpty ? "text" : lang
                currentCode = []
            } else if line.hasPrefix("```") && inCodeBlock {
                inCodeBlock = false
                blocks.append(CodeBlock(language: currentLanguage, code: currentCode.joined(separator: "\n")))
            } else if inCodeBlock {
                currentCode.append(line)
            }
        }

        return blocks
    }
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, role, content, timestamp, parentMessageID, providerID, tokenCount, latencyMs, model
        case imageData, imageMIMETypes
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        role = try container.decode(String.self, forKey: .role)
        content = try container.decode(String.self, forKey: .content)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        parentMessageID = try container.decodeIfPresent(UUID.self, forKey: .parentMessageID)
        providerID = try container.decodeIfPresent(String.self, forKey: .providerID)
        tokenCount = try container.decodeIfPresent(Int.self, forKey: .tokenCount)
        latencyMs = try container.decodeIfPresent(Double.self, forKey: .latencyMs)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        imageData = try container.decodeIfPresent([Data].self, forKey: .imageData) ?? []
        imageMIMETypes = try container.decodeIfPresent([String].self, forKey: .imageMIMETypes) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(role, forKey: .role)
        try container.encode(content, forKey: .content)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(parentMessageID, forKey: .parentMessageID)
        try container.encode(providerID, forKey: .providerID)
        try container.encode(tokenCount, forKey: .tokenCount)
        try container.encode(latencyMs, forKey: .latencyMs)
        try container.encode(model, forKey: .model)
        try container.encode(imageData, forKey: .imageData)
        try container.encode(imageMIMETypes, forKey: .imageMIMETypes)
    }
}

struct CodeBlock: Identifiable {
    let id = UUID()
    let language: String
    let code: String
}
