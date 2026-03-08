import SwiftUI
import AppKit

/// Artifact viewer for code blocks with copy and save-to-file functionality.
struct ArtifactView: View {
    let codeBlock: CodeBlock
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label(codeBlock.language.uppercased(), systemImage: "chevron.left.forwardslash.chevron.right")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Code content
            ScrollView([.horizontal, .vertical]) {
                Text(codeBlock.code)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(nsColor: .textBackgroundColor))

            Divider()

            // Action buttons
            HStack(spacing: 16) {
                Button {
                    copyToClipboard()
                } label: {
                    Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    saveToFile()
                } label: {
                    Label("Save to File", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)

                Spacer()

                Text("\(codeBlock.code.components(separatedBy: "\n").count) lines")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(codeBlock.code, forType: .string)
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
    }

    private func saveToFile() {
        let panel = NSSavePanel()
        panel.title = "Save Code"
        panel.nameFieldStringValue = "code.\(fileExtension)"
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            try? codeBlock.code.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private var fileExtension: String {
        let map = [
            "swift": "swift", "python": "py", "javascript": "js",
            "typescript": "ts", "rust": "rs", "go": "go",
            "java": "java", "cpp": "cpp", "c": "c",
            "html": "html", "css": "css", "json": "json",
            "yaml": "yaml", "toml": "toml", "sh": "sh",
            "bash": "sh", "sql": "sql", "ruby": "rb",
            "kotlin": "kt", "dart": "dart",
        ]
        return map[codeBlock.language.lowercased()] ?? "txt"
    }
}
