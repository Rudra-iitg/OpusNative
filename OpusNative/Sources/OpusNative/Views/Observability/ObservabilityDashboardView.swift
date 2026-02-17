import SwiftUI
import Charts

struct ObservabilityDashboardView: View {
    @State private var observability = ObservabilityManager.shared
    @State private var performance = PerformanceManager.shared
    
    @State private var selectedLevel: LogLevel?
    @State private var searchText = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header & Performance Toggle
                HStack {
                    VStack(alignment: .leading) {
                        Text("System Health")
                            .font(.largeTitle.bold())
                        Text("Logs, Metrics, and Performance")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    
                    Toggle("Performance Mode", isOn: Binding(
                        get: { performance.isPerformanceModeEnabled },
                        set: { performance.isPerformanceModeEnabled = $0 }
                    ))
                    .toggleStyle(.switch)
                }
                .padding(.bottom)
                
                // Metrics
                HStack(spacing: 16) {
                    VStack(alignment: .leading) {
                        Text("Average Latency (ms)")
                            .font(.headline)
                        
                        Chart {
                            ForEach(observability.apiLatencySamples.sorted(by: { $0.key < $1.key }), id: \.key) { provider, samples in
                                let avg = samples.reduce(0, +) / Double(samples.count)
                                BarMark(
                                    x: .value("Provider", provider),
                                    y: .value("Latency", avg)
                                )
                                .foregroundStyle(by: .value("Provider", provider))
                            }
                        }
                        .frame(height: 150)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
                    
                    VStack(alignment: .leading) {
                        Text("Error Counts")
                            .font(.headline)
                        
                        List {
                            ForEach(observability.errorCounts.sorted(by: { $0.value > $1.value }), id: \.key) { provider, count in
                                HStack {
                                    Text(provider)
                                    Spacer()
                                    Text("\(count)")
                                        .foregroundStyle(.red)
                                        .bold()
                                }
                            }
                        }
                        .listStyle(.plain)
                        .frame(height: 150)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
                }
                
                // Logs
                VStack(alignment: .leading, spacing: 8) {
                    Text("Live Logs")
                        .font(.headline)
                    
                    HStack {
                        TextField("Search logs...", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                        
                        Picker("Level", selection: $selectedLevel) {
                            Text("All").tag(Optional<LogLevel>.none)
                            Text("Debug").tag(Optional(LogLevel.debug))
                            Text("Info").tag(Optional(LogLevel.info))
                            Text("Warning").tag(Optional(LogLevel.warning))
                            Text("Error").tag(Optional(LogLevel.error))
                        }
                        .frame(width: 120)
                    }
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(filteredLogs) { log in
                                HStack(alignment: .top) {
                                    Image(systemName: log.level.icon)
                                        .foregroundStyle(logColor(log.level))
                                        .frame(width: 20)
                                    
                                    Text("[\(log.subsystem)]")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                        .frame(width: 80, alignment: .leading)
                                    
                                    Text(log.message)
                                        .textSelection(.enabled)
                                    
                                    Spacer()
                                    
                                    Text(log.timestamp.formatted(date: .omitted, time: .standard))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .font(.system(.body, design: .monospaced))
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(hoverColor(log.level).opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                    .frame(height: 300)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(8)
                }
            }
            .padding(32)
        }
    }
    
    private var filteredLogs: [LogEntry] {
        observability.logs.filter { log in
            if let selected = selectedLevel, log.level != selected { return false }
            if !searchText.isEmpty {
                return log.message.localizedCaseInsensitiveContains(searchText) ||
                       log.subsystem.localizedCaseInsensitiveContains(searchText)
            }
            return true
        }.reversed()
    }
    
    private func logColor(_ level: LogLevel) -> Color {
        switch level {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
    
    private func hoverColor(_ level: LogLevel) -> Color {
        switch level {
        case .error: return .red
        case .warning: return .orange
        default: return .white
        }
    }
}
