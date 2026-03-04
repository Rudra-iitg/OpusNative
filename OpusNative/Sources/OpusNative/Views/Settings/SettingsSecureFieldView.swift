import SwiftUI

struct SettingsSecureFieldView: View {
    let label: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
            SecureField("", text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}
