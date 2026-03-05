import SwiftUI

struct SettingsGenericEndpointsView: View {
    @State private var manager = GenericEndpointManager.shared
    let accentColor: Color
    
    @State private var showingAddSheet = false
    @State private var editingEndpoint: SavedEndpoint?

    var body: some View {
        SettingsCardView(title: "Generic Endpoints", icon: "network", accentColor: accentColor) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Bring your own OpenAI-compatible endpoint.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                
                ForEach(manager.endpoints) { endpoint in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(endpoint.name)
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                            Text(endpoint.baseURL)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        
                        Spacer()
                        
                        Button {
                            editingEndpoint = endpoint
                            showingAddSheet = true
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(accentColor)
                        
                        Button {
                            manager.delete(endpoint.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                }
                
                Button {
                    editingEndpoint = nil
                    showingAddSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Custom Endpoint")
                    }
                    .font(.subheadline)
                    .foregroundStyle(accentColor)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddGenericEndpointSheet(
                endpointToEdit: editingEndpoint,
                accentColor: accentColor,
                onSave: { endpoint in
                    manager.addOrUpdate(endpoint)
                    showingAddSheet = false
                },
                onCancel: {
                    showingAddSheet = false
                }
            )
        }
    }
}

struct AddGenericEndpointSheet: View {
    var endpointToEdit: SavedEndpoint?
    let accentColor: Color
    var onSave: (SavedEndpoint) -> Void
    var onCancel: () -> Void
    
    @State private var name: String = ""
    @State private var baseURL: String = ""
    @State private var apiKey: String = ""
    @State private var modelName: String = ""
    @State private var isTesting = false
    @State private var testResult: Bool? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(endpointToEdit == nil ? "Add Endpoint" : "Edit Endpoint")
                    .font(.headline)
                Spacer()
                Button("Cancel", action: onCancel)
                    .buttonStyle(.plain)
            }
            .padding()
            
            Form {
                Section {
                    TextField("Name (e.g. My Server)", text: $name)
                        .textFieldStyle(.roundedBorder)
                    TextField("Base URL (e.g. http://10.0.0.5:8000)", text: $baseURL)
                        .textFieldStyle(.roundedBorder)
                    TextField("API Key (Optional)", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                    TextField("Model Name (e.g. llama-3)", text: $modelName)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding()
            
            HStack {
                Button {
                    Task { await testConnection() }
                } label: {
                    HStack {
                        if isTesting {
                            ProgressView().controlSize(.small)
                        }
                        Text("Test Connection")
                    }
                }
                
                if let result = testResult {
                    Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(result ? .green : .red)
                }
                
                Spacer()
                
                Button("Save") {
                    let ep = SavedEndpoint(
                        id: endpointToEdit?.id ?? UUID(),
                        name: name,
                        baseURL: baseURL,
                        apiKey: apiKey,
                        modelName: modelName,
                        customHeaders: endpointToEdit?.customHeaders ?? [:]
                    )
                    onSave(ep)
                }
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
                .disabled(name.isEmpty || baseURL.isEmpty)
            }
            .padding()
        }
        .frame(width: 400)
        .onAppear {
            if let ep = endpointToEdit {
                name = ep.name
                baseURL = ep.baseURL
                apiKey = ep.apiKey
                modelName = ep.modelName
            }
        }
    }
    
    private func testConnection() async {
        isTesting = true
        testResult = nil
        let ep = SavedEndpoint(id: UUID(), name: name, baseURL: baseURL, apiKey: apiKey, modelName: modelName, customHeaders: [:])
        let provider = GenericOpenAICompatibleProvider(endpoint: ep)
        testResult = await provider.testConnection()
        isTesting = false
    }
}
