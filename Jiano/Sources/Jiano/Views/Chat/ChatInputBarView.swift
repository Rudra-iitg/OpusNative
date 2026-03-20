import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ChatInputBarView: View {
    @Bindable var chatVM: ChatViewModel
    var modelContext: ModelContext
    let themeManager: ThemeManager
    let performanceManager: PerformanceManager

    @FocusState private var isInputFocused: Bool
    @State private var isDragTargeted = false

    private var isMessageEmpty: Bool {
        chatVM.currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            thumbnailStrip
            visionWarningBanner
            attachmentErrorLabel
            inputRow
        }
        .background(backgroundView)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var thumbnailStrip: some View {
        if !chatVM.pendingAttachments.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(chatVM.pendingAttachments) { attachment in
                        AttachmentThumbnailView(attachment: attachment) {
                            chatVM.removeAttachment(id: attachment.id)
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 8)
            }
        }
    }

    @ViewBuilder
    private var visionWarningBanner: some View {
        if chatVM.diContainer.aiManager.activeProvider?.supportsVision == false,
           !chatVM.pendingAttachments.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text("The active provider does not support image input. Images will not be sent.")
                    .font(.caption)
                    .foregroundStyle(.yellow.opacity(0.9))
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 6)
        }
    }

    @ViewBuilder
    private var attachmentErrorLabel: some View {
        if let error = chatVM.attachmentError {
            HStack(spacing: 6) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red.opacity(0.8))
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.9))
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 4)
        }
    }

    private var inputRow: some View {
        HStack(alignment: .bottom, spacing: 12) {
            attachmentButton
            textInputField
            sendButton
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
    }

    private var attachmentButton: some View {
        Button { chatVM.openFilePicker() } label: {
            Image(systemName: "paperclip")
                .font(.system(size: 18))
                .foregroundStyle(Color.white.opacity(0.5))
        }
        .buttonStyle(.plain)
    }

    private var textInputField: some View {
        ZStack(alignment: .topLeading) {
            if chatVM.currentMessage.isEmpty {
                Text("Message OpusNative...")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.25))
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $chatVM.currentMessage)
                .font(.body)
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 36, maxHeight: 120)
                .fixedSize(horizontal: false, vertical: true)
                .focused($isInputFocused)
                .onSubmit {
                    if !NSEvent.modifierFlags.contains(.shift) {
                        chatVM.sendMessage(modelContext: modelContext)
                    }
                }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(isInputFocused ? 0.18 : 0.1), lineWidth: 1))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(isDragTargeted ? Color.blue.opacity(0.6) : Color.clear, lineWidth: 2))
        .onDrop(of: [.image, .fileURL], isTargeted: $isDragTargeted, perform: handleDrop)
    }

    private var sendButton: some View {
        Button { chatVM.sendMessage(modelContext: modelContext) } label: {
            Image(systemName: chatVM.isStreaming ? "ellipsis.circle.fill" : "arrow.up.circle.fill")
                .font(.system(size: 30))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isMessageEmpty ? Color.white.opacity(0.2) : themeManager.accent)
                .shadow(color: isMessageEmpty ? .clear : themeManager.accent.opacity(0.5), radius: 8)
        }
        .buttonStyle(.plain)
        .disabled(isMessageEmpty || chatVM.isStreaming)
        .keyboardShortcut(.return, modifiers: .command)
    }

    @ViewBuilder
    private var backgroundView: some View {
        if performanceManager.reduceTranslucency {
            Color(red: 0.1, green: 0.1, blue: 0.12)
        } else {
            Rectangle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .overlay(Rectangle().fill(Color.white.opacity(0.03)))
        }
    }

    // MARK: - Drop handler

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        Task { @MainActor in
            var urls: [URL] = []
            for provider in providers {
                guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else { continue }
                if let url = try? await withCheckedThrowingContinuation({ (cont: CheckedContinuation<URL, Error>) in
                    _ = provider.loadObject(ofClass: URL.self) { url, error in
                        if let url { cont.resume(returning: url) }
                        else { cont.resume(throwing: error ?? URLError(.unknown)) }
                    }
                }) {
                    urls.append(url)
                }
            }
            if !urls.isEmpty { chatVM.addAttachments(urls) }
        }
        return true
    }
}

// MARK: - Attachment Thumbnail

struct AttachmentThumbnailView: View {
    let attachment: ImageAttachment
    let onRemove: () -> Void
    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let nsImage = NSImage(data: attachment.data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 64, height: 64)
                    .overlay(Image(systemName: "photo").foregroundStyle(.white.opacity(0.5)))
            }

            if isHovered {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .background(Circle().fill(Color.black.opacity(0.6)))
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
            }
        }
        .onHover { isHovered = $0 }
    }
}
