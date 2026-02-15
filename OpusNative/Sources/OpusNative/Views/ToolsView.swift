import SwiftUI

/// Tools view providing quick access to File Analyzer, Clipboard Monitor, and Screenshot Analyzer.
struct ToolsView: View {
    @State private var fileAnalyzer = FileAnalyzer()
    @State private var clipboardMonitor = ClipboardMonitor()
    @State private var screenshotAnalyzer = ScreenshotAnalyzer()
    @State private var selectedTool: ToolType = .files

    private let accentColor = Color(red: 0.56, green: 0.44, blue: 1.0)

    enum ToolType: String, CaseIterable, Identifiable {
        case files = "File Analyzer"
        case clipboard = "Clipboard"
        case screenshot = "Screenshot"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .files: return "doc.text.magnifyingglass"
            case .clipboard: return "clipboard"
            case .screenshot: return "camera.viewfinder"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "wrench.and.screwdriver")
                    .foregroundStyle(accentColor)
                Text("System Tools")
                    .font(.title2.weight(.semibold))
                Spacer()
            }
            .padding(20)

            // Tool tabs
            HStack(spacing: 0) {
                ForEach(ToolType.allCases) { tool in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTool = tool
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tool.icon)
                            Text(tool.rawValue)
                        }
                        .font(.callout.weight(.medium))
                        .foregroundStyle(selectedTool == tool ? .white : .white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedTool == tool
                                ? accentColor.opacity(0.2)
                                : Color.clear
                        )
                        .overlay(
                            Rectangle()
                                .frame(height: 2)
                                .foregroundStyle(selectedTool == tool ? accentColor : .clear),
                            alignment: .bottom
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.white.opacity(0.03))

            Divider().overlay(Color.white.opacity(0.08))

            // Tool content
            ScrollView {
                switch selectedTool {
                case .files:
                    fileAnalyzerContent
                case .clipboard:
                    clipboardContent
                case .screenshot:
                    screenshotContent
                }
            }
            .padding(24)
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.08, blue: 0.12), Color(red: 0.05, green: 0.05, blue: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    // MARK: - File Analyzer

    private var fileAnalyzerContent: some View {
        VStack(spacing: 20) {
            Button {
                if let file = fileAnalyzer.pickFile() {
                    Task {
                        await fileAnalyzer.analyzeFile(content: file.content, fileName: file.name, isImage: file.isImage)
                    }
                }
            } label: {
                VStack(spacing: 12) {
                    Image(systemName: "doc.badge.gearshape")
                        .font(.system(size: 36))
                        .foregroundStyle(accentColor)
                    Text("Select File to Analyze")
                        .font(.callout.weight(.medium))
                    Text("Supports text, code, images, and more")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 1, dash: [8])))
                )
            }
            .buttonStyle(.plain)

            if fileAnalyzer.isAnalyzing {
                ProgressView("Analyzing \(fileAnalyzer.selectedFileName)...")
                    .tint(accentColor)
            }

            if let error = fileAnalyzer.errorMessage {
                ErrorBannerView(message: error) { fileAnalyzer.errorMessage = nil }
            }

            if !fileAnalyzer.analysisResult.isEmpty {
                resultCard(title: fileAnalyzer.selectedFileName, content: fileAnalyzer.analysisResult)
            }
        }
    }

    // MARK: - Clipboard Monitor

    private var clipboardContent: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                Button {
                    clipboardMonitor.readClipboard()
                } label: {
                    Label("Read Clipboard", systemImage: "clipboard")
                        .font(.callout.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)

                Button {
                    Task { await clipboardMonitor.analyzeClipboard() }
                } label: {
                    Label("Analyze", systemImage: "brain")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(accentColor))
                }
                .buttonStyle(.plain)
            }

            if clipboardMonitor.contentType != .empty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Clipboard Content")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.white.opacity(0.7))
                        ProviderBadge(providerID: clipboardMonitor.contentType.rawValue)
                    }

                    Text(clipboardMonitor.clipboardContent.prefix(500))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.black.opacity(0.3))
                        )
                }
            }

            if clipboardMonitor.isAnalyzing {
                ProgressView("Analyzing...").tint(accentColor)
            }

            if let error = clipboardMonitor.errorMessage {
                ErrorBannerView(message: error) { clipboardMonitor.errorMessage = nil }
            }

            if !clipboardMonitor.analysisResult.isEmpty {
                resultCard(title: "Clipboard Analysis", content: clipboardMonitor.analysisResult)
            }
        }
    }

    // MARK: - Screenshot Analyzer

    private var screenshotContent: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                Button {
                    Task { await screenshotAnalyzer.captureScreen() }
                } label: {
                    Label("Capture Screen", systemImage: "camera.viewfinder")
                        .font(.callout.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)

                Button {
                    Task { await screenshotAnalyzer.analyzeScreenshot() }
                } label: {
                    Label("Analyze", systemImage: "brain")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(accentColor))
                }
                .buttonStyle(.plain)
                .disabled(screenshotAnalyzer.capturedImage == nil)
            }

            if let image = screenshotAnalyzer.capturedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.1)))
            }

            if screenshotAnalyzer.isAnalyzing {
                ProgressView("Analyzing screenshot...").tint(accentColor)
            }

            if let error = screenshotAnalyzer.errorMessage {
                ErrorBannerView(message: error) { screenshotAnalyzer.errorMessage = nil }
            }

            if !screenshotAnalyzer.analysisResult.isEmpty {
                resultCard(title: "Screenshot Analysis", content: screenshotAnalyzer.analysisResult)
            }
        }
    }

    // MARK: - Result Card

    private func resultCard(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(content, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.white.opacity(0.5))
            }

            Text(content)
                .textSelection(.enabled)
                .foregroundStyle(.white.opacity(0.85))
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.03))
                )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.06)))
        )
    }
}
