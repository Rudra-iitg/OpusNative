import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Comprehensive settings view with tabs for each provider, model settings, backup, and appearance.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = SettingsViewModel()
    @State private var selectedTab: SettingsTab = .providers

    private var accentColor: Color { ThemeManager.shared.accent }

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
                            providersContent
                        case .model:
                            modelContent
                        case .persona:
                            personaContent
                        case .backup:
                            backupContent
                        case .appearance:
                            appearanceContent
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

    // MARK: - Provider Settings

    private var providersContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("API Keys & Credentials")
                .font(.headline)
                .foregroundStyle(.white)

            settingsCard(title: "Anthropic", icon: "sparkle") {
                secureField("API Key", text: $viewModel.anthropicKey)
            }

            settingsCard(title: "OpenAI", icon: "brain") {
                secureField("API Key", text: $viewModel.openaiKey)
            }

            settingsCard(title: "HuggingFace", icon: "text.magnifyingglass") {
                secureField("Access Token", text: $viewModel.huggingfaceToken)
            }

            settingsCard(title: "Google Gemini", icon: "sparkles") {
                secureField("API Key", text: $viewModel.geminiKey)
            }

            settingsCard(title: "Grok (xAI)", icon: "bolt.fill") {
                secureField("API Key", text: $viewModel.grokKey)
            }

            settingsCard(title: "Ollama (Local)", icon: "desktopcomputer") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Base URL")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                    TextField("http://localhost:11434", text: $viewModel.ollamaBaseURL)
                        .textFieldStyle(.roundedBorder)
                }
            }

            settingsCard(title: "AWS Bedrock", icon: "cloud") {
                VStack(spacing: 12) {
                    secureField("Access Key ID", text: $viewModel.accessKey)
                    secureField("Secret Access Key", text: $viewModel.secretKey)
                    HStack {
                        Text("Region")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                        Picker("", selection: $viewModel.region) {
                            ForEach(SettingsViewModel.regions, id: \.self) { r in
                                Text(r).tag(r)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
        }
    }

    // MARK: - Model Settings

    private var modelContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Inference Parameters")
                .font(.headline)
                .foregroundStyle(.white)

            settingsCard(title: "Temperature", icon: "thermometer") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Slider(value: $viewModel.temperature, in: 0...1, step: 0.05)
                        Text(String(format: "%.2f", viewModel.temperature))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 40)
                    }
                    Text("Lower = more deterministic, higher = more creative")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.3))
                }
            }

            settingsCard(title: "Max Tokens", icon: "number") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Slider(value: Binding(
                            get: { Double(viewModel.maxTokens) },
                            set: { viewModel.maxTokens = Int($0) }
                        ), in: 256...8192, step: 256)
                        Text("\(viewModel.maxTokens)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 50)
                    }
                }
            }

            settingsCard(title: "Top P (Nucleus Sampling)", icon: "chart.pie") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Slider(value: $viewModel.topP, in: 0...1, step: 0.05)
                        Text(String(format: "%.2f", viewModel.topP))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 40)
                    }
                }
            }
        }
    }

    // MARK: - Persona

    private var personaContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("System Prompt / Persona")
                .font(.headline)
                .foregroundStyle(.white)

            TextEditor(text: $viewModel.systemPrompt)
                .font(.body)
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 150)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.08)))
                )

            // Presets
            HStack(spacing: 8) {
                Text("Presets:")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                ForEach(personaPresets, id: \.0) { preset in
                    Button(preset.0) {
                        viewModel.systemPrompt = preset.1
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(accentColor.opacity(0.8))
                }
            }
        }
    }

    private let personaPresets: [(String, String)] = [
        ("Coding Expert", "You are an expert software engineer. Provide clean, well-documented code with best practices. Always explain your reasoning."),
        ("Writing Assistant", "You are a skilled writing assistant. Help craft clear, compelling prose. Pay attention to tone, structure, and readability."),
        ("Concise", "You are a concise AI assistant. Give brief, direct answers. Avoid filler words and unnecessary explanations."),
    ]

    // MARK: - Backup

    private var backupContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("AWS S3 Cloud Backup")
                .font(.headline)
                .foregroundStyle(.white)

            // S3 Configuration Card
            settingsCard(title: "S3 Configuration", icon: "externaldrive.badge.icloud") {
                VStack(spacing: 12) {
                    secureField("S3 Access Key", text: $viewModel.s3AccessKey)
                    secureField("S3 Secret Key", text: $viewModel.s3SecretKey)
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bucket Name")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                            TextField("my-backup-bucket", text: $viewModel.s3BucketName)
                                .textFieldStyle(.roundedBorder)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Region")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                            Picker("", selection: $viewModel.s3Region) {
                                ForEach(SettingsViewModel.regions, id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }
            }

            // Auto-Backup Card
            settingsCard(title: "Auto-Backup", icon: "arrow.triangle.2.circlepath") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: Binding(
                        get: { S3BackupManager.shared.autoBackupEnabled },
                        set: { S3BackupManager.shared.autoBackupEnabled = $0 }
                    )) {
                        Text("Enable auto-backup after chat sessions")
                            .font(.callout)
                    }
                    .toggleStyle(.switch)
                    .tint(accentColor)

                    if S3BackupManager.shared.autoBackupEnabled {
                        HStack {
                            Text("Backup interval")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                            Picker("", selection: Binding(
                                get: { S3BackupManager.shared.autoBackupIntervalMinutes },
                                set: { S3BackupManager.shared.autoBackupIntervalMinutes = $0 }
                            )) {
                                Text("Every 15 min").tag(15)
                                Text("Every 30 min").tag(30)
                                Text("Every 1 hour").tag(60)
                                Text("Every 6 hours").tag(360)
                                Text("Every 24 hours").tag(1440)
                            }
                            .pickerStyle(.menu)
                        }
                    }

                    if let lastDate = S3BackupManager.shared.lastBackupDate {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text("Last backup: \(lastDate.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
            }

            // Manual Backup Card
            settingsCard(title: "Backup Now", icon: "icloud.and.arrow.up") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Encrypt and upload all conversations, clipboard analyses, file analyses, and screenshot results to S3.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))

                    if S3BackupManager.shared.isBackingUp {
                        VStack(alignment: .leading, spacing: 6) {
                            ProgressView(value: S3BackupManager.shared.progress)
                                .tint(accentColor)
                            Text(S3BackupManager.shared.statusMessage)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    } else {
                        Button {
                            Task {
                                if let context = viewModel.modelContext {
                                    await S3BackupManager.shared.backup(modelContext: context)
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.up.circle.fill")
                                Text("Backup All Data")
                            }
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(accentColor))
                        }
                        .buttonStyle(.plain)
                        .disabled(!S3BackupManager.shared.isConfigured)
                    }

                    if !S3BackupManager.shared.statusMessage.isEmpty && !S3BackupManager.shared.isBackingUp {
                        Text(S3BackupManager.shared.statusMessage)
                            .font(.caption)
                            .foregroundStyle(S3BackupManager.shared.statusMessage.contains("✓") ? .green : .white.opacity(0.5))
                    }
                }
            }

            // Restore Card
            settingsCard(title: "Restore from S3", icon: "icloud.and.arrow.down") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Download and merge a backup from a specific date. Existing conversations are preserved — only new data is added.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))

                    Button {
                        Task { await S3BackupManager.shared.listBackupDates() }
                    } label: {
                        HStack {
                            if S3BackupManager.shared.isListingBackups {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Loading...")
                            } else {
                                Image(systemName: "arrow.clockwise")
                                Text("Load Available Backups")
                            }
                        }
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .disabled(!S3BackupManager.shared.isConfigured || S3BackupManager.shared.isListingBackups)

                    if !S3BackupManager.shared.availableBackups.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Available Backups")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.6))

                            ForEach(S3BackupManager.shared.availableBackups) { backup in
                                HStack {
                                    Image(systemName: "clock.fill")
                                        .font(.caption)
                                        .foregroundStyle(accentColor)
                                    Text(backup.displayDate)
                                        .font(.callout)
                                    Spacer()

                                    Button {
                                        Task {
                                            if let context = viewModel.modelContext {
                                                await S3BackupManager.shared.restore(date: backup.date, modelContext: context)
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.down.circle.fill")
                                            Text("Restore")
                                        }
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 5)
                                        .background(Capsule().fill(accentColor.opacity(0.6)))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.03))
                                )
                            }
                        }
                    }

                    if S3BackupManager.shared.isRestoring {
                        VStack(alignment: .leading, spacing: 6) {
                            ProgressView(value: S3BackupManager.shared.progress)
                                .tint(.green)
                            Text(S3BackupManager.shared.statusMessage)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }

                    if let error = S3BackupManager.shared.errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red.opacity(0.8))
                        }
                    }

                    if !S3BackupManager.shared.isRestoring,
                       S3BackupManager.shared.statusMessage.contains("Restored") {
                        Text(S3BackupManager.shared.statusMessage)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.green)
                Text("Backups are encrypted with AES-256-GCM before upload")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    // MARK: - Appearance

    private var appearanceContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Chat Appearance")
                .font(.headline)
                .foregroundStyle(.white)

            // Accent Color Picker
            settingsCard(title: "Accent Color", icon: "paintpalette") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Theme color applied across the entire app")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                        ForEach(ThemeManager.themes) { theme in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    ThemeManager.shared.currentThemeIndex = theme.id
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    ZStack {
                                        Circle()
                                            .fill(theme.color)
                                            .frame(width: 36, height: 36)
                                            .shadow(color: theme.color.opacity(
                                                ThemeManager.shared.currentThemeIndex == theme.id ? 0.6 : 0
                                            ), radius: 8)

                                        if ThemeManager.shared.currentThemeIndex == theme.id {
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
                                            ThemeManager.shared.currentThemeIndex == theme.id
                                                ? .white : .white.opacity(0.4)
                                        )
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            settingsCard(title: "Background Image", icon: "photo") {
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

    // MARK: - Helpers

    private func settingsCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(accentColor)
                    .frame(width: 20)
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.06)))
        )
    }

    private func secureField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
            SecureField("", text: text)
                .textFieldStyle(.roundedBorder)
        }
    }
}
