import Foundation
import SwiftData

@Model
final class ChatMessage: Identifiable {
    @Attribute(.unique) var id: UUID
    var role: String  // "user" or "assistant"
    var content: String
    var timestamp: Date
    var conversation: Conversation?

    /// Provider that generated this response (nil for user messages)
    var providerID: String?

    /// Approximate token count for this message
    var tokenCount: Int?

    /// Response latency in milliseconds (assistant messages only)
    var latencyMs: Double?

    init(role: String, content: String, conversation: Conversation? = nil, providerID: String? = nil, tokenCount: Int? = nil, latencyMs: Double? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.conversation = conversation
        self.providerID = providerID
        self.tokenCount = tokenCount
        self.latencyMs = latencyMs
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
}

struct CodeBlock: Identifiable {
    let id = UUID()
    let language: String
    let code: String
}
