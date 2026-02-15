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

    private var accentColor: Color { ThemeManager.shared.accent }

    var body: some View {
        HStack(alignment: .top) {
            if message.isUser {
                Spacer(minLength: 80)
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
                        HStack(spacing: 2) {
                            Image(systemName: "number")
                            Text("\(tokens) tokens")
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
                Spacer(minLength: 80)
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
    }

    // MARK: - User Bubble

    private var userBubble: some View {
        Text(message.content)
            .textSelection(.enabled)
            .foregroundStyle(.white)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: accentColor.opacity(0.25), radius: 8, y: 4)
            )
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
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.1), Color.white.opacity(0.03)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
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
