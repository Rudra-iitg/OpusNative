import SwiftUI
import SwiftData

struct EmbeddingWorkspaceView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: EmbeddingWorkspaceViewModel
    
    let diContainer: AppDIContainer
    
    init(diContainer: AppDIContainer) {
        self.diContainer = diContainer
        self._viewModel = State(initialValue: EmbeddingWorkspaceViewModel(diContainer: diContainer))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Toolbar
            workspaceToolbar
                .padding()
                .background(.ultraThinMaterial)
                .border(width: 1, edges: [.bottom], color: Color(nsColor: .separatorColor))
            
            // Main Content Area
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Left Input Pane
                    inputPane
                        .frame(width: max(300, geometry.size.width * 0.3))
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                        .border(width: 1, edges: [.trailing], color: Color(nsColor: .separatorColor))
                    
                    // Right Results Pane
                    resultsPane
                        .frame(maxWidth: .infinity)
                        .background(
                            ZStack {
                                Color(nsColor: .windowBackgroundColor)
                                // Standard OpusNative subtle background glow
                                Circle()
                                    .fill(Color.indigo.opacity(0.05))
                                    .frame(width: 600, height: 600)
                                    .blur(radius: 100)
                                    .offset(x: 200, y: -200)
                            }
                        )
                }
            }
        }
        .onAppear {
            viewModel.setModelContext(modelContext)
            Task {
                await viewModel.fetchModels()
            }
        }
    }
    
    // MARK: - Toolbar
    private var workspaceToolbar: some View {
        HStack {
            Text("Embedding Workspace")
                .font(.headline)
                .padding(.trailing, 16)
            
            // Mode Switcher
            Picker("Mode", selection: $viewModel.currentMode) {
                ForEach(EmbeddingWorkspaceMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 400)
            
            Spacer()
            
            // Global Status
            if viewModel.isProcessing {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 8)
                Text("Processing...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if viewModel.processingTime > 0 {
                Label("\(String(format: "%.0f ms", viewModel.processingTime * 1000))", systemImage: "timer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 8)
                
                Label("\(viewModel.memoryUsageEstimate)", systemImage: "memorychip")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Input Pane (Left Side)
    @ViewBuilder
    private var inputPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Model Section (Shared)
                VStack(alignment: .leading, spacing: 8) {
                    Label("Model Configuration", systemImage: "cpu")
                        .font(.headline)
                    
                    Picker("Model", selection: $viewModel.selectedModel) {
                        ForEach(viewModel.availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.bottom, 8)
                
                Divider()
                
                // Mode-specific Inputs
                switch viewModel.currentMode {
                case .generate:
                    generateInputView
                case .explore:
                    exploreInputView
                case .compare:
                    compareInputView
                case .lab:
                    labInputView
                }
                
                Spacer()
            }
            .padding(20)
        }
    }
    
    // MARK: - Results Pane (Right Side)
    @ViewBuilder
    private var resultsPane: some View {
        switch viewModel.currentMode {
        case .generate:
            GenerateResultView(viewModel: viewModel)
        case .explore:
            ExploreResultView(viewModel: viewModel)
        case .compare:
            CompareResultView(viewModel: viewModel)
        case .lab:
            LabResultView(viewModel: viewModel)
        }
    }
    
    // MARK: - Specific Input Views
    private var generateInputView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Text Input", systemImage: "text.alignleft")
                .font(.headline)
            TextEditor(text: $viewModel.generateInputText)
                .font(.custom("Menlo", size: 14))
                .frame(minHeight: 150)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                .cornerRadius(8)
            
            Button("Generate Embedding") {
                Task { await viewModel.generateSingleEmbedding() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.generateInputText.isEmpty || viewModel.isProcessing)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
    
    private var exploreInputView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Data Source", systemImage: "internaldrive")
                .font(.headline)
            Text("Load embeddings from the local database to explore the vector space.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var compareInputView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Source Text", systemImage: "text.bubble")
                .font(.headline)
            TextEditor(text: $viewModel.compareSourceText)
                .font(.custom("Menlo", size: 14))
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                .cornerRadius(8)
            
            Label("Target Text", systemImage: "text.bubble.fill")
                .font(.headline)
            TextEditor(text: $viewModel.compareTargetText)
                .font(.custom("Menlo", size: 14))
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                .cornerRadius(8)
            
            Button("Calculate Similarity") {
                Task { await viewModel.runComparison() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.compareSourceText.isEmpty || viewModel.compareTargetText.isEmpty || viewModel.isProcessing)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
    
    private var labInputView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Batch Input", systemImage: "list.bullet.rectangle")
                .font(.headline)
            Text("Enter one sentence per line to cluster them.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            TextEditor(text: $viewModel.labBatchInput)
                .font(.custom("Menlo", size: 14))
                .frame(minHeight: 200)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                .cornerRadius(8)
            
            Stepper("Clusters: \(viewModel.labClusterCount)", value: $viewModel.labClusterCount, in: 2...20)
                .padding(.vertical, 8)
            
            Button("Run Analysis") {
                Task { await viewModel.runBatchAnalysis() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.labBatchInput.isEmpty || viewModel.isProcessing)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

// Border Helper
extension View {
    func border(width: CGFloat, edges: [Edge], color: Color) -> some View {
        overlay(EdgeBorder(width: width, edges: edges).foregroundColor(color))
    }
}

struct EdgeBorder: Shape {
    var width: CGFloat
    var edges: [Edge]
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for edge in edges {
            var x: CGFloat {
                switch edge {
                case .top, .bottom, .leading: return rect.minX
                case .trailing: return rect.maxX - width
                }
            }
            var y: CGFloat {
                switch edge {
                case .top, .leading, .trailing: return rect.minY
                case .bottom: return rect.maxY - width
                }
            }
            var w: CGFloat {
                switch edge {
                case .top, .bottom: return rect.width
                case .leading, .trailing: return width
                }
            }
            var h: CGFloat {
                switch edge {
                case .top, .bottom: return width
                case .leading, .trailing: return rect.height
                }
            }
            path.addRect(CGRect(x: x, y: y, width: w, height: h))
        }
        return path
    }
}
