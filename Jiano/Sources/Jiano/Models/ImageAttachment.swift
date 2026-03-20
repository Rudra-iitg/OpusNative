import Foundation

/// A pending image attachment held in `ChatViewModel` until the message is sent.
struct ImageAttachment: Identifiable, Sendable {
    let id = UUID()
    let data: Data
    let mimeType: String   // e.g. "image/jpeg"
    let filename: String
}
