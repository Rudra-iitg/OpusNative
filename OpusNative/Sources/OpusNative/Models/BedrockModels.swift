import Foundation

// MARK: - Request Models

struct BedrockRequest: Codable {
    let anthropicVersion: String
    let maxTokens: Int
    let system: String?
    let messages: [MessagePayload]

    enum CodingKeys: String, CodingKey {
        case anthropicVersion = "anthropic_version"
        case maxTokens = "max_tokens"
        case system
        case messages
    }
}

struct MessagePayload: Codable {
    let role: String
    let content: String
}

// MARK: - Streaming Response Event Types

enum StreamEventType: String, Codable {
    case messageStart = "message_start"
    case contentBlockStart = "content_block_start"
    case contentBlockDelta = "content_block_delta"
    case contentBlockStop = "content_block_stop"
    case messageDelta = "message_delta"
    case messageStop = "message_stop"
    case ping
    case error
}

struct StreamEvent: Codable {
    let type: String
}

struct MessageStartEvent: Codable {
    let type: String
    let message: MessageStartPayload
}

struct MessageStartPayload: Codable {
    let id: String
    let role: String
    let model: String
}

struct ContentBlockDeltaEvent: Codable {
    let type: String
    let index: Int
    let delta: DeltaPayload
}

struct DeltaPayload: Codable {
    let type: String
    let text: String?
}

struct MessageDeltaEvent: Codable {
    let type: String
    let delta: MessageDeltaPayload
    let usage: UsagePayload?
}

struct MessageDeltaPayload: Codable {
    let stopReason: String?

    enum CodingKeys: String, CodingKey {
        case stopReason = "stop_reason"
    }
}

struct UsagePayload: Codable {
    let outputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case outputTokens = "output_tokens"
    }
}

struct StreamErrorEvent: Codable {
    let type: String
    let error: ErrorPayload
}

struct ErrorPayload: Codable {
    let type: String
    let message: String
}
