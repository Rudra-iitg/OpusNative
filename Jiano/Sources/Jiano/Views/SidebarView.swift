import SwiftUI
import SwiftData

/// Sidebar with navigation sections and conversation history.
struct SidebarView: View {
    @Bindable var chatVM: ChatViewModel
    @Binding var selectedNav: NavigationItem?
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]
    @State private var hoveredItem: NavigationItem?

    @Environment(AppDIContainer.self) private var diContainer
    private var themeManager: ThemeManager { diContainer.themeManager }

    private var accentColor: Color { themeManager.accent }  // Dynamic accent

    var body: some View {
        List(selection: $selectedNav) {
            // Primary
            Section {
                ForEach([NavigationItem.chat, .compare]) { item in
                    NavigationLink(value: item) {
                        Label(item.rawValue, systemImage: item.icon)
                            .font(.callout.weight(.medium))
                    }
                }
            }

            // Developer tools
            Section("Tools") {
                ForEach([NavigationItem.codeAssistant, .promptLibrary, .tools]) { item in
                    NavigationLink(value: item) {
                        Label(item.rawValue, systemImage: item.icon)
                            .font(.callout.weight(.medium))
                    }
                }
            }

            // Analytics & monitoring
            Section("Insights") {
                ForEach([NavigationItem.embeddings, .usage, .observability]) { item in
                    NavigationLink(value: item) {
                        Label(item.rawValue, systemImage: item.icon)
                            .font(.callout.weight(.medium))
                    }
                }
            }

            Section {
                NavigationLink(value: NavigationItem.settings) {
                    Label(NavigationItem.settings.rawValue, systemImage: NavigationItem.settings.icon)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            // Conversation history
            Section("History") {
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
                        .padding(.vertical, 6)
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

