import Foundation
import SwiftData

enum LogLevel: String, Codable {
    case debug, info, warning, error
    
    var icon: String {
        switch self {
        case .debug: return "ladybug"
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.octagon.fill"
        }
    }
}

struct LogEntry: Identifiable, Codable {
    var id = UUID()
    let timestamp: Date
    let level: LogLevel
    let subsystem: String
    let message: String
    let metadata: [String: String]?
}

@Observable
final class ObservabilityManager {
    static let shared = ObservabilityManager()
    
    // MARK: - State
    var logs: [LogEntry] = []
    private let maxLogs = 1000
    
    // Metrics
    var apiLatencySamples: [String: [Double]] = [:] // Provider -> [Latency]
    var errorCounts: [String: Int] = [:] // Provider -> Count
    
    private init() {}
    
    // MARK: - Logging
    
    @MainActor
    func log(_ message: String, level: LogLevel = .info, subsystem: String = "App", metadata: [String: String]? = nil) {
        let entry = LogEntry(timestamp: Date(), level: level, subsystem: subsystem, message: message, metadata: metadata)
        logs.append(entry)
        
        // Trim if needed
        if logs.count > maxLogs {
            logs.removeFirst(logs.count - maxLogs)
        }
        
        // Console print for debug
        #if DEBUG
        print("[\(subsystem)] \(level.rawValue.uppercased()): \(message)")
        #endif
    }
    
    // MARK: - Metrics
    
    @MainActor
    func trackLatency(provider: String, durationMs: Double) {
        if apiLatencySamples[provider] == nil {
            apiLatencySamples[provider] = []
        }
        apiLatencySamples[provider]?.append(durationMs)
        
        // Keep last 50 samples
        if let count = apiLatencySamples[provider]?.count, count > 50 {
            apiLatencySamples[provider]?.removeFirst()
        }
    }
    
    @MainActor
    func trackError(provider: String) {
        errorCounts[provider, default: 0] += 1
    }
    
    // MARK: - Export
    
    func exportLogs() -> String {
        guard let data = try? JSONEncoder().encode(logs) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
