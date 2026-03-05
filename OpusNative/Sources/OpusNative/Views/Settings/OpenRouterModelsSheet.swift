import SwiftUI

struct OpenRouterModelsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var models: [ModelInfo] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    
    var onSelect: (ModelInfo) -> Void
    
    var filteredModels: [ModelInfo] {
        if searchText.isEmpty {
            return models
        }
        return models.filter { $0.id.localizedCaseInsensitiveContains(searchText) || $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("OpenRouter Models")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            TextField("Search models...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding()
            
            if isLoading {
                Spacer()
                ProgressView("Fetching models from OpenRouter...")
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                Text("Error: \(error)")
                    .foregroundStyle(.red)
                Button("Retry") {
                    Task { await fetch() }
                }
                .padding(.top)
                Spacer()
            } else {
                List(filteredModels) { model in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(model.displayName)
                                .font(.body.bold())
                            Text(model.id)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Cost (Input/Output)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(model.formatPricing)
                                .font(.caption)
                        }
                        
                        Button("Select") {
                            onSelect(model)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.leading)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 600, height: 500)
        .onAppear {
            Task { await fetch() }
        }
    }
    
    private func fetch() async {
        isLoading = true
        errorMessage = nil
        do {
            let provider = OpenRouterProvider(keychain: KeychainService.shared)
            let fetched = try await provider.fetchAvailableModels()
            // Sort alphabetically by ID
            models = fetched.sorted { $0.id < $1.id }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
