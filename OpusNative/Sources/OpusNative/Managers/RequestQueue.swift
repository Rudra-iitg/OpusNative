import Foundation

// MARK: - Request Queue

/// Per-provider request queue with exponential backoff for rate limit handling.
/// Routes all AI requests through a managed queue to prevent 429 storms
/// when the Compare page fires multiple simultaneous provider requests.
actor RequestQueue {
    static let shared = RequestQueue()

    // MARK: - Configuration

    /// Per-provider backoff state
    private var backoffState: [String: BackoffState] = [:]

    /// Per-provider concurrent request limit
    private var concurrencyLimits: [String: Int] = [:]

    /// Per-provider active request count
    private var activeRequests: [String: Int] = [:]

    private struct BackoffState {
        var currentDelay: TimeInterval = 0
        var lastRateLimitTime: Date?
        var consecutiveFailures: Int = 0

        static let initialDelay: TimeInterval = 1.0
        static let maxDelay: TimeInterval = 60.0
        static let multiplier: Double = 2.0
        static let resetThreshold: TimeInterval = 120.0 // Reset after 2 min without rate limit
    }

    // MARK: - Public API

    /// Execute a request through the queue with rate limit protection.
    /// Automatically retries on rate limit errors with exponential backoff.
    func execute<T>(
        providerID: String,
        maxRetries: Int = 3,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        // Wait for any active backoff
        await applyBackoff(for: providerID)

        var lastError: Error?

        for attempt in 0..<(maxRetries + 1) {
            do {
                incrementActive(providerID)
                defer { decrementActive(providerID) }

                let result = try await operation()

                // Success — reset backoff
                resetBackoff(for: providerID)
                return result

            } catch let error as AIProviderError {
                switch error {
                case .rateLimited(let retryAfter):
                    // Apply rate limit backoff
                    recordRateLimit(for: providerID, retryAfter: retryAfter)
                    lastError = error

                    if attempt < maxRetries {
                        await applyBackoff(for: providerID)
                        continue
                    }

                default:
                    throw error
                }
            } catch {
                throw error
            }
        }

        throw lastError ?? AIProviderError.serverError(statusCode: 429, message: "Rate limited after \(maxRetries) retries")
    }

    // MARK: - Backoff Management

    private func recordRateLimit(for providerID: String, retryAfter: Int?) {
        var state = backoffState[providerID] ?? BackoffState()
        state.lastRateLimitTime = Date()
        state.consecutiveFailures += 1

        if let retryAfter {
            state.currentDelay = TimeInterval(retryAfter)
        } else {
            // Exponential backoff
            if state.currentDelay == 0 {
                state.currentDelay = BackoffState.initialDelay
            } else {
                state.currentDelay = min(
                    state.currentDelay * BackoffState.multiplier,
                    BackoffState.maxDelay
                )
            }
        }

        backoffState[providerID] = state
    }

    private func resetBackoff(for providerID: String) {
        if var state = backoffState[providerID] {
            // Only reset if enough time has passed since last rate limit
            if let lastTime = state.lastRateLimitTime,
               Date().timeIntervalSince(lastTime) > BackoffState.resetThreshold {
                state.currentDelay = 0
                state.consecutiveFailures = 0
                backoffState[providerID] = state
            }
        }
    }

    private func applyBackoff(for providerID: String) async {
        guard let state = backoffState[providerID], state.currentDelay > 0 else { return }

        // Check if enough time has passed to auto-reset
        if let lastTime = state.lastRateLimitTime,
           Date().timeIntervalSince(lastTime) > BackoffState.resetThreshold {
            backoffState[providerID]?.currentDelay = 0
            backoffState[providerID]?.consecutiveFailures = 0
            return
        }

        let delay = state.currentDelay
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }

    // MARK: - Concurrency Tracking

    private func incrementActive(_ providerID: String) {
        activeRequests[providerID, default: 0] += 1
    }

    private func decrementActive(_ providerID: String) {
        activeRequests[providerID, default: 0] -= 1
    }

    /// Current number of active requests for a provider
    func activeRequestCount(for providerID: String) -> Int {
        activeRequests[providerID] ?? 0
    }

    /// Current backoff delay for a provider (0 if none)
    func currentBackoffDelay(for providerID: String) -> TimeInterval {
        backoffState[providerID]?.currentDelay ?? 0
    }
}
