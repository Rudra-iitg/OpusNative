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
    var selectedConversation: Conversation? {
        didSet {
            if let conversation = selectedConversation {
                ContextManager.shared.updateUsage(messages: conversation.sortedMessages, model: AIManager.shared.settings.modelName)
            }
        }
    }
    var lastResponseLatency: Double = 0
    var lastResponseTokens: Int?

    private var streamTask: Task<Void, Never>?
    
    // Phase 2: Context Monitor
    var showInspector: Bool = false
    var contextUsage: Int { ContextManager.shared.currentUsage }
    var contextLimit: Int { ContextManager.shared.maxContext }
    var contextPercentage: Double { ContextManager.shared.usagePercentage }

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
        let userMessage = ChatMessage(role: "user", content: text, conversation: conversation, model: settings.modelName)
        modelContext.insert(userMessage)
        conversation.messages.append(userMessage)
        conversation.updatedAt = Date()
        
        // Update context immediately
        ContextManager.shared.updateUsage(messages: conversation.sortedMessages, model: settings.modelName)

        currentMessage = ""
        errorMessage = nil

        // Start streaming
        isStreaming = true
        streamingText = ""
        let startTime = CFAbsoluteTimeGetCurrent()

        streamTask = Task {
            do {
                var inputTokens: Int?
                var outputTokens: Int?

                if provider.supportsStreaming && settings.useStreaming {
                    // Streaming mode
                    let history = conversation.sortedMessages.dropLast().map { $0.toDTO }
                    let stream = try await provider.streamMessage(
                        text,
                        conversation: history,
                        settings: settings
                    )

                    for try await chunk in stream {
                        switch chunk {
                        case .content(let text):
                            streamingText += text
                        case .usage(let input, let output):
                            inputTokens = input
                            outputTokens = output
                            lastResponseTokens = input + output
                        }
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
                    inputTokens = response.inputTokenCount
                    outputTokens = response.outputTokenCount
                    
                    // Track usage
                    UsageManager.shared.track(response: response)
                    
                    // Update context
                    ContextManager.shared.updateUsage(messages: conversation.sortedMessages, model: settings.modelName)
                }

                let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                lastResponseLatency = latency
                
                // Observability: Track latency
                ObservabilityManager.shared.trackLatency(provider: provider.id, durationMs: latency)
                ObservabilityManager.shared.log("Response received from \(provider.displayName) in \(Int(latency))ms", level: .info, subsystem: "Chat")

                // Track usage (if not already tracked in non-streaming, but let's just track again or track correctly)
                // Actually usage is tracked in non-streaming block above.
                // For streaming, we need to track here.
                if provider.supportsStreaming && settings.useStreaming {
                     let response = AIResponse(
                        content: streamingText,
                        inputTokenCount: inputTokens,
                        outputTokenCount: outputTokens,
                        latencyMs: latency,
                        model: settings.modelName,
                        providerID: provider.id
                    )
                    UsageManager.shared.track(response: response)
                }

                // Save completed assistant message
                let assistantMessage = ChatMessage(
                    role: "assistant",
                    content: streamingText,
                    conversation: conversation,
                    providerID: provider.id,
                    tokenCount: lastResponseTokens,
                    latencyMs: latency,
                    model: settings.modelName
                )
                modelContext.insert(assistantMessage)
                conversation.messages.append(assistantMessage)
                conversation.updatedAt = Date()
                
                // Update context after response
                ContextManager.shared.updateUsage(messages: conversation.sortedMessages, model: settings.modelName)

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
                
                // Observability: Track error
                ObservabilityManager.shared.trackError(provider: provider.id)
                ObservabilityManager.shared.log("Error from \(provider.displayName): \(error.localizedDescription)", level: .error, subsystem: "Chat")

                // Save partial response if any
                if !streamingText.isEmpty {
                    let partialMessage = ChatMessage(
                        role: "assistant",
                        content: streamingText + "\n\n⚠️ *Stream interrupted*",
                        conversation: conversation,
                        providerID: provider.id,
                        latencyMs: latency,
                        model: settings.modelName
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
