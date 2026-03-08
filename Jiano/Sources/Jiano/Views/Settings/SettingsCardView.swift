import SwiftUI

struct SettingsCardView<Content: View>: View {
    let title: String
    let icon: String
    let accentColor: Color
    let content: Content

    init(title: String, icon: String, accentColor: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.accentColor = accentColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(accentColor)
                    .frame(width: 20)
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.06)))
        )
    }
}
