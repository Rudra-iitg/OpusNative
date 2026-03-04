import SwiftUI

struct ChatEmptyStateView: View {
    let themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [themeManager.accent, themeManager.accentLight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: themeManager.accent.opacity(0.4), radius: 20)

            Text("Start a conversation")
                .font(.title2.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))

            Text("Select a provider and type a message below")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.35))

            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
}
