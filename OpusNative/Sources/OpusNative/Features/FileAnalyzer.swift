import Foundation
import AppKit
import UniformTypeIdentifiers

// MARK: - File Analyzer

/// Loads files via NSOpenPanel and sends content to the active AI provider for analysis.
@Observable
@MainActor
final class FileAnalyzer {
    var isAnalyzing = false
    var analysisResult: String = ""
    var selectedFileName: String = ""
    var errorMessage: String?

    /// Open a file picker and return the file content
    func pickFile() -> (name: String, content: String, isImage: Bool)? {
        let panel = NSOpenPanel()
        panel.title = "Select File to Analyze"
        panel.allowedContentTypes = [
            .plainText, .sourceCode, .json, .xml, .yaml,
            .html, .css, .pdf,
            .png, .jpeg, .tiff, .heic,
            .swiftSource
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        let fileName = url.lastPathComponent

        // Check if image
        let imageExtensions = ["png", "jpg", "jpeg", "heic", "tiff", "bmp", "gif"]
        let ext = url.pathExtension.lowercased()

        if imageExtensions.contains(ext) {
            // Return base64-encoded image data
            if let data = try? Data(contentsOf: url) {
                let base64 = data.base64EncodedString()
                return (fileName, base64, true)
            }
        }

        // Text file
        if let content = try? String(contentsOf: url, encoding: .utf8) {
            return (fileName, content, false)
        }

        // Binary — try reading as data
        if let data = try? Data(contentsOf: url) {
            return (fileName, "Binary file (\(data.count) bytes) — cannot display as text", false)
        }

        return nil
    }

    /// Analyze the given file content using the active provider
    func analyzeFile(content: String, fileName: String, isImage: Bool) async {
        guard let provider = AIManager.shared.activeProvider else {
            errorMessage = "No active provider configured."
            return
        }

        if isImage && !provider.supportsVision {
            errorMessage = "\(provider.displayName) does not support image analysis. Select a vision-capable provider."
            return
        }

        isAnalyzing = true
        errorMessage = nil
        selectedFileName = fileName
        analysisResult = ""

        let prompt: String
        if isImage {
            prompt = "Analyze this image file named '\(fileName)'. Describe what you see in detail, noting any text, code, diagrams, or notable elements."
        } else {
            prompt = """
            Analyze the following file named '\(fileName)':

            ```
            \(content.prefix(10000))
            ```

            Provide:
            1. What this file does
            2. Key components and their purposes
            3. Any potential issues or improvements
            4. A brief summary
            """
        }

        do {
            let settings = AIManager.shared.settings
            let response = try await provider.sendMessage(prompt, conversation: [], settings: settings)
            analysisResult = response.content
        } catch {
            errorMessage = error.localizedDescription
        }

        isAnalyzing = false
    }

    /// Clear analysis results
    func clear() {
        selectedFileName = ""
        analysisResult = ""
        errorMessage = nil
    }
}
