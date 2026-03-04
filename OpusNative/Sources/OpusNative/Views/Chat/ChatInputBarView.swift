import SwiftUI
import SwiftData

struct ChatInputBarView: View {
    @Bindable var chatVM: ChatViewModel
    var modelContext: ModelContext
    let themeManager: ThemeManager
    let performanceManager: PerformanceManager

    @FocusState private var isInputFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextEditor(text: $chatVM.currentMessage)
                .font(.body)
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 36, maxHeight: 120)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
                .focused($isInputFocused)
                .onSubmit {
                    if !NSEvent.modifierFlags.contains(.shift) {
                        chatVM.sendMessage(modelContext: modelContext)
                    }
                }

            Button {
                chatVM.sendMessage(modelContext: modelContext)
            } label: {
                Image(systemName: chatVM.isStreaming ? "ellipsis.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(
                        chatVM.currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color.white.opacity(0.2)
                            : themeManager.accent
                    )
                    .shadow(color: chatVM.currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? .clear
                            : themeManager.accent.opacity(0.5),
                            radius: 8)
            }
            .buttonStyle(.plain)
            .disabled(chatVM.currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chatVM.isStreaming)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            Group {
                if performanceManager.reduceTranslucency {
                    Color(red: 0.1, green: 0.1, blue: 0.12)
                } else {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .overlay(Rectangle().fill(Color.white.opacity(0.03)))
                }
            }
        )
    }
}
