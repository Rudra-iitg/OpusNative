import SwiftUI

struct StreamingBubbleView: View {
    let text: String
    var providerName: String = "AI"
    
    @Environment(AppDIContainer.self) private var diContainer
    private var themeManager: ThemeManager { diContainer.themeManager }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(themeManager.accent)
                    Text(providerName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.6))
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                        .tint(themeManager.accent)
                }

                Text(text)
                    .textSelection(.enabled)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                            )
                    )
            }
            Spacer(minLength: 120)
        }
    }
}
