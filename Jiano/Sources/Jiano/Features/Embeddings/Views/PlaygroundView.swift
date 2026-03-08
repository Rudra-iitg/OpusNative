import SwiftUI
import SwiftData
import Charts

struct PlaygroundView: View {
    @Bindable var viewModel: EmbeddingPlaygroundViewModel
    // We still need embeddings for random sampling if no batch input? 
    // Actually the new playground is batch-focused as per request "Multi-Text Input Mode".
    // But let's keep search too? The request focused on "Experimental Lab".
    // I will combine the Batch Lab with the existing Search if possible, or focus on the Lab.
    // Given "Multi-Text Input Mode", I'll add a mode switcher.
    
    @State private var mode: PlaygroundMode = .lab
    @State private var selectedModel: String = ""
    @State private var availableModels: [String] = []
    
    enum PlaygroundMode: String, CaseIterable {
        case lab = "Experiment Lab"
        // case search = "Search" // Keeping it simple for now as requested features are complex
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Label("Experimental Lab", systemImage: "flask.fill")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Batch process text, analyze clusters, and detect anomalies.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 40)
                
                // Controls
                HStack {
                    Picker("Mode", selection: $mode) {
                        ForEach(PlaygroundMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    
                    Spacer()
                    
                    // Model Picker (We need to fetch models here too or rely on parent)
                    // Simple text field for model or hardcoded for now due to time, 
                    // ideally bind to a parent or fetch independently.
                    // Assuming viewModel has access or we pass it.
                    // Let's just use a TextField for model name or "nomic-embed-text" default
                    TextField("Model Name", text: $selectedModel)
                        .frame(width: 150)
                        .textFieldStyle(.roundedBorder)
                        .onAppear { selectedModel = "nomic-embed-text" }
                }
                .padding(.horizontal, 24)
                
                // Batch Input
                VStack(alignment: .leading) {
                    Label("Batch Input (One sentence per line)", systemImage: "list.bullet.clipboard")
                        .font(.headline)
                    
                    TextEditor(text: $viewModel.batchInput)
                        .font(.custom("Menlo", size: 14))
                        .frame(height: 150)
                        .padding(8)
                        .background(Color(nsColor: .textBackgroundColor).opacity(0.8))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.1)))
                    
                    HStack {
                        Stepper("Clusters: \(viewModel.clusterCount)", value: $viewModel.clusterCount, in: 2...10)
                        Spacer()
                        Button(action: {
                            Task { await viewModel.runBatchAnalysis(model: selectedModel) }
                        }) {
                            if viewModel.isProcessing {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("Run Analysis")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.batchInput.isEmpty || viewModel.isProcessing)
                    }
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .padding(.horizontal, 24)
                
                // Results - Clustering
                if !viewModel.clusteredPoints.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Cluster Analysis", systemImage: "bubbles.and.sparkles")
                            .font(.headline)
                        
                        Chart {
                            ForEach(viewModel.clusteredPoints) { point in
                                PointMark(
                                    x: .value("PCA 1", point.x),
                                    y: .value("PCA 2", point.y)
                                )
                                .foregroundStyle(by: .value("Cluster", "Cluster \(point.clusterIndex + 1)"))
                                .symbol(by: .value("Type", point.isAnomaly ? "Anomaly" : "Normal"))
                                .symbolSize(point.isAnomaly ? 100 : 60)
                                .annotation(position: .top) {
                                    if point.isAnomaly {
                                        Text("Anomaly")
                                            .font(.caption2)
                                            .foregroundStyle(.red)
                                            .bold()
                                    }
                                }
                            }
                        }
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .frame(height: 300)
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                        .cornerRadius(12)
                        
                        // Cluster Stats / List
                        Text("Detected Groups")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        ForEach(viewModel.clusters.indices, id: \.self) { idx in
                            let cluster = viewModel.clusters[idx]
                            DisclosureGroup("Cluster \(idx + 1) (\(cluster.memberIndices.count) items)") {
                                VStack(alignment: .leading) {
                                    // Valid index check to avoid crash if sync issue
                                    ForEach(cluster.memberIndices, id: \.self) { memberIdx in
                                        if memberIdx < viewModel.clusteredPoints.count {
                                            Text("• " + viewModel.clusteredPoints[memberIdx].text)
                                                .font(.caption)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                                .padding(.leading)
                            }
                        }
                    }
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .padding(.horizontal, 24)
                }
                
                Spacer()
            }
        }
        .background(
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                Circle()
                    .fill(Color.cyan.opacity(0.05))
                    .frame(width: 800, height: 800)
                    .blur(radius: 100)
                    .offset(x: 200, y: -200)
            }
            .ignoresSafeArea()
        )
        .navigationTitle("Playground")
    }
}
