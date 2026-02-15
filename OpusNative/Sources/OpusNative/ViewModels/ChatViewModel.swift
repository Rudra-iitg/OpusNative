import Foundation
import SwiftData

/// Main ViewModel driving the chat experience.
/// Uses AIManager for multi-provider support with token tracking and latency display.
@Observable
@MainActor
final class ChatViewModel {
    var currentMessage: String = ""
    var isStreaming: Bool = false
    var streamingText: String = ""
    var errorMessage: String?
    var selectedConversation: Conversation?
    var lastResponseLatency: Double = 0
    var lastResponseTokens: Int?

    private var streamTask: Task<Void, Never>?

    // MARK: - Send Message

    func sendMessage(modelContext: ModelContext) {
        let text = currentMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }

        let aiManager = AIManager.shared

        guard let provider = aiManager.activeProvider else {
            errorMessage = "No provider selected. Configure a provider in Settings."
            return
        }

        // Check if provider is configured
        guard aiManager.isProviderConfigured(provider.id) else {
            errorMessage = "\(provider.displayName) is not configured. Open Settings (⌘,) to add credentials."
            return
        }

        let settings = aiManager.settings

        // Create or reuse conversation
        if selectedConversation == nil {
            let conversation = Conversation(
                title: String(text.prefix(50)),
                providerID: provider.id
            )
            modelContext.insert(conversation)
            selectedConversation = conversation
        }

        guard let conversation = selectedConversation else { return }

        // Add user message
        let userMessage = ChatMessage(role: "user", content: text, conversation: conversation)
        modelContext.insert(userMessage)
        conversation.messages.append(userMessage)
        conversation.updatedAt = Date()

        currentMessage = ""
        errorMessage = nil

        // Start streaming
        isStreaming = true
        streamingText = ""
        let startTime = CFAbsoluteTimeGetCurrent()

        streamTask = Task {
            do {
                if provider.supportsStreaming && settings.useStreaming {
                    // Streaming mode
                    let history = conversation.sortedMessages.dropLast().map { $0.toDTO }
                    let stream = try await provider.streamMessage(
                        text,
                        conversation: history,
                        settings: settings
                    )

                    for try await delta in stream {
                        streamingText += delta
                    }
                } else {
                    // Non-streaming mode
                    let history = conversation.sortedMessages.dropLast().map { $0.toDTO }
                    let response = try await provider.sendMessage(
                        text,
                        conversation: history,
                        settings: settings
                    )
                    streamingText = response.content
                    lastResponseTokens = response.tokenCount
                }

                let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                lastResponseLatency = latency

                // Save completed assistant message
                let assistantMessage = ChatMessage(
                    role: "assistant",
                    content: streamingText,
                    conversation: conversation,
                    providerID: provider.id,
                    tokenCount: lastResponseTokens,
                    latencyMs: latency
                )
                modelContext.insert(assistantMessage)
                conversation.messages.append(assistantMessage)
                conversation.updatedAt = Date()

                try? modelContext.save()

                // Trigger auto-backup if enabled
                Task {
                    await S3BackupManager.shared.autoBackupIfNeeded(modelContext: modelContext)
                }

                streamingText = ""
                isStreaming = false
            } catch {
                let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                errorMessage = error.localizedDescription
                isStreaming = false

                // Save partial response if any
                if !streamingText.isEmpty {
                    let partialMessage = ChatMessage(
                        role: "assistant",
                        content: streamingText + "\n\n⚠️ *Stream interrupted*",
                        conversation: conversation,
                        providerID: provider.id,
                        latencyMs: latency
                    )
                    modelContext.insert(partialMessage)
                    conversation.messages.append(partialMessage)
                    try? modelContext.save()
                    streamingText = ""
                }
            }
        }
    }

    // MARK: - Actions

    func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
    }

    func newConversation() {
        selectedConversation = nil
        currentMessage = ""
        streamingText = ""
        errorMessage = nil
    }

    func deleteConversation(_ conversation: Conversation, modelContext: ModelContext) {
        if selectedConversation?.id == conversation.id {
            selectedConversation = nil
        }
        modelContext.delete(conversation)
        try? modelContext.save()
    }

    /// Auto-title a conversation based on the first user message
    func updateTitle(for conversation: Conversation) {
        let first = conversation.sortedMessages.first(where: { $0.isUser })
        if let first, conversation.title == "New Chat" {
            conversation.title = String(first.content.prefix(50))
        }
    }
}
