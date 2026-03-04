import SwiftUI
import UniformTypeIdentifiers

struct SettingsAppearanceTab: View {
    @Bindable var viewModel: SettingsViewModel
    @Bindable var themeManager: ThemeManager
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Chat Appearance")
                .font(.headline)
                .foregroundStyle(.white)

            // Accent Color Picker
            SettingsCardView(title: "Accent Color", icon: "paintpalette", accentColor: accentColor) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Theme color applied across the entire app")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                        ForEach(ThemeManager.themes) { theme in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    themeManager.currentThemeIndex = theme.id
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    ZStack {
                                        Circle()
                                            .fill(theme.color)
                                            .frame(width: 36, height: 36)
                                            .shadow(color: theme.color.opacity(
                                                themeManager.currentThemeIndex == theme.id ? 0.6 : 0
                                            ), radius: 8)

                                        if themeManager.currentThemeIndex == theme.id {
                                            Circle()
                                                .strokeBorder(.white, lineWidth: 2.5)
                                                .frame(width: 36, height: 36)

                                            Image(systemName: "checkmark")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.white)
                                        }
                                    }

                                    Text(theme.name)
                                        .font(.caption2)
                                        .foregroundStyle(
                                            themeManager.currentThemeIndex == theme.id
                                                ? .white : .white.opacity(0.4)
                                        )
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            SettingsCardView(title: "Background Image", icon: "photo", accentColor: accentColor) {
                VStack(alignment: .leading, spacing: 12) {
                    if !viewModel.backgroundImagePath.isEmpty {
                        HStack {
                            Text(viewModel.backgroundImagePath.components(separatedBy: "/").last ?? "")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                                .lineLimit(1)
                            Spacer()
                            Button("Clear") {
                                viewModel.clearBackgroundImage()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(.red.opacity(0.7))
                        }
                    }

                    Button {
                        let panel = NSOpenPanel()
                        panel.allowedContentTypes = [.png, .jpeg, .tiff, .heic]
                        panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK, let url = panel.url {
                            viewModel.backgroundImagePath = url.path
                        }
                    } label: {
                        Label("Choose Image", systemImage: "folder")
                            .font(.callout)
                    }
                    .buttonStyle(.bordered)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Opacity")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                        HStack {
                            Slider(value: $viewModel.backgroundOpacity, in: 0.05...0.5, step: 0.01)
                            Text(String(format: "%.0f%%", viewModel.backgroundOpacity * 100))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(width: 40)
                        }
                    }
                }
            }
        }
    }
}
