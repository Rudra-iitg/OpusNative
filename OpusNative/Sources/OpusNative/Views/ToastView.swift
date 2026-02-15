import SwiftUI

/// Toast notification view with auto-dismiss and type-based styling.
struct ToastView: View {
    let message: String
    let type: ToastType
    let onDismiss: () -> Void

    enum ToastType {
        case success, error, info, warning

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            }
        }

        var color: Color {
            switch self {
            case .success: return .green
            case .error: return .red
            case .info: return ThemeManager.shared.accent
            case .warning: return .orange
            }
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: type.icon)
                .foregroundStyle(type.color)
                .font(.callout)

            Text(message)
                .font(.callout.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))

            Spacer()

            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    onDismiss()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(type.color.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
        )
        .frame(maxWidth: 400)
    }
}
