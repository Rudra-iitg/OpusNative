import SwiftUI

// MARK: - Command Palette

/// A Spotlight-style command palette for keyboard-first navigation.
/// Triggered by ⌘K, provides fuzzy search across all app actions.
struct CommandPalette: View {
    @Binding var isPresented: Bool
    @Binding var selectedNav: NavigationItem?

    @State private var searchText = ""
    @State private var selectedIndex = 0

    private var accentColor: Color { ThemeManager.shared.accent }

    // MARK: - Action Registry

    struct PaletteAction: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let icon: String
        let shortcut: String?
        let action: () -> Void
    }

    private var allActions: [PaletteAction] {
        var actions: [PaletteAction] = []

        // Navigation actions
        for nav in NavigationItem.allCases {
            actions.append(PaletteAction(
                title: "Go to \(nav.rawValue)",
                subtitle: "Navigate to \(nav.rawValue) page",
                icon: nav.icon,
                shortcut: nil,
                action: { selectedNav = nav; isPresented = false }
            ))
        }

        // Provider switching
        for provider in AIManager.shared.configuredProviders {
            actions.append(PaletteAction(
                title: "Switch to \(provider.displayName)",
                subtitle: "Change active AI provider",
                icon: "arrow.triangle.swap",
                shortcut: nil,
                action: {
                    AIManager.shared.switchProvider(to: provider.id)
                    isPresented = false
                }
            ))
        }

        // Quick actions
        actions.append(PaletteAction(
            title: "New Conversation",
            subtitle: "Start a fresh chat",
            icon: "plus.bubble",
            shortcut: "⌘N",
            action: { selectedNav = .chat; isPresented = false }
        ))

        actions.append(PaletteAction(
            title: "Open Settings",
            subtitle: "Configure providers, appearance, and more",
            icon: "gearshape",
            shortcut: "⌘,",
            action: { selectedNav = .settings; isPresented = false }
        ))

        actions.append(PaletteAction(
            title: "Compare Models",
            subtitle: "Side-by-side provider comparison",
            icon: "rectangle.split.2x1",
            shortcut: nil,
            action: { selectedNav = .compare; isPresented = false }
        ))

        actions.append(PaletteAction(
            title: "View Usage Stats",
            subtitle: "Token usage and cost tracking",
            icon: "chart.xyaxis.line",
            shortcut: nil,
            action: { selectedNav = .usage; isPresented = false }
        ))

        return actions
    }

    private var filteredActions: [PaletteAction] {
        if searchText.isEmpty { return allActions }
        let query = searchText.lowercased()
        return allActions.filter {
            $0.title.lowercased().contains(query) ||
            $0.subtitle.lowercased().contains(query)
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(accentColor)
                    .font(.title3)

                TextField("Type a command...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.title3.weight(.light))
                    .foregroundStyle(.white)
                    .onSubmit {
                        executeSelected()
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }

                // Dismiss hint
                Text("ESC")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.08)))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider().overlay(Color.white.opacity(0.1))

            // Results list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(filteredActions.enumerated()), id: \.element.id) { index, action in
                            actionRow(action, isSelected: index == selectedIndex)
                                .id(index)
                                .onTapGesture {
                                    action.action()
                                }
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: 320)
                .onChange(of: selectedIndex) { _, newValue in
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }

            // Footer
            HStack(spacing: 16) {
                keyHint("↑↓", label: "Navigate")
                keyHint("↵", label: "Select")
                keyHint("ESC", label: "Dismiss")
                Spacer()
                Text("\(filteredActions.count) actions")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.03))
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.12, green: 0.12, blue: 0.18),
                                    Color(red: 0.08, green: 0.08, blue: 0.14)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ).opacity(0.95)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
        .frame(width: 520)
        .onKeyPress(.upArrow) {
            selectedIndex = max(0, selectedIndex - 1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            selectedIndex = min(filteredActions.count - 1, selectedIndex + 1)
            return .handled
        }
        .onKeyPress(.escape) {
            isPresented = false
            return .handled
        }
        .onKeyPress(.return) {
            executeSelected()
            return .handled
        }
        .onChange(of: searchText) { _, _ in
            selectedIndex = 0
        }
    }

    // MARK: - Subviews

    private func actionRow(_ action: PaletteAction, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: action.icon)
                .font(.body)
                .foregroundStyle(isSelected ? accentColor : .white.opacity(0.6))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.85))

                Text(action.subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            if let shortcut = action.shortcut {
                Text(shortcut)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.06)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? accentColor.opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
    }

    private func keyHint(_ key: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.06)))

            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.3))
        }
    }

    // MARK: - Actions

    private func executeSelected() {
        guard selectedIndex < filteredActions.count else { return }
        filteredActions[selectedIndex].action()
    }
}
