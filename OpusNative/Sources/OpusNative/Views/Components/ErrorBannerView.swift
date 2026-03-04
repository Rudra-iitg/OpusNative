import SwiftUI
import AppKit

struct ErrorBannerView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text("Error")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(message, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.white.opacity(0.6))

                Button("Dismiss", action: onDismiss)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Text(message)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.85))
                .textSelection(.enabled)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.red.opacity(0.4), lineWidth: 1)
                )
        )
    }
}
