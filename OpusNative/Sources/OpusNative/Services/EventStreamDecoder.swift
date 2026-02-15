import Foundation
import CryptoKit

/// Decodes AWS event-stream binary framing into JSON payloads.
///
/// AWS event-stream format per event:
/// - 4 bytes: total byte length (big endian)
/// - 4 bytes: headers byte length (big endian)
/// - 4 bytes: prelude CRC32 checksum
/// - N bytes: headers (variable length key-value pairs)
/// - M bytes: payload (JSON)
/// - 4 bytes: message CRC32 checksum
final class EventStreamDecoder: @unchecked Sendable {

    private var buffer = Data()

    /// Feed raw bytes into the decoder and extract any complete event payloads
    func decode(_ data: Data) -> [Data] {
        buffer.append(data)
        var payloads: [Data] = []

        while buffer.count >= 12 {  // Minimum: prelude (12 bytes)
            let totalLength = Int(readUInt32(from: buffer, at: 0))
            let headersLength = Int(readUInt32(from: buffer, at: 4))

            guard totalLength >= 16 else {
                // Invalid frame - skip 1 byte
                buffer.removeFirst()
                continue
            }

            guard buffer.count >= totalLength else {
                break  // Wait for more data
            }

            // Extract one complete event
            let eventData = buffer.prefix(totalLength)
            buffer.removeFirst(totalLength)

            // Payload starts after prelude (12 bytes) + headers
            let payloadStart = 12 + headersLength
            let payloadEnd = totalLength - 4  // Exclude trailing CRC

            if payloadEnd > payloadStart {
                let payload = eventData[payloadStart..<payloadEnd]
                payloads.append(Data(payload))
            }
        }

        return payloads
    }

    /// Reset the internal buffer
    func reset() {
        buffer = Data()
    }

    private func readUInt32(from data: Data, at offset: Int) -> UInt32 {
        let bytes = data[data.startIndex + offset ..< data.startIndex + offset + 4]
        return bytes.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
    }
}

// MARK: - Stream Event Parser

struct StreamEventParser {
    private static let decoder = JSONDecoder()

    /// Parse a JSON payload into a typed streaming event and return the text delta if present
    static func parseTextDelta(from data: Data) -> String? {
        // First determine event type
        guard let event = try? decoder.decode(StreamEvent.self, from: data) else {
            return nil
        }

        switch event.type {
        case "content_block_delta":
            guard let deltaEvent = try? decoder.decode(ContentBlockDeltaEvent.self, from: data) else {
                return nil
            }
            return deltaEvent.delta.text

        default:
            return nil
        }
    }

    /// Check if the stream event is an error
    static func parseError(from data: Data) -> String? {
        guard let event = try? decoder.decode(StreamEvent.self, from: data) else {
            return nil
        }
        guard event.type == "error" else { return nil }
        guard let errorEvent = try? decoder.decode(StreamErrorEvent.self, from: data) else {
            return "Unknown error"
        }
        return errorEvent.error.message
    }

    /// Check if the stream has ended
    static func isMessageStop(from data: Data) -> Bool {
        guard let event = try? decoder.decode(StreamEvent.self, from: data) else {
            return false
        }
        return event.type == "message_stop"
    }
}
