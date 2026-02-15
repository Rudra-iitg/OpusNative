import SwiftUI
import SwiftData

// MARK: - Navigation Item

/// Sidebar navigation destinations
enum NavigationItem: String, CaseIterable, Identifiable {
    case chat = "Chat"
    case compare = "Compare"
    case codeAssistant = "Code Assistant"
    case tools = "Tools"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .compare: return "rectangle.split.2x1"
        case .codeAssistant: return "chevron.left.forwardslash.chevron.right"
        case .tools: return "wrench.and.screwdriver"
        case .settings: return "gearshape"
        }
    }
}

/// Root view: NavigationSplitView with sidebar navigation and dynamic detail panels.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var chatVM = ChatViewModel()
    @State private var compareVM = CompareViewModel()
    @State private var codeAssistant = CodeAssistant()
    @State private var selectedNav: NavigationItem? = .chat
    @State private var toastMessage: String?
    @State private var toastType: ToastView.ToastType = .info

    var body: some View {
        NavigationSplitView {
            SidebarView(chatVM: chatVM, selectedNav: $selectedNav)
        } detail: {
            ZStack {
                detailView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Toast overlay
                if let message = toastMessage {
                    VStack {
                        ToastView(message: message, type: toastType) {
                            toastMessage = nil
                        }
                        .padding(.top, 8)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 900, minHeight: 600)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedNav {
        case .chat:
            ChatView(chatVM: chatVM)
        case .compare:
            CompareView(viewModel: compareVM)
        case .codeAssistant:
            CodeAssistantView(assistant: codeAssistant)
        case .tools:
            ToolsView()
        case .settings:
            SettingsView()
        case .none:
            ChatView(chatVM: chatVM)
        }
    }

    /// Show a toast notification
    func showToast(_ message: String, type: ToastView.ToastType = .info) {
        withAnimation(.spring(response: 0.4)) {
            toastMessage = message
            toastType = type
        }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation(.easeOut(duration: 0.3)) {
                toastMessage = nil
            }
        }
    }
}
