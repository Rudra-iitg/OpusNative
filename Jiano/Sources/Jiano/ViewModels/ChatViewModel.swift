import AppKit
import Foundation
import SwiftData
import UniformTypeIdentifiers

/// Main ViewModel driving the chat experience.
/// Uses AIManager for multi-provider support with token tracking and latency display.
@Observable
@MainActor
final class ChatViewModel {
    let diContainer: AppDIContainer
    
    init(diContainer: AppDIContainer) {
        self.diContainer = diContainer
    }
    
    var currentMessage: String = ""
    var isStreaming: Bool = false
    var streamingText: String = ""
    var errorMessage: String?
    var selectedConversation: Conversation? {
        didSet {
            if let conversation = selectedConversation {
                diContainer.contextManager.updateUsage(messages: conversation.sortedMessages, model: diContainer.aiManager.settings.modelName)
            }
        }
    }
    var lastResponseLatency: Double = 0
    var lastResponseTokens: Int?

    // MARK: - Image Attachments
    var pendingAttachments: [ImageAttachment] = []
    var attachmentError: String?

    private static let supportedImageTypes: [UTType] = [.jpeg, .png, .gif, .webP, .heic]
    private static let maxFileSizeBytes = 20 * 1024 * 1024  // 20 MB
    private static let maxAttachmentCount = 5

    func addAttachments(_ urls: [URL]) {
        var newAttachments: [ImageAttachment] = []

        for url in urls {
            // Validate UTType
            let utType = UTType(filenameExtension: url.pathExtension)
            let isSupported = utType.map { type in
                Self.supportedImageTypes.contains { type.conforms(to: $0) }
            } ?? false

            guard isSupported else {
                attachmentError = "\"\(url.lastPathComponent)\" is not a supported image type. Supported types: JPEG, PNG, GIF, WebP, HEIC."
                continue
            }

            // Read file data
            guard let data = try? Data(contentsOf: url) else {
                attachmentError = "Could not read file \"\(url.lastPathComponent)\"."
                continue
            }

            // Enforce 20 MB size limit
            guard data.count <= Self.maxFileSizeBytes else {
                attachmentError = "\"\(url.lastPathComponent)\" exceeds the 20 MB file size limit."
                continue
            }

            // Determine MIME type
            let mimeType: String
            if let type = utType {
                if type.conforms(to: .jpeg) { mimeType = "image/jpeg" }
                else if type.conforms(to: .png) { mimeType = "image/png" }
                else if type.conforms(to: .gif) { mimeType = "image/gif" }
                else if type.conforms(to: .webP) { mimeType = "image/webp" }
                else if type.conforms(to: .heic) { mimeType = "image/heic" }
                else { mimeType = "image/jpeg" }
            } else {
                mimeType = "image/jpeg"
            }

            newAttachments.append(ImageAttachment(data: data, mimeType: mimeType, filename: url.lastPathComponent))
        }

        // Enforce 5-image cap
        let remainingSlots = Self.maxAttachmentCount - pendingAttachments.count
        if newAttachments.count > remainingSlots {
            attachmentError = "You can attach up to \(Self.maxAttachmentCount) images per message. The limit has been reached."
            newAttachments = Array(newAttachments.prefix(remainingSlots))
        }

        pendingAttachments.append(contentsOf: newAttachments)
    }

    func removeAttachment(id: UUID) {
        pendingAttachments.removeAll { $0.id == id }
    }

