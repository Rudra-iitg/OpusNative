import SwiftUI
import Charts

struct ComparisonView: View {
    @Bindable var viewModel: EmbeddingComparisonViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: - Header
                VStack(alignment: .leading, spacing: 8) {
                    Label("Semantic Comparison", systemImage: "arrow.left.and.right")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Compare the semantic similarity using multiple metrics.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 40)
                
                // MARK: - Inputs
                HStack(alignment: .top, spacing: 20) {
                    // Source
                    VStack(alignment: .leading) {
                        Label("Source Text", systemImage: "doc.text")
                            .font(.headline)
                        TextEditor(text: $viewModel.sourceText)
                            .font(.custom("Menlo", size: 14))
                            .lineSpacing(4)
                            .padding(8)
                            .background(Color(nsColor: .textBackgroundColor).opacity(0.8))
                            .cornerRadius(12)
                            .frame(height: 120)
                    }
                    
                    // Target
                    VStack(alignment: .leading) {
                        Label("Target Text", systemImage: "doc.text.fill")
                            .font(.headline)
                        TextEditor(text: $viewModel.targetText)
                            .font(.custom("Menlo", size: 14))
                            .lineSpacing(4)
                            .padding(8)
                            .background(Color(nsColor: .textBackgroundColor).opacity(0.8))
                            .cornerRadius(12)
                            .frame(height: 120)
                    }
                }
                .padding(.horizontal, 24)
                
                // Controls
                HStack {
                    Picker("Model", selection: $viewModel.selectedModel) {
                        ForEach(viewModel.availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .frame(width: 200)
                    
                    Button(action: {
                        Task { await viewModel.compare() }
                    }) {
                        if viewModel.isComparing {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Compare Similarity")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.sourceText.isEmpty || viewModel.targetText.isEmpty || viewModel.isComparing)
                }
                .padding(.horizontal, 24)
                
                // MARK: - Analysis Results
                if !viewModel.similarityMetrics.isEmpty {
                    VStack(spacing: 32) {
                        // 1. Primary Metric (Cosine)
                        VStack(spacing: 8) {
                            Text(viewModel.similarityLabel)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(viewModel.similarityColor)
                            
                            Text(viewModel.comparisonDescription)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: 600)
                        }
                        
                        // 2. Radar Chart
                        RadarChartView(
                            data: [
                                "Comparison": viewModel.radarData.map { RadarChartData(category: $0.metric, value: $0.value) }
                            ],
                            axes: ["Cosine", "Euclidean (Inv)", "Manhattan (Inv)", "Dot (Sigmoid)"],
                            colors: ["Comparison": .blue]
                        )
                        .frame(height: 300)
                        
                        /*
                        // Fallback Bar Chart (if Radar has issues)
                        Chart(viewModel.radarData) { item in
                            BarMark(
                                x: .value("Metric", item.metric),
                                y: .value("Score", item.value)
                            )
                            .foregroundStyle(by: .value("Metric", item.metric))
                        }
                        .chartYAxis {
                            AxisMarks(values: [0, 0.5, 1.0])
                        }
                        .frame(height: 250)
                        */
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                        .cornerRadius(16)
                        
                        // 3. Raw Metrics Table
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Raw Metric Values")
                                .font(.headline)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
                                ForEach(Array(viewModel.similarityMetrics.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { key in
                                    VStack(alignment: .leading) {
                                        Text(key.rawValue)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(String(format: "%.4f", viewModel.similarityMetrics[key] ?? 0))
                                            .font(.body)
                                            .monospacedDigit()
                                            .bold()
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                                    .cornerRadius(12)
                                }
                            }
                        }
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .cornerRadius(24)
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                Spacer()
            }
            .padding(.bottom, 40)
        }
        .background(
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                
                GeometryReader { proxy in
                    Circle()
                        .fill(Color.indigo.opacity(0.08))
                        .frame(width: 700, height: 700)
                        .blur(radius: 120)
                        .offset(x: proxy.size.width * 0.5, y: -200)
                }
            }
            .ignoresSafeArea()
        )
        .onAppear {
            Task { await viewModel.fetchModels() }
        }
        .navigationTitle("Comparison")
    }
}
