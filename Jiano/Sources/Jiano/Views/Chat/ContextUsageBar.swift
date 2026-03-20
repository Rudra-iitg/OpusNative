import SwiftUI

struct ContextUsageBar: View {
    var usage: Int
    var limit: Int
    var percentage: Double

    // Animate changes
    @State private var animatedPercentage: Double = 0.0

    // 5.1 — Environment and state
    @Environment(AppDIContainer.self) private var diContainer
    @State private var showPicker: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Existing bar + labels content
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

                // Labels row
                HStack {
                    Text("\(format(usage)) / \(format(limit)) tokens")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))

                    Spacer()

                    Text(String(format: "%.1f%%", percentage * 100))
                        .font(.caption2.bold())
                        .foregroundStyle(fillColor)

                    // 5.2 — Override button
                    Button {
                        showPicker.toggle()
                    } label: {
                        if diContainer.contextManager.isManualOverride {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.fill")
                                Text("Override")
                            }
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                            )
                        } else {
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .foregroundStyle(Color.white.opacity(0.3))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.06))
                                        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Set context window limit for this session")
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            // 5.3 — Inline override picker panel
            if showPicker {
                pickerPanel
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showPicker)
        .onChange(of: percentage, initial: true) { _, newValue in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                animatedPercentage = newValue
            }
        }
    }

    private var pickerPanel: some View {
        let accentColor = diContainer.themeManager.accent
        return VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text("Session Context Limit")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                if diContainer.contextManager.isManualOverride {
                    Button("Clear Override") {
                        diContainer.contextManager.clearOverride()
                        showPicker = false
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }

            // Preset chips (exclude Auto preset, i.e. tokens == 0)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ContextManager.presets.filter { $0.tokens > 0 }) { preset in
                        let isActive = diContainer.contextManager.manualOverride == preset.tokens
                        Button {
                            diContainer.contextManager.manualOverride = preset.tokens
                            showPicker = false
                        } label: {
                            Text(preset.label)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(isActive ? .white : Color.white.opacity(0.6))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(isActive ? accentColor : Color.white.opacity(0.06)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Footer note
            Text("Override applies to this session only. Set a global default in Settings → Model.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.03))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 0.5)
        }
    }

    private var fillColor: Color {
        if percentage > 0.9 { return .red }
        if percentage > 0.75 { return .orange }
        return .green
    }

    private func format(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fk", Double(value) / 1_000)
        }
        return "\(value)"
    }
}
