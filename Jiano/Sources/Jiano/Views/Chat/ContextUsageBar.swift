import SwiftUI

struct ContextUsageBar: View {
    var usage: Int
    var limit: Int
    var percentage: Double
    
    // Animate changes
    @State private var animatedPercentage: Double = 0.0
    
    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 4)
                    
                    // Filled bar
                    Capsule()
                        .fill(fillColor)
                        .frame(width: max(0, min(geometry.size.width * animatedPercentage, geometry.size.width)), height: 4)
                        .shadow(color: fillColor.opacity(0.5), radius: 2)
                }
            }
            .frame(height: 4)
            
            // Labels
            HStack {
                Text("\(format(usage)) / \(format(limit)) tokens")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                
                Spacer()
                
                Text(String(format: "%.1f%%", percentage * 100))
                    .font(.caption2.bold())
                    .foregroundStyle(fillColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .onChange(of: percentage, initial: true) { oldValue, newValue in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                animatedPercentage = newValue
            }
        }
    }
    
    private var fillColor: Color {
        if percentage > 0.9 { return .red }
        if percentage > 0.75 { return .orange }
        return .green
    }
    
    private func format(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value)/1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fk", Double(value)/1_000)
        }
        return "\(value)"
    }
}
