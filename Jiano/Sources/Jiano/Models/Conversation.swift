import Foundation
import SwiftData

@Model
final class Conversation {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date

    /// Default provider for this conversation
    var providerID: String?

    /// The leaf message ID of the currently active branch.
    /// `nil` means the conversation is linear or use the latest message.
    var activeBranchLeafID: UUID?

    // Ensure ChatMessage has a 'conversation' property for this inverse relationship to work
    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.conversation)
    var messages: [ChatMessage] = []

    init(title: String = "New Chat", providerID: String? = nil) {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.providerID = providerID
        self.messages = []
    }

    // MARK: - Backward Compatible (Linear)

    /// Messages sorted by timestamp (legacy linear view).
    /// For branching conversations, prefer `messagesForBranch()`.
    var sortedMessages: [ChatMessage] {
        let branchMessages = messagesForBranch(leafID: activeBranchLeafID)
        return branchMessages.isEmpty
            ? messages.sorted { $0.timestamp < $1.timestamp }
            : branchMessages
    }

    // MARK: - Branching Support

    /// Walk from a leaf message back to the root, returning messages in chronological order.
    /// If `leafID` is nil, returns the latest branch (by timestamp of leaf).
    func messagesForBranch(leafID: UUID?) -> [ChatMessage] {
        let messageMap = Dictionary(uniqueKeysWithValues: messages.map { ($0.id, $0) })

        // Find the starting leaf
        let leaf: ChatMessage?
        if let leafID {
            leaf = messageMap[leafID]
        } else {
            // Find the latest leaf (a message with no children)
            let childParentIDs = Set(messages.compactMap { $0.parentMessageID })
            leaf = messages.filter { !childParentIDs.contains($0.id) }
                .sorted { $0.timestamp > $1.timestamp }
                .first
        }

        guard let startMessage = leaf else { return [] }

        // Walk back to root
        var path: [ChatMessage] = [startMessage]
        var current = startMessage
        while let parentID = current.parentMessageID, let parent = messageMap[parentID] {
            path.append(parent)
            current = parent
        }

        return path.reversed() // Root → Leaf order
    }

    /// Get all direct children of a specific message (for branch visualization).
    func children(of messageID: UUID) -> [ChatMessage] {
        messages.filter { $0.parentMessageID == messageID }
            .sorted { $0.timestamp < $1.timestamp }
    }

    /// How many branches exist at a given message (number of children).
    func branchCount(at messageID: UUID) -> Int {
        children(of: messageID).count
    }
}
