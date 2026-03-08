import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Comprehensive settings view with tabs for each provider, model settings, backup, and appearance.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddProvider = false
    @State private var hoveredProvider: String? = nil
    @State private var selectedTab: SettingsTab = .providers
    
    @Environment(AppDIContainer.self) private var environmentDIContainer
    private var diContainer: AppDIContainer { environmentDIContainer } // Or just keep diContainer via init if we prefer, but let's just use property
    private var themeManager: ThemeManager { diContainer.themeManager }
    private var s3BackupManager: S3BackupManager { diContainer.s3BackupManager }
    private var aiManager: AIManager { diContainer.aiManager } // Include just in case
    
    @State private var viewModel: SettingsViewModel
    
    init(diContainer: AppDIContainer) {
        self._viewModel = State(initialValue: SettingsViewModel(diContainer: diContainer))
    }
    
    private var accentColor: Color { themeManager.accent }

    enum SettingsTab: String, CaseIterable, Identifiable {
        case providers = "Providers"
        case model = "Model"
        case persona = "Persona"
        case backup = "Cloud Backup"
        case appearance = "Appearance"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .providers: return "server.rack"
            case .model: return "slider.horizontal.3"
            case .persona: return "person.text.rectangle"
            case .backup: return "icloud.and.arrow.up"
            case .appearance: return "paintbrush"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "gearshape")
                    .foregroundStyle(accentColor)
                Text("Settings")
                    .font(.title2.weight(.semibold))
                Spacer()

                if !viewModel.saveStatus.isEmpty {
                    Text(viewModel.saveStatus)
                        .font(.caption)
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }
            }
            .padding(20)

            Divider().overlay(Color.white.opacity(0.08))

            HSplitView {
                // Left: tab selector
                VStack(spacing: 4) {
                    ForEach(SettingsTab.allCases) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: tab.icon)
                                    .frame(width: 20)
                                Text(tab.rawValue)
                                    .font(.callout.weight(.medium))
                                Spacer()
                            }
                            .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.5))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedTab == tab ? accentColor.opacity(0.2) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(16)
                .frame(width: 180)

                // Right: content
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch selectedTab {
                        case .providers:
                            SettingsProvidersTab(viewModel: viewModel, accentColor: accentColor)
                        case .model:
                            SettingsModelTab(viewModel: viewModel, accentColor: accentColor)
                        case .persona:
                            SettingsPersonaTab(viewModel: viewModel, accentColor: accentColor)
                        case .backup:
                            SettingsBackupTab(viewModel: viewModel, s3BackupManager: s3BackupManager, accentColor: accentColor)
                        case .appearance:
                            SettingsAppearanceTab(viewModel: viewModel, themeManager: themeManager, accentColor: accentColor)
                        }

                        // Save button
                        Button {
                            viewModel.saveSettings()
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                Text("Save Settings")
                            }
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 10).fill(accentColor))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 12)
                    }
                    .padding(24)
                }
            }
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.08, blue: 0.12), Color(red: 0.05, green: 0.05, blue: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .onAppear {
            viewModel.modelContext = modelContext
            viewModel.loadSettings()
        }
    }

}
