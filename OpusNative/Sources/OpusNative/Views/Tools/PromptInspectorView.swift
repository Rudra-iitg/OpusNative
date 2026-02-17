import SwiftUI
import MarkdownUI

struct PromptInspectorView: View {
    let systemPrompt: String
    let messages: [ChatMessage]
    let modelSettings: ModelSettings
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("System Prompt") {
                    if systemPrompt.isEmpty {
                        Text("No system prompt set.")
                            .italic()
                            .foregroundStyle(.secondary)
                    } else {
                        Text(systemPrompt)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                
                Section("Message History (\(messages.count))") {
                    ForEach(messages) { msg in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(msg.role.uppercased())
                                    .font(.caption.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(roleColor(msg.role).opacity(0.2))
                                    .foregroundStyle(roleColor(msg.role))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                
                                Spacer()
                                
                                Text("\(msg.content.count) chars")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Text(msg.content)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section("Settings Snapshot") {
                    LabeledContent("Model", value: modelSettings.modelName)
                    LabeledContent("Temperature", value: String(format: "%.2f", modelSettings.temperature))
                    LabeledContent("Max Tokens", value: "\(modelSettings.maxTokens)")
                }
            }
            .navigationTitle("Prompt Inspector")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: copyFullCtx) {
                        Label("Copy All", systemImage: "doc.on.doc")
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 600)
    }
    
    private func roleColor(_ role: String) -> Color {
        switch role {
        case "user": return .blue
        case "assistant": return .green
        case "system": return .purple
        default: return .gray
        }
    }
    
    private func copyFullCtx() {
        var full = "SYSTEM:\n\(systemPrompt)\n\n"
        for msg in messages {
            full += "\(msg.role.uppercased()):\n\(msg.content)\n\n"
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(full, forType: .string)
    }
}
