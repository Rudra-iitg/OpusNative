import Foundation
import Combine

@Observable
final class PerformanceManager {
    static let shared = PerformanceManager()
    
    // User preference
    var isPerformanceModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isPerformanceModeEnabled, forKey: "isPerformanceModeEnabled")
            updateConfiguration()
        }
    }
    
    // Configuration values based on mode
    private(set) var blurRadius: Double = 20
    private(set) var animationDuration: Double = 0.3
    private(set) var reduceTranslucency: Bool = false
    
    private init() {
        self.isPerformanceModeEnabled = UserDefaults.standard.bool(forKey: "isPerformanceModeEnabled")
        
        // Listen for thermal state
        Task {
            for await _ in NotificationCenter.default.notifications(named: ProcessInfo.thermalStateDidChangeNotification) {
                await checkThermalState()
            }
        }
        
        updateConfiguration()
    }
    
    @MainActor
    private func checkThermalState() {
        let state = ProcessInfo.processInfo.thermalState
        if state == .serious || state == .critical {
            if !isPerformanceModeEnabled {
                isPerformanceModeEnabled = true
                ObservabilityManager.shared.log("Thermal throttling detected. Enabling Performance Mode.", level: .warning, subsystem: "Performance")
            }
        }
    }
    
    private func updateConfiguration() {
        if isPerformanceModeEnabled {
            blurRadius = 0
            animationDuration = 0
            reduceTranslucency = true
        } else {
            blurRadius = 20
            animationDuration = 0.3
            reduceTranslucency = false
        }
    }
}
