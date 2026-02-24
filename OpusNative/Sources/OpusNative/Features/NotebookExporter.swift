import Foundation
import AppKit
import UniformTypeIdentifiers

// MARK: - Notebook Exporter

/// Exports conversations as Jupyter-style .ipynb notebooks.
/// User messages → markdown cells, AI responses → markdown cells with code blocks extracted as code cells.
struct NotebookExporter {

    /// Export a conversation as a Jupyter Notebook (.ipynb) JSON string
    static func export(conversation: Conversation) -> String {
        let messages = conversation.sortedMessages
        var cells: [[String: Any]] = []

        for message in messages {
            if message.isUser {
                // User messages → markdown cells with bold prefix
                cells.append(markdownCell("**User:**\n\n\(message.content)"))
            } else {
                // AI messages → split into markdown + code cells
                let segments = splitContentIntoSegments(message.content)
                for segment in segments {
                    switch segment {
                    case .markdown(let text):
                        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            cells.append(markdownCell(text))
                        }
                    case .code(let language, let code):
                        cells.append(codeCell(code, language: language))
                    }
                }
            }
        }

        let notebook: [String: Any] = [
            "nbformat": 4,
            "nbformat_minor": 5,
            "metadata": [
                "kernelspec": [
                    "display_name": "Python 3",
                    "language": "python",
                    "name": "python3"
                ],
                "language_info": [
                    "name": "python",
                    "version": "3.11"
                ],
                "title": conversation.title,
                "exported_from": "OpusNative",
                "export_date": ISO8601DateFormatter().string(from: Date())
            ],
            "cells": cells
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: notebook, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return json
    }

    /// Save conversation as .ipynb file via NSSavePanel
    @MainActor
    static func saveToFile(conversation: Conversation) {
        let json = export(conversation: conversation)

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(conversation.title).ipynb"
        panel.title = "Export as Jupyter Notebook"
        panel.message = "Choose where to save the notebook"

        if panel.runModal() == .OK, let url = panel.url {
            try? json.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Content Parsing

    private enum ContentSegment {
        case markdown(String)
        case code(language: String, code: String)
    }

    /// Split AI response content into markdown and code block segments
    private static func splitContentIntoSegments(_ content: String) -> [ContentSegment] {
        var segments: [ContentSegment] = []
        let lines = content.components(separatedBy: "\n")
        var currentMarkdown: [String] = []
        var inCodeBlock = false
        var currentCodeLanguage = "python"
        var currentCode: [String] = []

        for line in lines {
            if line.hasPrefix("```") && !inCodeBlock {
                // Start of code block — flush markdown
                if !currentMarkdown.isEmpty {
                    segments.append(.markdown(currentMarkdown.joined(separator: "\n")))
                    currentMarkdown = []
                }
                inCodeBlock = true
                let lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                currentCodeLanguage = lang.isEmpty ? "python" : lang
                currentCode = []
            } else if line.hasPrefix("```") && inCodeBlock {
                // End of code block — flush code
                inCodeBlock = false
                segments.append(.code(language: currentCodeLanguage, code: currentCode.joined(separator: "\n")))
            } else if inCodeBlock {
                currentCode.append(line)
            } else {
                currentMarkdown.append(line)
            }
        }

        // Flush remaining markdown
        if !currentMarkdown.isEmpty {
            segments.append(.markdown(currentMarkdown.joined(separator: "\n")))
        }

        return segments
    }

    // MARK: - Cell Builders

    private static func markdownCell(_ source: String) -> [String: Any] {
        [
            "cell_type": "markdown",
            "metadata": [:] as [String: Any],
            "source": source.components(separatedBy: "\n").map { $0 + "\n" }
        ]
    }

    private static func codeCell(_ source: String, language: String) -> [String: Any] {
        [
            "cell_type": "code",
            "metadata": [
                "language": language
            ],
            "source": source.components(separatedBy: "\n").map { $0 + "\n" },
            "outputs": [] as [Any],
            "execution_count": NSNull()
        ]
    }
}