    func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.jpeg, .png, .gif, .webP, .heic]
        panel.title = "Select Images"

        if panel.runModal() == .OK {
            addAttachments(panel.urls)
        }
    }

    private var streamTask: Task<Void, Never>?
    
    // Phase 2: Context Monitor
    var showInspector: Bool = false
    var contextUsage: Int { diContainer.contextManager.currentUsage }
    var contextLimit: Int { diContainer.contextManager.maxContext }
    var contextPercentage: Double { diContainer.contextManager.usagePercentage }

    // MARK: - Send Message

    func sendMessage(modelContext: ModelContext) {
        let text = currentMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }

        let aiManager = diContainer.aiManager

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

        // Add user message, chaining it to the current branch leaf
        let capturedAttachments = pendingAttachments
        let previousLeafID = conversation.sortedMessages.last?.id
        let userMessage = ChatMessage(
            role: "user",
            content: text,
            conversation: conversation,
            parentMessageID: previousLeafID,
            model: settings.modelName,
            imageData: capturedAttachments.map { $0.data },
            imageMIMETypes: capturedAttachments.map { $0.mimeType }
        )
        modelContext.insert(userMessage)
        conversation.messages.append(userMessage)
        conversation.updatedAt = Date()
        
        // Update context immediately
        diContainer.contextManager.updateUsage(messages: conversation.sortedMessages, model: settings.modelName)

        currentMessage = ""
        pendingAttachments = []
        attachmentError = nil
        errorMessage = nil

        // Validate attachments for vision support and size limits
        let attachmentsToSend: [ImageAttachment]
        if !capturedAttachments.isEmpty {
            if !provider.supportsVision {
                // Non-vision provider: silently drop images, send text only
                attachmentsToSend = []
            } else {
                // Check per-image base64 size limits
                let isAnthropic = provider.id == "anthropic"
                let base64Limit = isAnthropic ? 5 * 1024 * 1024 : 20 * 1024 * 1024
                let providerName = isAnthropic ? "Anthropic" : "OpenAI"

                var oversized = false
                for attachment in capturedAttachments {
                    // Approximate base64 size: every 3 bytes become 4 base64 chars
                    let base64Size = (attachment.data.count * 4 + 2) / 3
                    if base64Size > base64Limit {
                        errorMessage = "An image exceeds the \(providerName) size limit (\(isAnthropic ? "5" : "20") MB). Please remove it and try again."
                        isStreaming = false
                        oversized = true
                        break
                    }
                }
                if oversized { return }
                attachmentsToSend = capturedAttachments
            }
        } else {
            attachmentsToSend = []
        }

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
                    let imagePayloads = attachmentsToSend.map { ImagePayload(data: $0.data, mimeType: $0.mimeType) }
                    let stream = try await diContainer.requestQueue.execute(providerID: provider.id) {
                        try await provider.streamMessage(
                            text,
                            conversation: history,
                            images: imagePayloads,
                            settings: settings
                        )
                    }

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
                    let imagePayloads = attachmentsToSend.map { ImagePayload(data: $0.data, mimeType: $0.mimeType) }
                    let response = try await diContainer.requestQueue.execute(providerID: provider.id) {
                        try await provider.sendMessage(
                            text,
                            conversation: history,
                            images: imagePayloads,
                            settings: settings
                        )
                    }
                    streamingText = response.content
                    lastResponseTokens = response.tokenCount
                    inputTokens = response.inputTokenCount
                    outputTokens = response.outputTokenCount
                    
                    // Track usage
                    diContainer.usageManager.track(response: response, providerID: provider.id, modelContext: modelContext)
                    
                    // Update context
                    diContainer.contextManager.updateUsage(messages: conversation.sortedMessages, model: settings.modelName)
                }

                let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                lastResponseLatency = latency
                
                // Observability: Track latency
                diContainer.observabilityManager.trackLatency(provider: provider.id, durationMs: latency)
                diContainer.observabilityManager.log("Response received from \(provider.displayName) in \(Int(latency))ms", level: .info, subsystem: "Chat")

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
                    diContainer.usageManager.track(response: response, providerID: provider.id, modelContext: modelContext)
                }

                // Save completed assistant message
                let assistantMessage = ChatMessage(
                    role: "assistant",
                    content: streamingText,
                    conversation: conversation,
                    parentMessageID: userMessage.id,
                    providerID: provider.id,
                    tokenCount: lastResponseTokens,
                    latencyMs: latency,
                    model: settings.modelName
                )
                modelContext.insert(assistantMessage)
                conversation.messages.append(assistantMessage)
                conversation.updatedAt = Date()
                
                // Update context after response
                diContainer.contextManager.updateUsage(messages: conversation.sortedMessages, model: settings.modelName)

                try? modelContext.save()

                // Trigger auto-backup if enabled
                Task {
                    await diContainer.s3BackupManager.autoBackupIfNeeded(modelContext: modelContext)
                }

                streamingText = ""
                isStreaming = false
            } catch {
                let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                errorMessage = error.localizedDescription
                isStreaming = false
                
                // Observability: Track error
                diContainer.observabilityManager.trackError(provider: provider.id)
                diContainer.observabilityManager.log("Error from \(provider.displayName): \(error.localizedDescription)", level: .error, subsystem: "Chat")

                // Save partial response if any
                if !streamingText.isEmpty {
                    let partialMessage = ChatMessage(
                        role: "assistant",
                        content: streamingText + "\n\n⚠️ *Stream interrupted*",
                        conversation: conversation,
                        parentMessageID: userMessage.id,
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
