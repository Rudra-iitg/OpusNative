import SwiftUI
import Charts

struct EmbeddingGeneratorView: View {
    @Bindable var viewModel: EmbeddingViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // MARK: - Header & Model Selection
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Model Selection")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Picker("", selection: $viewModel.selectedModel) {
                            ForEach(viewModel.availableModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 200)
                        .disabled(viewModel.isGenerating)
                    }
                    
                    Spacer()
                    
                    if viewModel.isGenerating {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Generating...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                    } else {
                        Button(action: {
                            Task { await viewModel.generateEmbedding() }
                        }) {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Generate Embedding")
                            }
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)
                        .disabled(viewModel.inputText.isEmpty)
                        .shadow(color: .indigo.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                )
                
                // MARK: - Input Area
                VStack(alignment: .leading, spacing: 8) {
                    Label("Input Text", systemImage: "text.quote")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    TextEditor(text: $viewModel.inputText)
                        .font(.custom("Menlo", size: 14)) // Monospaced for tech feel
                        .lineSpacing(4)
                        .scrollContentBackground(.hidden) // Important for custom background
                        .padding(12)
                        .frame(minHeight: 120)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(nsColor: .textBackgroundColor).opacity(0.8))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(viewModel.inputText.isEmpty ? Color.secondary.opacity(0.2) : Color.indigo.opacity(0.5), lineWidth: 1)
                        )
                        .animation(.easeInOut, value: viewModel.inputText.isEmpty)
                }
                
                // MARK: - Error Message
                if let error = viewModel.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(error)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                }
                
                // MARK: - Results Area
                if let stats = viewModel.currentStats, let item = viewModel.currentEmbedding {
                    VStack(alignment: .leading, spacing: 20) {
                        Label("Vector Analysis", systemImage: "waveform.path.ecg")
                            .font(.title3)
                            .bold()
                        
                        // Metrics Grid
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                            PremiumMetricCard(title: "Dimension", value: "\(item.dimension)", icon: "ruler", color: .blue)
                            PremiumMetricCard(title: "L2 Norm", value: String(format: "%.4f", stats.norm), icon: "scalemass", color: .purple)
                            PremiumMetricCard(title: "Mean", value: String(format: "%.6f", stats.mean), icon: "sum", color: .green)
                            PremiumMetricCard(title: "Variance", value: String(format: "%.6f", stats.variance), icon: "chart.bar", color: .orange)
                            PremiumMetricCard(title: "Range", value: String(format: "%.2f ... %.2f", stats.min, stats.max), icon: "arrow.up.and.down", color: .pink)
                            PremiumMetricCard(title: "Sparsity", value: String(format: "%.1f%%", stats.sparsity * 100), icon: "circle.grid.2x2", color: .cyan)
                        }
                        
                        // Vector Chart
                        VStack(alignment: .leading) {
                            Text("Dimension Distribution (First 100)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Chart {
                                ForEach(Array(item.vector.prefix(100).enumerated()), id: \.offset) { index, value in
                                    // Area gradient for premium feel
                                    AreaMark(
                                        x: .value("Index", index),
                                        y: .value("Value", value)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.indigo.opacity(0.5), .indigo.opacity(0.0)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .interpolationMethod(.catmullRom)
                                    
                                    LineMark(
                                        x: .value("Index", index),
                                        y: .value("Value", value)
                                    )
                                    .foregroundStyle(.indigo)
                                    .interpolationMethod(.catmullRom)
                                    .lineStyle(StrokeStyle(lineWidth: 2))
                                }
                            }
                            .frame(height: 250)
                            .chartYAxis {
                                AxisMarks(position: .leading) { value in
                                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                                    AxisValueLabel()
                                }
                            }
                            .chartXAxis {
                                AxisMarks { value in
                                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                    AxisValueLabel()
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .padding(.top, 40)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            // Subtle ambient background
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                
                // Top-right glow
                GeometryReader { proxy in
                    Circle()
                        .fill(Color.indigo.opacity(0.1))
                        .frame(width: 600, height: 600)
                        .blur(radius: 100)
                        .offset(x: proxy.size.width * 0.4, y: -200)
                    
                    // Bottom-left glow
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 500, height: 500)
                        .blur(radius: 100)
                        .offset(x: -200, y: proxy.size.height * 0.6)
                }
            }
            .ignoresSafeArea()
        )
        .navigationTitle("Generator")
    }
}

struct PremiumMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.caption)
                    .padding(6)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            
            Text(value)
                .font(.system(.headline, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(LinearGradient(colors: [.white.opacity(0.2), .black.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}
