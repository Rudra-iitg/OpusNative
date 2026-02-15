import SwiftUI

/// Tools view providing quick access to File Analyzer, Clipboard Monitor, and Screenshot Analyzer.
struct ToolsView: View {
    @State private var fileAnalyzer = FileAnalyzer()
    @State private var clipboardMonitor = ClipboardMonitor()
    @State private var screenshotAnalyzer = ScreenshotAnalyzer()
    @State private var selectedTool: ToolType = .files

    private let accentColor = Color(red: 0.56, green: 0.44, blue: 1.0)
    private let accentGradient = LinearGradient(
        colors: [Color(red: 0.56, green: 0.44, blue: 1.0), Color(red: 0.36, green: 0.24, blue: 0.95)],
        startPoint: .leading, endPoint: .trailing
    )

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

    /// Current provider name and model for display
    private var activeProviderName: String {
        AIManager.shared.activeProvider?.displayName ?? "No Provider"
    }

    private var activeModelName: String {
        AIManager.shared.settings.modelName
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

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
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.07, green: 0.07, blue: 0.12), Color(red: 0.04, green: 0.04, blue: 0.09)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [accentColor.opacity(0.04), .clear],
                    center: .top,
                    startRadius: 50,
                    endRadius: 400
                )
            }
            .ignoresSafeArea()
        )
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("System Tools")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                HStack(spacing: 6) {
                    Text("Using")
                        .foregroundStyle(.white.opacity(0.35))
                    Text(activeProviderName)
                        .foregroundStyle(accentColor.opacity(0.8))
                    if !activeModelName.isEmpty {
                        Text("·")
                            .foregroundStyle(.white.opacity(0.25))
                        Text(activeModelName)
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
                .font(.caption)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
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
                resultCard(
                    title: fileAnalyzer.selectedFileName,
                    content: fileAnalyzer.analysisResult,
                    icon: "doc.text.fill",
                    onClear: { withAnimation { fileAnalyzer.clear() } }
                )
            }
        }
    }

    // MARK: - Clipboard Monitor

    private var clipboardContent: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                Button {
                    clipboardMonitor.readClipboard()
                } label: {
                    Label("Read Clipboard", systemImage: "clipboard")
                        .font(.callout.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)

                Button {
                    Task { await clipboardMonitor.analyzeClipboard() }
                } label: {
                    Label("Analyze", systemImage: "brain")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(accentGradient))
                }
                .buttonStyle(.plain)
            }

            if clipboardMonitor.contentType != .empty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Clipboard Content")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.white.opacity(0.7))

                        // Content type badge
                        Text(clipboardMonitor.contentType.rawValue)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(accentColor.opacity(0.3))
                            )

                        Spacer()

                        // Clear clipboard button
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                clipboardMonitor.clear()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                Text("Clear")
                            }
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.08)))
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Text(clipboardMonitor.clipboardContent.prefix(500))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.3))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.white.opacity(0.06))
                                )
                        )
                }
            }

            if clipboardMonitor.isAnalyzing {
                ProgressView("Analyzing with \(activeProviderName)...")
                    .tint(accentColor)
            }

            if let error = clipboardMonitor.errorMessage {
                ErrorBannerView(message: error) { clipboardMonitor.errorMessage = nil }
            }

            if !clipboardMonitor.analysisResult.isEmpty {
                resultCard(
                    title: "Clipboard Analysis",
                    content: clipboardMonitor.analysisResult,
                    icon: "clipboard.fill",
                    onClear: { withAnimation { clipboardMonitor.clear() } }
                )
            }
        }
    }

    // MARK: - Screenshot Analyzer

    private var screenshotContent: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                Button {
                    Task { await screenshotAnalyzer.captureScreen() }
                } label: {
                    Label("Capture Screen", systemImage: "camera.viewfinder")
                        .font(.callout.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)

                Button {
                    Task { await screenshotAnalyzer.analyzeScreenshot() }
                } label: {
                    Label("Analyze", systemImage: "brain")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(accentGradient))
                }
                .buttonStyle(.plain)
                .disabled(screenshotAnalyzer.capturedImage == nil)
            }

            if let image = screenshotAnalyzer.capturedImage {
                VStack(spacing: 8) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.1)))

                    // Clear screenshot
                    Button {
                        withAnimation { screenshotAnalyzer.clear() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Clear Screenshot")
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }

            if screenshotAnalyzer.isAnalyzing {
                ProgressView("Analyzing with \(activeProviderName)...")
                    .tint(accentColor)
            }

            if let error = screenshotAnalyzer.errorMessage {
                ErrorBannerView(message: error) { screenshotAnalyzer.errorMessage = nil }
            }

            if !screenshotAnalyzer.analysisResult.isEmpty {
                resultCard(
                    title: "Screenshot Analysis",
                    content: screenshotAnalyzer.analysisResult,
                    icon: "camera.fill",
                    onClear: { withAnimation { screenshotAnalyzer.clear() } }
                )
            }
        }
    }

    // MARK: - Result Card

    private func resultCard(title: String, content: String, icon: String, onClear: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                // Provider & model badge
                HStack(spacing: 4) {
                    Image(systemName: "cpu")
                        .font(.system(size: 9))
                    Text("\(activeProviderName) · \(activeModelName)")
                        .lineLimit(1)
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.05))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.06)))
                )
            }

            // Action buttons row
            HStack(spacing: 8) {
                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(content, forType: .string)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.08)))
                    )
                }
                .buttonStyle(.plain)

                Button(action: onClear) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("Clear")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.red.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.red.opacity(0.06))
                            .overlay(Capsule().strokeBorder(Color.red.opacity(0.12)))
                    )
                }
                .buttonStyle(.plain)
            }

            // Content
            Text(content)
                .textSelection(.enabled)
                .foregroundStyle(.white.opacity(0.85))
                .lineSpacing(3)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.03))
                )
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .opacity(0.6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.06))
        )
    }
}
