import SwiftUI
import SwiftData

struct SettingsBackupTab: View {
    @Bindable var viewModel: SettingsViewModel
    @Bindable var s3BackupManager: S3BackupManager
    let accentColor: Color
    
    @State private var showBackupBrowser = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("AWS S3 Cloud Backup")
                .font(.headline)
                .foregroundStyle(.white)

            // S3 Configuration Card
            SettingsCardView(title: "S3 Configuration", icon: "externaldrive.badge.icloud", accentColor: accentColor) {
                VStack(spacing: 12) {
                    SettingsSecureFieldView(label: "S3 Access Key", text: $viewModel.s3AccessKey)
                    SettingsSecureFieldView(label: "S3 Secret Key", text: $viewModel.s3SecretKey)
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
            SettingsCardView(title: "Auto-Backup", icon: "arrow.triangle.2.circlepath", accentColor: accentColor) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: Binding(
                        get: { s3BackupManager.autoBackupEnabled },
                        set: { s3BackupManager.autoBackupEnabled = $0 }
                    )) {
                        Text("Enable auto-backup after chat sessions")
                            .font(.callout)
                    }
                    .toggleStyle(.switch)
                    .tint(accentColor)

                    if s3BackupManager.autoBackupEnabled {
                        HStack {
                            Text("Backup interval")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                            Picker("", selection: Binding(
                                get: { s3BackupManager.autoBackupIntervalMinutes },
                                set: { s3BackupManager.autoBackupIntervalMinutes = $0 }
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

                    if let lastDate = s3BackupManager.lastBackupDate {
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
            SettingsCardView(title: "Backup Now", icon: "icloud.and.arrow.up", accentColor: accentColor) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Encrypt and upload all conversations, clipboard analyses, file analyses, and screenshot results to S3.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))

                    if s3BackupManager.isBackingUp {
                        VStack(alignment: .leading, spacing: 6) {
                            ProgressView(value: s3BackupManager.progress)
                                .tint(accentColor)
                            Text(s3BackupManager.statusMessage)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    } else {
                        Button {
                            Task {
                                if let context = viewModel.modelContext {
                                    await s3BackupManager.backup(modelContext: context)
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
                        .disabled(!s3BackupManager.isConfigured)
                    }

                    if !s3BackupManager.statusMessage.isEmpty && !s3BackupManager.isBackingUp {
                        Text(s3BackupManager.statusMessage)
                            .font(.caption)
                            .foregroundStyle(s3BackupManager.statusMessage.contains("✓") ? .green : .white.opacity(0.5))
                    }
                }
            }

            // Restore Card
            SettingsCardView(title: "Restore from S3", icon: "icloud.and.arrow.down", accentColor: accentColor) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Browse cloud backups and selectively restore specific data.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))

                    Button {
                        showBackupBrowser = true
                    } label: {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("Browse & Restore Backups")
                        }
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .disabled(!s3BackupManager.isConfigured)
                }
            }
            .sheet(isPresented: $showBackupBrowser) {
                BackupBrowserView()
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
}
