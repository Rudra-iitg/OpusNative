import Foundation

enum ReportFormat {
    case markdown
    case json
}

struct ReportGenerator {
    static let shared = ReportGenerator()
    
    private init() {}
    
    func generate(conversation: [ChatMessage], format: ReportFormat, model: String) -> Data? {
        switch format {
        case .markdown:
            return generateMarkdown(conversation: conversation, model: model).data(using: .utf8)
        case .json:
            return generateJSON(conversation: conversation, model: model)
        }
    }
    
    // MARK: - Markdown
    
    private func generateMarkdown(conversation: [ChatMessage], model: String) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        
        var md = "# Conversation Report\n"
        md += "**Date:** \(formatter.string(from: Date()))\n"
        md += "**Model:** \(model)\n"
        md += "**Message Count:** \(conversation.count)\n\n"
        md += "---\n\n"
        
        for msg in conversation {
            let role = msg.role == "user" ? "**User**" : "**Assistant**"
            let time = formatter.string(from: msg.timestamp)
            
            md += "### \(role) (*\(time)*)\n\n"
            md += "\(msg.content)\n\n"
            
            if let tokens = msg.tokenCount {
                md += "*Estimated Tokens: \(tokens)*\n\n"
            }
            md += "---\n\n"
        }
        
        return md
    }
    
    // MARK: - JSON
    
    private func generateJSON(conversation: [ChatMessage], model: String) -> Data? {
        let export = ConversationExport(
            timestamp: Date(),
            model: model,
            messages: conversation
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        return try? encoder.encode(export)
    }
}

struct ConversationExport: Codable {
    let timestamp: Date
    let model: String
    let messages: [ChatMessage]
}
