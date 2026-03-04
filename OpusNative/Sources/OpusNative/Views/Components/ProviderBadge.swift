import SwiftUI

/// A small badge component to display the initials or full name of an AI provider.
struct ProviderBadge: View {
    let providerID: String
    var compact: Bool = false

    private var color: Color {
        switch providerID {
        case "anthropic": return Color(red: 0.91, green: 0.40, blue: 0.29) // Coral
        case "openai": return Color(red: 0.29, green: 0.85, blue: 0.58) // Green
        case "huggingface": return Color(red: 1.0, green: 0.82, blue: 0.24) // Yellow
        case "ollama": return Color(red: 0.40, green: 0.65, blue: 0.95) // Blue
        case "bedrock": return Color(red: 0.95, green: 0.60, blue: 0.18) // Orange
        case "gemini": return Color(red: 0.35, green: 0.60, blue: 1.0) // Google Blue
        case "grok": return Color(red: 0.85, green: 0.30, blue: 0.30) // Red
        default: return .gray
        }
    }

    private var label: String {
        switch providerID {
        case "anthropic": return compact ? "CL" : "Claude"
        case "openai": return compact ? "OA" : "OpenAI"
        case "huggingface": return compact ? "HF" : "HuggingFace"
        case "ollama": return compact ? "OL" : "Ollama"
        case "bedrock": return compact ? "BR" : "Bedrock"
        case "gemini": return compact ? "GM" : "Gemini"
        case "grok": return compact ? "GK" : "Grok"
        default: return compact ? "?" : providerID
        }
    }

    var body: some View {
        Text(label)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, compact ? 4 : 8)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.8))
            )
    }
}
