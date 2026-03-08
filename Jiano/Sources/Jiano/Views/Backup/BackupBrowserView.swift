import SwiftUI
import SwiftData

struct BackupBrowserView: View {
    @Bindable var s3Manager = S3BackupManager.shared
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedBackup: BackupManifestFile?
    
    var body: some View {
        NavigationStack {
            List {
                if s3Manager.isListingBackups {
                    HStack {
                        Spacer()
                        ProgressView("Fetching available backups...")
                        Spacer()
                    }
                    .padding()
                } else if s3Manager.availableBackups.isEmpty {
                    Section {
                        Text("No backups found.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section(header: Text("Cloud Backups")) {
                        ForEach(s3Manager.availableBackups) { backup in
                            NavigationLink(destination: BackupDetailView(manifestFile: backup)) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(backup.createdAt.formatted(date: .long, time: .shortened))
                                            .font(.headline)
                                        Text("Items: \(totalItems(in: backup)) • \(backup.deviceName)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if backup.schemaVersion < 2 {
                                        Text("Legacy")
                                            .font(.caption2)
                                            .padding(4)
                                            .background(Color.orange.opacity(0.2))
                                            .foregroundColor(.orange)
                                            .cornerRadius(4)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Backup Browser")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        Task { await s3Manager.listBackupDates() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(s3Manager.isListingBackups)
                }
            }
            .task {
                if s3Manager.availableBackups.isEmpty {
                    await s3Manager.listBackupDates()
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
    
    private func totalItems(in backup: BackupManifestFile) -> Int {
        let m = backup.manifest
        return m.conversationCount + m.comparisonCount + m.codeSessionCount + m.embeddingCount + m.toolAnalysisCount + m.usageRecordCount
    }
}
