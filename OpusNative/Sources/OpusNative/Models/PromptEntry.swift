import Foundation
import SwiftData

// MARK: - Prompt Entry (Versioned Prompt)

/// A stored prompt with full version history.
/// Each edit pushes the new text onto `promptVersions` — the last element is always the current version.
/// This enables diffing, reverting, and auditing prompt evolution over time.
@Model
final class PromptEntry {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: String

    /// Version stack: last element = current version, previous elements = history.
    /// Minimum 1 element (the initial version).
    var promptVersions: [String]

    var createdAt: Date
    var updatedAt: Date

    init(name: String, prompt: String, category: String = "General") {
        self.id = UUID()
        self.name = name
        self.category = category
        self.promptVersions = [prompt]
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Computed Properties

    /// The current (latest) version of the prompt text.
    var currentPrompt: String {
        promptVersions.last ?? ""
    }

    /// Number of versions stored.
    var versionCount: Int {
        promptVersions.count
    }

    /// Get prompt text at a specific version (0-indexed, 0 = original).
    func promptAt(version: Int) -> String? {
        guard version >= 0, version < promptVersions.count else { return nil }
        return promptVersions[version]
    }

    // MARK: - Mutation

    /// Save a new version of the prompt. Only adds if the text actually changed.
    func addVersion(_ prompt: String) {
        guard prompt != currentPrompt else { return }
        promptVersions.append(prompt)
        updatedAt = Date()
    }

    /// Revert to a specific version by copying that version's text as a new version.
    /// This preserves the full history (non-destructive revert).
    func revertTo(version: Int) {
        guard let text = promptAt(version: version) else { return }
        addVersion(text)
    }

    // MARK: - Diffing

    /// Simple line-by-line diff between two versions.
    /// Returns an array of diff entries: "+added", "-removed", " unchanged".
    func diff(from fromVersion: Int, to toVersion: Int) -> [String] {
        guard let fromText = promptAt(version: fromVersion),
              let toText = promptAt(version: toVersion) else { return [] }

        let fromLines = fromText.components(separatedBy: "\n")
        let toLines = toText.components(separatedBy: "\n")

        var result: [String] = []
        let maxCount = max(fromLines.count, toLines.count)

        for i in 0..<maxCount {
            let fromLine = i < fromLines.count ? fromLines[i] : nil
            let toLine = i < toLines.count ? toLines[i] : nil

            switch (fromLine, toLine) {
            case let (f?, t?) where f == t:
                result.append(" \(f)")
            case let (f?, t?):
                result.append("-\(f)")
                result.append("+\(t)")
            case let (f?, nil):
                result.append("-\(f)")
            case let (nil, t?):
                result.append("+\(t)")
            default:
                break
            }
        }
        return result
    }
}
