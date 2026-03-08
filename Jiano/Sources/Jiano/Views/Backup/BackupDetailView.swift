import SwiftUI
import SwiftData

struct BackupDetailView: View {
    let manifestFile: BackupManifestFile
    
    @Environment(\.modelContext) private var modelContext
    @State private var options = BackupRestoreEngine.RestoreOptions()
    @State private var isRestoring = false
    @State private var restoreProgress: Double = 0
    @State private var restoreStatus: String = ""
    @State private var restoreResult: BackupRestoreEngine.RestoreResult?
    @State private var restoreError: String?
    
    @State private var isDownloadingPayload = false
    @State private var rawPayloadJSON: String?
    @State private var showingRawJSON = false
    
    var body: some View {
        Form {
            Section(header: Text("Backup Metadata")) {
                LabeledContent("Device", value: manifestFile.deviceName)
                LabeledContent("Date", value: manifestFile.createdAt.formatted(date: .long, time: .shortened))
                LabeledContent("App Version", value: manifestFile.appVersion)
                LabeledContent("Schema Version", value: "\(manifestFile.schemaVersion)")
            }
            
            let m = manifestFile.manifest
            Section(header: Text("Select Data to Restore")) {
                Toggle("Conversations (\(m.conversationCount) items, \(m.messageCount) messages)", isOn: $options.restoreConversations)
                Toggle("Comparisons (\(m.comparisonCount))", isOn: $options.restoreComparisons)
                Toggle("Code Sessions (\(m.codeSessionCount))", isOn: $options.restoreCodeSessions)
                Toggle("Embeddings (\(m.embeddingCount))", isOn: $options.restoreEmbeddings)
                Toggle("Tool Analyses (\(m.toolAnalysisCount))", isOn: $options.restoreToolAnalyses)
                Toggle("Usage Logs (\(m.usageRecordCount))", isOn: $options.restoreUsageLogs)
                Toggle("Restore App Settings", isOn: $options.restoreSettings)
            }
            
            Section {
                if isRestoring {
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: restoreProgress)
                        Text(restoreStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } else if let result = restoreResult {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Restore completed successfully!")
                            .font(.headline)
                            .foregroundColor(.green)
                        
                        Text("Items Added:")
                            .font(.subheadline)
                            .padding(.top, 4)
                        Text("• Conversations: \(result.addedConversations)")
                        Text("• Comparisons: \(result.addedComparisons)")
                        Text("• Code Sessions: \(result.addedCodeSessions)")
                        Text("• Embeddings: \(result.addedEmbeddings)")
                        Text("• Tool Analyses: \(result.addedToolAnalyses)")
                        Text("• Usage Logs: \(result.addedUsageLogs)")
                    }
                    .font(.caption)
                } else if let error = restoreError {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                } else {
                    Button(action: performRestore) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Restore Selected Data")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    // Disable restore if nothing selected
                    .disabled(!(options.restoreConversations || options.restoreComparisons || options.restoreCodeSessions || options.restoreEmbeddings || options.restoreToolAnalyses || options.restoreUsageLogs || options.restoreSettings))
                    
                    if isDownloadingPayload {
                        ProgressView("Downloading Payload...")
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                    } else {
                        Button(action: viewRawData) {
                            HStack {
                                Image(systemName: "doc.text.magnifyingglass")
                                Text("View Raw Backup Data")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 4)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Restore Backup")
        .sheet(isPresented: $showingRawJSON) {
            if let json = rawPayloadJSON {
                NavigationStack {
                    ScrollView {
                        Text(json)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .navigationTitle("Raw Backup Data")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showingRawJSON = false }
                        }
                    }
                }
                .frame(minWidth: 600, minHeight: 600)
            }
        }
    }
    
    private func performRestore() {
        isRestoring = true
        restoreResult = nil
        restoreError = nil
        restoreProgress = 0
        restoreStatus = "Starting..."
        
        // Setup engine
        let engine = BackupRestoreEngine()
        
        Task {
            do {
                let res = try await engine.restore(
                    manifestFile: manifestFile,
                    options: options,
                    context: modelContext,
                    onProgress: { status, prog in
                        Task { @MainActor in
                            self.restoreStatus = status
                            self.restoreProgress = prog
                        }
                    }
                )
                
                await MainActor.run {
                    self.restoreResult = res
                    self.isRestoring = false
                }
            } catch {
                await MainActor.run {
                    self.restoreError = error.localizedDescription
                    self.isRestoring = false
                }
            }
        }
    }
    
    private func viewRawData() {
        isDownloadingPayload = true
        restoreError = nil
        
        Task {
            do {
                let s3Manager = S3BackupManager.shared
                guard let config = s3Manager.getS3Config() else {
                    throw NSError(domain: "BackupDetail", code: 1, userInfo: [NSLocalizedDescriptionKey: "S3 credentials missing"])
                }
                
                let encryptedData = try await s3Manager.downloadFromS3(key: manifestFile.payloadKey, config: config)
                let jsonData = try s3Manager.decrypt(data: encryptedData)
                
                if let str = String(data: jsonData, encoding: .utf8) {
                    await MainActor.run {
                        self.rawPayloadJSON = str
                        self.isDownloadingPayload = false
                        self.showingRawJSON = true
                    }
                } else {
                    throw NSError(domain: "BackupDetail", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to decode JSON string from decrypted data."])
                }
            } catch {
                await MainActor.run {
                    self.restoreError = error.localizedDescription
                    self.isDownloadingPayload = false
                }
            }
        }
    }
}
