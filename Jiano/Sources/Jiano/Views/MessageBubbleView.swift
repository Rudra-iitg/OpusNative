import SwiftUI
import MarkdownUI
import AppKit

/// Individual message bubble with provider badge, token count, latency, Markdown rendering.
struct MessageBubbleView: View {
    let message: ChatMessage
    @State private var showArtifact: Bool = false
    @State private var selectedCodeBlock: CodeBlock?
    @State private var isHovered: Bool = false
    @State private var showCopied: Bool = false
    @State private var fullScreenImage: NSImage?
    @Environment(AppDIContainer.self) private var diContainer

    private var themeManager: ThemeManager { diContainer.themeManager }
    private var usageManager: UsageManager { diContainer.usageManager }
    private var accentColor: Color { themeManager.accent }

    var body: some View {
        HStack(alignment: .top) {
            if message.isUser {
                Spacer(minLength: 120)
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
                // Label row with provider badge
                HStack(spacing: 6) {
                    if !message.isUser {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(accentColor)

                        if let providerID = message.providerID {
                            ProviderBadge(providerID: providerID)
                        } else {
                            Text("AI")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }

                    if message.isUser {
                        Text("You")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.5))
                        Image(systemName: "person.circle.fill")
                            .font(.caption)
                            .foregroundStyle(accentColor.opacity(0.7))
                    }
                }

                // Content bubble
                if message.isUser {
                    userBubble
                } else {
                    assistantBubble
                }

                // Metadata row: timestamp, token count, latency, copy
                HStack(spacing: 8) {
                    Text(message.timestamp.formatted(.dateTime.hour().minute()))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.2))

                    if let tokens = message.tokenCount {
                        HStack(spacing: 6) {
                            HStack(spacing: 2) {
                                Image(systemName: "number")
                                Text("\(tokens)")
                            }
                            
                            // Cost calculation
                            if let cost = usageManager.calculateCost(
                                input: 0, // We don't store input split on message yet, assume mostly output for assistant
                                output: tokens,
                                model: message.model ?? ""
                            ) as Decimal?, cost > 0 {
                                Text("•")
                                    .foregroundStyle(.white.opacity(0.2))
                                Text(cost.formatted(.currency(code: "USD")))
                                    .foregroundStyle(.green.opacity(0.8))
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.25))
                    }

                    if let latency = message.latencyMs {
                        HStack(spacing: 2) {
                            Image(systemName: "clock")
                            Text(String(format: "%.0fms", latency))
                        }
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.25))
                    }

                    if isHovered {
                        Button {
                            copyMessageToClipboard()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                Text(showCopied ? "Copied" : "Copy")
                            }
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity)
                    }
                }
            }

            if !message.isUser {
                Spacer(minLength: 120)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button {
                copyMessageToClipboard()
            } label: {
                Label("Copy Message", systemImage: "doc.on.doc")
            }
        }
        .sheet(isPresented: $showArtifact) {
            if let block = selectedCodeBlock {
                ArtifactView(codeBlock: block)
            }
        }
        .sheet(isPresented: Binding(
            get: { fullScreenImage != nil },
            set: { if !$0 { fullScreenImage = nil } }
        )) {
            if let img = fullScreenImage {
                VStack {
                    HStack {
                        Spacer()
                        Button("Close") { fullScreenImage = nil }
                            .padding()
                    }
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .padding()
                }
                .frame(minWidth: 400, minHeight: 400)
            }
        }
    }

    // MARK: - User Bubble

    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if !message.imageData.isEmpty {
                imageGrid
            }

            Text(message.content)
                .textSelection(.enabled)
                .foregroundStyle(.white)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [accentColor, accentColor.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: accentColor.opacity(0.2), radius: 10, y: 4)
        )
    }

    private var imageGrid: some View {
        let columns = message.imageData.count == 1
            ? [GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]

        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(message.imageData.enumerated()), id: \.offset) { _, data in
                if let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 300, maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onTapGesture {
                            fullScreenImage = nsImage
                        }
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .overlay(
                            VStack(spacing: 4) {
                                Image(systemName: "photo")
                                    .font(.title2)
                                Text("Image unavailable")
                                    .font(.caption)
                            }
                            .foregroundStyle(.white.opacity(0.5))
                        )
                }
            }
        }
    }

    // MARK: - Assistant Bubble

    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            Markdown(message.content)
                .markdownTheme(.gitHub)
                .textSelection(.enabled)

            if !message.codeBlocks.isEmpty {
                Divider()
                    .overlay(Color.white.opacity(0.08))
                HStack(spacing: 8) {
                    ForEach(Array(message.codeBlocks.enumerated()), id: \.element.id) { index, block in
                        Button {
                            selectedCodeBlock = block
                            showArtifact = true
                        } label: {
                            Label(
                                "Code \(index + 1) (\(block.language))",
                                systemImage: "doc.text"
                            )
                            .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(accentColor)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.1), Color.white.opacity(0.03)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        )
    }

    // MARK: - Clipboard

    private func copyMessageToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.content, forType: .string)
        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopied = false
        }
    }
}
