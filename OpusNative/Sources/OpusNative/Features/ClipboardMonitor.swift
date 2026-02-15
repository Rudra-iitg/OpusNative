import Foundation
import AppKit

// MARK: - Clipboard Monitor

/// Reads and analyzes clipboard content using the active AI provider.
@Observable
@MainActor
final class ClipboardMonitor {
    var isAnalyzing = false
    var clipboardContent: String = ""
    var analysisResult: String = ""
    var contentType: ClipboardContentType = .empty
    var errorMessage: String?

    enum ClipboardContentType: String {
        case text = "Text"
        case image = "Image"
        case empty = "Empty"
    }

    /// Read the current clipboard contents
    func readClipboard() {
        let pasteboard = NSPasteboard.general

        // Check for text
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            clipboardContent = text
            contentType = .text
            return
        }

        // Check for image
        if let _ = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png) {
            clipboardContent = "[Image on clipboard]"
            contentType = .image
            return
        }

        clipboardContent = ""
        contentType = .empty
    }

    /// Analyze clipboard content using the active provider
    func analyzeClipboard() async {
        readClipboard()

        guard contentType != .empty else {
            errorMessage = "Clipboard is empty."
            return
        }

        guard let provider = AIManager.shared.activeProvider else {
            errorMessage = "No active provider configured."
            return
        }

        if contentType == .image && !provider.supportsVision {
            errorMessage = "\(provider.displayName) does not support image analysis."
            return
        }

        isAnalyzing = true
        errorMessage = nil
        analysisResult = ""

        let prompt: String
        switch contentType {
        case .text:
            prompt = """
            Analyze the following content from the clipboard:

            ```
            \(clipboardContent.prefix(8000))
            ```

            Provide a helpful analysis including:
            1. What type of content this is
            2. A summary of the content
            3. Any observations or suggestions
            """

        case .image:
            prompt = "Analyze the image currently on the clipboard. Describe what you see in detail."

        case .empty:
            return
        }

        do {
            let settings = AIManager.shared.settings
            let response = try await provider.sendMessage(prompt, conversation: [], settings: settings)
            analysisResult = response.content

            // Persist for S3 backup
            S3BackupManager.saveToolAnalysis(
                type: "clipboard",
                title: "Clipboard — \(contentType.rawValue)",
                content: response.content,
                toKey: "clipboardAnalysisHistory"
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isAnalyzing = false
    }

    /// Clear clipboard content and analysis results
    func clear() {
        clipboardContent = ""
        contentType = .empty
        analysisResult = ""
        errorMessage = nil
    }
}
