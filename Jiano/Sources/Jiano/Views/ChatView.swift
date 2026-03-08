import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit

/// Main chat view with multi-provider support, token/latency display, and model settings.
struct ChatView: View {
    @Bindable var chatVM: ChatViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(AppDIContainer.self) private var diContainer


    private var aiManager: AIManager { diContainer.aiManager }
    private var themeManager: ThemeManager { diContainer.themeManager }
    private var performanceManager: PerformanceManager { diContainer.performanceManager }
    private var reportGenerator: ReportGenerator { diContainer.reportGenerator }
    private var observabilityManager: ObservabilityManager { diContainer.observabilityManager }

    // Background image from settings
    private var backgroundImagePath: String? {
        UserDefaults.standard.string(forKey: "backgroundImagePath")
    }
    private var backgroundOpacity: Double {
        UserDefaults.standard.double(forKey: "backgroundOpacity").clamped(to: 0.05...0.5, default: 0.15)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Provider & Model toolbar
            ChatProviderToolbarView(aiManager: aiManager, performanceManager: performanceManager)
            
            // Context bar — only visible when conversation has usage
            if chatVM.contextPercentage > 0 {
                ContextUsageBar(
                    usage: chatVM.contextUsage,
                    limit: chatVM.contextLimit,
                    percentage: chatVM.contextPercentage
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Messages area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 20) {
                        if let conversation = chatVM.selectedConversation {
                            ForEach(conversation.sortedMessages) { message in
                                MessageBubbleView(message: message)
                                    .id(message.id)
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                                        removal: .opacity
                                    ))
                            }
                        } else {
                            ChatEmptyStateView(themeManager: themeManager)
                        }

                        // Streaming message
                        if chatVM.isStreaming && !chatVM.streamingText.isEmpty {
                            StreamingBubbleView(
                                text: chatVM.streamingText,
                                providerName: aiManager.activeProvider?.displayName ?? "AI"
                            )
                            .id("streaming")
                        }

                        // Error message
                        if let error = chatVM.errorMessage {
                            ErrorBannerView(message: error) {
                                chatVM.errorMessage = nil
                            }
                            .id("error")
                        }
                    }
                    .padding(.horizontal, 48)
                    .padding(.vertical, 24)
                }
                .onChange(of: chatVM.streamingText) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo("streaming", anchor: .bottom)
                    }
                }
                .onChange(of: chatVM.selectedConversation?.messages.count) {
                    if let last = chatVM.selectedConversation?.sortedMessages.last {
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Input area
            ChatInputBarView(
                chatVM: chatVM,
                modelContext: modelContext,
                themeManager: themeManager,
                performanceManager: performanceManager
            )
        }
        .background {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.08, blue: 0.12),
                        Color(red: 0.06, green: 0.07, blue: 0.10),
                        Color(red: 0.05, green: 0.05, blue: 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                if let path = backgroundImagePath, !path.isEmpty,
                   let nsImage = NSImage(contentsOfFile: path) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .opacity(backgroundOpacity)
                        .clipped()
                } else {
                    // App Logo Watermark shadow
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 350, height: 350)
                        .opacity(0.05)
                        .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
                }

                RadialGradient(
                    colors: [
                        themeManager.accent.opacity(0.04),
                        Color.clear
                    ],
                    center: .topTrailing,
                    startRadius: 100,
                    endRadius: 500
                )
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $chatVM.showInspector) {
            PromptInspectorView(
                systemPrompt: aiManager.settings.systemPrompt,
                messages: chatVM.selectedConversation?.sortedMessages ?? [],
                modelSettings: aiManager.settings
            )
        }
        .navigationTitle(chatVM.selectedConversation?.title ?? "OpusNative")
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    chatVM.showInspector = true
                } label: {
                    Label("Inspect Prompt", systemImage: "doc.text.magnifyingglass")
                }
                .help("View full prompt context")
                
                Menu {
                    Button("Export as Markdown") {
                        exportChat(format: .markdown)
                    }
                    Button("Export as JSON") {
                        exportChat(format: .json)
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            }
            
            if chatVM.isStreaming {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        chatVM.stopStreaming()
                    } label: {
                        Label("Stop", systemImage: "stop.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }
    private func exportChat(format: ReportFormat) {
        guard let conversation = chatVM.selectedConversation else { return }
        
        let sorted = conversation.sortedMessages
        let model = aiManager.settings.modelName
        
        guard let data = reportGenerator.generate(conversation: sorted, format: format, model: model) else { return }
        
        let ext = format == .markdown ? "md" : "json"
        let filename = "OpusNative_Chat_\(Date().formatted(date: .numeric, time: .omitted)).\(ext)"
            .replacingOccurrences(of: "/", with: "-")
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = format == .markdown ? [UTType.plainText] : [UTType.json]
        savePanel.nameFieldStringValue = filename
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.title = "Export Conversation"
        savePanel.message = "Choose a location to save your conversation export."
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? data.write(to: url)
                observabilityManager.log("Exported chat to \(url.lastPathComponent)", level: .info, subsystem: "Export")
            }
        }
    }
}



private extension Double {
    func clamped(to range: ClosedRange<Double>, default defaultValue: Double) -> Double {
        if self == 0 { return defaultValue }
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
