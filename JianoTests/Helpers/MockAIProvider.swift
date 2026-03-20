import Foundation
@testable import OpusNative

// MARK: - Mock AI Provider

/// A mock implementation of AIProvider for unit testing.
/// Returns hardcoded responses, tracks call counts, and supports error injection.
final class MockAIProvider: AIProvider, @unchecked Sendable {

    // MARK: - AIProvider Protocol

    let id: String
    let displayName: String
    let supportsVision: Bool
    let supportsStreaming: Bool
    let supportsTools: Bool
    let availableModels: [String]

    // MARK: - Test Configuration

    /// Number of times `sendMessage()` has been called
    private(set) var sendMessageCallCount: Int = 0

    /// The last message received by `sendMessage()`
    private(set) var lastReceivedMessage: String?

    /// The last conversation context received by `sendMessage()`
    private(set) var lastReceivedConversation: [MessageDTO]?

    /// If set, `sendMessage()` will throw this error instead of returning a response
    var errorToThrow: Error?

    /// The hardcoded response to return from `sendMessage()`
    var stubbedResponse: AIResponse

    // MARK: - Initialization

    init(
        id: String = "mock",
        displayName: String = "Mock Provider",
        supportsVision: Bool = false,
        supportsStreaming: Bool = false,
        supportsTools: Bool = false,
        availableModels: [String] = ["mock-model-1", "mock-model-2"]
    ) {
        self.id = id
        self.displayName = displayName
        self.supportsVision = supportsVision
        self.supportsStreaming = supportsStreaming
        self.supportsTools = supportsTools
        self.availableModels = availableModels
        self.stubbedResponse = AIResponse(
            content: "Mock response",
            inputTokenCount: 10,
            outputTokenCount: 20,
            latencyMs: 100,
            model: "mock-model-1",
            providerID: id,
            finishReason: "stop"
        )
    }

    // MARK: - AIProvider Methods

    func sendMessage(
        _ message: String,
        conversation: [MessageDTO],
        images: [ImagePayload] = [],
        settings: ModelSettings
    ) async throws -> AIResponse {
        sendMessageCallCount += 1
        lastReceivedMessage = message
        lastReceivedConversation = conversation

        if let error = errorToThrow {
            throw error
        }

        return stubbedResponse
    }

    // MARK: - Test Helpers

    /// Reset all tracking state
    func reset() {
        sendMessageCallCount = 0
        lastReceivedMessage = nil
        lastReceivedConversation = nil
        errorToThrow = nil
    }
}
