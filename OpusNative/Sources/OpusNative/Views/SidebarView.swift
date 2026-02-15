import SwiftUI
import SwiftData

/// Sidebar with navigation sections and conversation history.
struct SidebarView: View {
    @Bindable var chatVM: ChatViewModel
    @Binding var selectedNav: NavigationItem?
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]

    private let accentColor = Color(red: 0.56, green: 0.44, blue: 1.0)  // Purple accent

    var body: some View {
        List(selection: $selectedNav) {
            // Navigation sections
            Section("Workstation") {
                ForEach(NavigationItem.allCases) { item in
                    NavigationLink(value: item) {
                        Label(item.rawValue, systemImage: item.icon)
                            .font(.callout.weight(.medium))
                    }
                }
            }

            // Conversation history (only shown when in Chat)
            Section("Recent Chats") {
                ForEach(conversations) { conversation in
                    Button {
                        selectedNav = .chat
                        chatVM.selectedConversation = conversation
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(conversation.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .lineLimit(1)

                                Spacer()

                                // Provider badge
                                if let providerID = conversation.providerID {
                                    ProviderBadge(providerID: providerID, compact: true)
                                }
                            }

                            Text(conversation.updatedAt.formatted(.relative(presentation: .named)))
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.35))
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            chatVM.deleteConversation(conversation, modelContext: modelContext)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        chatVM.deleteConversation(conversations[index], modelContext: modelContext)
                    }
                }
            }
        }
        .navigationTitle("OpusNative")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    chatVM.newConversation()
                    selectedNav = .chat
                } label: {
                    Label("New Chat", systemImage: "plus.message")
                        .foregroundStyle(accentColor)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .listStyle(.sidebar)
    }
}

// MARK: - Provider Badge

struct ProviderBadge: View {
    let providerID: String
    var compact: Bool = false

    private var color: Color {
        switch providerID {
        case "anthropic": return Color(red: 0.91, green: 0.40, blue: 0.29) // Coral
        case "openai": return Color(red: 0.29, green: 0.85, blue: 0.58) // Green
        case "huggingface": return Color(red: 1.0, green: 0.82, blue: 0.24) // Yellow
        case "ollama": return Color(red: 0.40, green: 0.65, blue: 0.95) // Blue
        case "bedrock": return Color(red: 0.95, green: 0.60, blue: 0.18) // Orange
        default: return .gray
        }
    }

    private var label: String {
        switch providerID {
        case "anthropic": return compact ? "CL" : "Claude"
        case "openai": return compact ? "OA" : "OpenAI"
        case "huggingface": return compact ? "HF" : "HuggingFace"
        case "ollama": return compact ? "OL" : "Ollama"
        case "bedrock": return compact ? "BR" : "Bedrock"
        default: return compact ? "?" : providerID
        }
    }

    var body: some View {
        Text(label)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, compact ? 4 : 8)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.8))
            )
    }
}
