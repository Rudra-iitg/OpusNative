import Foundation
import CryptoKit

// MARK: - AWS Bedrock Provider

/// AWS Bedrock provider wrapping the existing BedrockService.
/// Supports SigV4 signing, binary event stream decoding, and streaming.
final class AWSBedrockProvider: AIProvider, @unchecked Sendable {
    let id = "bedrock"
    let displayName = "AWS Bedrock"
    let supportsVision = true
    let supportsStreaming = true
    let supportsTools = true

    let availableModels = [
        "us.anthropic.claude-sonnet-4-20250514-v1:0",
        "us.anthropic.claude-opus-4-20250514-v1:0",
        "anthropic.claude-3-5-sonnet-20241022-v2:0",
        "anthropic.claude-3-haiku-20240307-v1:0",
        "amazon.titan-text-express-v1"
    ]

    private let bedrockService = BedrockService()

    // MARK: - Send Message (via streaming, collect all)

    func sendMessage(
        _ message: String,
        conversation: [MessageDTO],
        settings: ModelSettings
    ) async throws -> AIResponse {
        let startTime = CFAbsoluteTimeGetCurrent()

        let stream = try await streamMessage(message, conversation: conversation, settings: settings)

        var fullContent = ""
        for try await chunk in stream {
            fullContent += chunk
        }

        let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        return AIResponse(
            content: fullContent,
            tokenCount: nil,
            latencyMs: latency,
            model: settings.modelName,
            providerID: id,
            finishReason: "stop"
        )
    }

    // MARK: - Stream Message

    func streamMessage(
        _ message: String,
        conversation: [MessageDTO],
        settings: ModelSettings
    ) async throws -> AsyncThrowingStream<String, Error> {
        let credentials = try getCredentials()

        let region = UserDefaults.standard.string(forKey: "awsRegion") ?? "us-east-1"

        // Build ChatMessage objects from DTOs for BedrockService compatibility
        var allMessages: [ChatMessage] = conversation.map { ChatMessage(role: $0.role, content: $0.content) }
        let userMessage = ChatMessage(role: "user", content: message)
        allMessages.append(userMessage)

        let systemPrompt = settings.systemPrompt.isEmpty ? nil : settings.systemPrompt

        return try await bedrockService.streamResponse(
            modelId: settings.modelName,
            messages: allMessages,
            systemPrompt: systemPrompt,
            region: region,
            accessKeyId: credentials.accessKey,
            secretAccessKey: credentials.secretKey
        )
    }

    // MARK: - Private Helpers

    private struct AWSCredentials {
        let accessKey: String
        let secretKey: String
    }

    private func getCredentials() throws -> AWSCredentials {
        guard let accessKey = KeychainService.shared.load(key: KeychainService.accessKeyID),
              let secretKey = KeychainService.shared.load(key: KeychainService.secretAccessKey),
              !accessKey.isEmpty, !secretKey.isEmpty else {
            throw AIProviderError.missingAPIKey(provider: displayName)
        }
        return AWSCredentials(accessKey: accessKey, secretKey: secretKey)
    }
}
