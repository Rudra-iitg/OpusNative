import SwiftUI

struct ChatEmptyStateView: View {
    let themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [themeManager.accent, themeManager.accentLight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: themeManager.accent.opacity(0.3), radius: 30)

            VStack(spacing: 8) {
                Text("Start a conversation")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))

                Text("Select a provider above, then type your message below")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                quickHint(icon: "command", text: "Cmd+K commands")
                quickHint(icon: "arrow.up.circle", text: "Cmd+Enter send")
                quickHint(icon: "plus.message", text: "Cmd+N new chat")
            }
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }

    private func quickHint(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption)
        }
        .foregroundStyle(.white.opacity(0.2))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.04))
        )
    }
}
