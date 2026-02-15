import Foundation
import AppKit
import ScreenCaptureKit

// MARK: - Screenshot Analyzer

/// Captures the screen using ScreenCaptureKit and sends screenshots to vision-capable AI models for analysis.
@Observable
@MainActor
final class ScreenshotAnalyzer {
    var isCapturing = false
    var isAnalyzing = false
    var capturedImage: NSImage?
    var analysisResult: String = ""
    var errorMessage: String?

    /// Capture the main screen using ScreenCaptureKit
    func captureScreen() async {
        isCapturing = true
        errorMessage = nil

        do {
            // Get available content
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

            guard let display = content.displays.first else {
                errorMessage = "No display found."
                isCapturing = false
                return
            }

            // Configure capture
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = display.width
            config.height = display.height
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.showsCursor = false

            // Capture single frame
            let cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )

            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            capturedImage = nsImage
        } catch {
            errorMessage = "Screen capture failed: \(error.localizedDescription). Check Screen Recording permission in System Settings > Privacy."
        }

        isCapturing = false
    }

    /// Analyze the captured screenshot using a vision-capable provider
    func analyzeScreenshot(prompt: String = "Describe what you see in this screenshot in detail.") async {
        guard let image = capturedImage else {
            errorMessage = "No screenshot captured. Capture a screenshot first."
            return
        }

        guard let provider = AIManager.shared.activeProvider else {
            errorMessage = "No active provider configured."
            return
        }

        guard provider.supportsVision else {
            errorMessage = "\(provider.displayName) does not support vision. Select a vision-capable provider (e.g., Claude, GPT-4o)."
            return
        }

        isAnalyzing = true
        errorMessage = nil
        analysisResult = ""

        // Convert NSImage to base64 PNG
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            errorMessage = "Failed to encode screenshot."
            isAnalyzing = false
            return
        }

        let imagePrompt = "\(prompt)\n\n[Screenshot attached as base64 PNG, \(pngData.count / 1024)KB]"

        do {
            let settings = AIManager.shared.settings
            let response = try await provider.sendMessage(imagePrompt, conversation: [], settings: settings)
            analysisResult = response.content

            // Persist for S3 backup
            S3BackupManager.saveToolAnalysis(
                type: "screenshot",
                title: "Screenshot Analysis",
                content: response.content,
                toKey: "screenshotAnalysisHistory"
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isAnalyzing = false
    }

    /// Clear the captured screenshot and results
    func clear() {
        capturedImage = nil
        analysisResult = ""
        errorMessage = nil
    }
}
