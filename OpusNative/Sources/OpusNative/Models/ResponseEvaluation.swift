import Foundation
import SwiftData

// MARK: - Response Evaluation

/// Persisted evaluation of an AI response from the Compare page.
/// Stores thumbs up/down, rubric-based scores, and optional notes.
/// This data can serve as training signal for fine-tuning or model selection.
@Model
final class ResponseEvaluation {
    @Attribute(.unique) var id: UUID

    /// Provider that generated the evaluated response
    var providerID: String

    /// Model name that generated the response
    var modelName: String

    /// The prompt that was used
    var prompt: String

    /// The AI response content that was evaluated
    var responseContent: String

    /// Thumbs up/down rating. `nil` = not yet rated.
    var thumbsUp: Bool?

    /// Rubric-based scores (e.g., {"correctness": 4, "conciseness": 5, "format": 3}).
    /// Each score is 1-5.
    var scores: [String: Int]

    /// Optional free-text notes from the evaluator
    var notes: String?

    /// When this evaluation was created
    var createdAt: Date

    // MARK: - Rubric Categories

    /// Standard rubric categories for evaluation
    static let rubricCategories = ["Correctness", "Conciseness", "Format", "Helpfulness", "Completeness"]

    init(
        providerID: String,
        modelName: String,
        prompt: String,
        responseContent: String,
        thumbsUp: Bool? = nil,
        scores: [String: Int] = [:],
        notes: String? = nil
    ) {
        self.id = UUID()
        self.providerID = providerID
        self.modelName = modelName
        self.prompt = prompt
        self.responseContent = responseContent
        self.thumbsUp = thumbsUp
        self.scores = scores
        self.notes = notes
        self.createdAt = Date()
    }

    // MARK: - Computed

    /// Average score across all rated rubric categories (1.0 - 5.0)
    var averageScore: Double? {
        guard !scores.isEmpty else { return nil }
        let total = scores.values.reduce(0, +)
        return Double(total) / Double(scores.count)
    }

    /// Whether this evaluation has any meaningful data
    var hasData: Bool {
        thumbsUp != nil || !scores.isEmpty || (notes != nil && !notes!.isEmpty)
    }

    /// Human-readable summary of the evaluation
    var summary: String {
        var parts: [String] = []
        if let thumbsUp {
            parts.append(thumbsUp ? "👍" : "👎")
        }
        if let avg = averageScore {
            parts.append(String(format: "%.1f/5.0", avg))
        }
        return parts.isEmpty ? "Not rated" : parts.joined(separator: " · ")
    }
}
