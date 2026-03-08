import SwiftUI

// MARK: - Enums & ViewModel

enum ModelTab: String, CaseIterable, Identifiable {
    case trending = "Trending"
    case popular = "Most Downloaded"
    case search = "Search Results"
    
    var id: String { self.rawValue }
}

@Observable
@MainActor
final class HFModelPickerViewModel {
    var searchQuery: String = ""
    var selectedTab: ModelTab = .trending
    
    var trendingModels: [HFModel] = []
    var popularModels: [HFModel] = []
    var searchResults: [HFModel] = []
    
    var recentModels: [String] = []
    
    var isLoading: Bool = false
    var error: String? = nil
    
    var selectedModelId: String = ""
    var customModelIdInput: String = ""
    
    private let service = HuggingFaceModelService.shared
    
    init() {
        self.selectedModelId = UserDefaults.standard.string(forKey: "huggingface_selected_model") ?? "mistralai/Mistral-7B-Instruct-v0.3"
        self.recentModels = UserDefaults.standard.stringArray(forKey: "huggingface_recent_models") ?? []
    }
    
    func loadTrending(apiKey: String) async {
        guard !apiKey.isEmpty else { return }
        isLoading = true
        error = nil
        do {
            trendingModels = try await service.fetchTrendingModels(apiKey: apiKey)
        } catch {
            handleError(error)
        }
        isLoading = false
    }
    
    func loadPopular(apiKey: String) async {
        guard !apiKey.isEmpty else { return }
        isLoading = true
        error = nil
        do {
            popularModels = try await service.fetchPopularModels(apiKey: apiKey)
        } catch {
            handleError(error)
        }
        isLoading = false
    }
    
    func search(query: String, apiKey: String) async {
        guard !apiKey.isEmpty else { return }
        isLoading = true
        error = nil
        do {
            searchResults = try await service.searchModels(query: query, apiKey: apiKey)
            selectedTab = .search
        } catch {
            handleError(error)
        }
        isLoading = false
    }
    
    func validateAndSelectCustomId(apiKey: String) async -> Bool {
        let input = customModelIdInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return false }
        
        do {
            let isValid = try await service.validateModel(modelId: input, apiKey: apiKey)
            if isValid {
                selectModel(id: input)
                return true
            }
        } catch {
            self.error = "Validation failed: \(error.localizedDescription)"
        }
        return false
    }
    
    func selectModel(id: String) {
        selectedModelId = id
        UserDefaults.standard.set(id, forKey: "huggingface_selected_model")
        
        var recents = recentModels
        recents.removeAll(where: { $0 == id })
        recents.insert(id, at: 0)
        if recents.count > 5 {
            recents = Array(recents.prefix(5))
        }
        recentModels = recents
        UserDefaults.standard.set(recents, forKey: "huggingface_recent_models")
    }
    
    private func handleError(_ error: Error) {
        if let hfError = error as? HuggingFaceAPIError, case .networkError(let statusCode) = hfError, statusCode == 503 {
            self.error = "Model is loading on HuggingFace servers, retry in ~20s"
        } else {
            self.error = "Couldn't load models. Check your connection."
        }
    }
}

// MARK: - View

struct HuggingFaceModelPickerView: View {
    let apiKey: String
    let onModelSelected: (String) -> Void
    
    @State private var viewModel = HFModelPickerViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            Divider().background(Color.white.opacity(0.1))
            
            if apiKey.isEmpty {
                noApiKeyView
            } else {
                searchSection
                tabsView
                
                ZStack {
                    modelsList
                    
                    if viewModel.isLoading {
                        loadingOverlay
                    }
                    
                    if let error = viewModel.error {
                        errorOverlay(message: error)
                    }
                }
            }
            
            Divider().background(Color.white.opacity(0.1))
            bottomBar
        }
        .frame(width: 500, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            if !apiKey.isEmpty && viewModel.trendingModels.isEmpty {
                await viewModel.loadTrending(apiKey: apiKey)
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Text("Select HuggingFace Model")
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
            Button {
                Task {
                    viewModel.error = nil
                    if viewModel.selectedTab == .trending {
                        await viewModel.loadTrending(apiKey: apiKey)
                    } else if viewModel.selectedTab == .popular {
                        await viewModel.loadPopular(apiKey: apiKey)
                    } else if viewModel.selectedTab == .search, !viewModel.searchQuery.isEmpty {
                        await viewModel.search(query: viewModel.searchQuery, apiKey: apiKey)
                    }
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.7))
            .disabled(viewModel.isLoading)
        }
        .padding()
        .background(Color.black.opacity(0.2))
    }
    
    private var noApiKeyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.fill")
                .font(.system(size: 40))
                .foregroundStyle(.yellow)
            
            Text("API Key Required")
                .font(.title3.bold())
                .foregroundStyle(.white)
            
            Text("Add your HuggingFace token to browse models. You can still type a model ID manually in the settings view.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal)
            
            Spacer()
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var searchSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search models or paste a model ID...", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .task(id: viewModel.searchQuery) {
                        do {
                            try await Task.sleep(for: .milliseconds(400))
                            guard !viewModel.searchQuery.isEmpty else { return }
                            await viewModel.search(query: viewModel.searchQuery, apiKey: apiKey)
                        } catch {
                            // Cancelled
                        }
                    }
                
                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.black.opacity(0.3))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.top, 12)
            
            if viewModel.searchQuery.contains("/") {
                Button {
                    viewModel.selectModel(id: viewModel.searchQuery)
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Use this model ID directly: \(viewModel.searchQuery)")
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding()
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var tabsView: some View {
        Picker("Tabs", selection: $viewModel.selectedTab) {
            ForEach(ModelTab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding()
        .onChange(of: viewModel.selectedTab) { _, newTab in
            Task {
                if newTab == .popular && viewModel.popularModels.isEmpty {
                    await viewModel.loadPopular(apiKey: apiKey)
                } else if newTab == .trending && viewModel.trendingModels.isEmpty {
                    await viewModel.loadTrending(apiKey: apiKey)
                }
            }
        }
    }
    
    private var modelsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                let models: [HFModel] = {
                    switch viewModel.selectedTab {
                    case .trending: return viewModel.trendingModels
                    case .popular: return viewModel.popularModels
                    case .search: return viewModel.searchResults
                    }
                }()
                
                if models.isEmpty && !viewModel.isLoading {
                    Text("No models found")
                        .foregroundStyle(.gray)
                        .padding(.top, 40)
                } else {
                    let recentSet = Set(viewModel.recentModels)
                    let recentFiltered = models.filter { recentSet.contains($0.modelId) }
                    let othersFiltered = models.filter { !recentSet.contains($0.modelId) }
                    
                    if !recentFiltered.isEmpty {
                        sectionHeader("Recently Used")
                        ForEach(recentFiltered) { model in
                            modelRow(model)
                        }
                        
                        if !othersFiltered.isEmpty {
                            sectionHeader("More Models")
                        }
                    }
                    
                    ForEach(othersFiltered) { model in
                        modelRow(model)
                    }
                }
            }
            .padding(.bottom)
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.gray)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private func modelRow(_ model: HFModel) -> some View {
        let isSelected = (model.modelId == viewModel.selectedModelId)
        return Button {
            viewModel.selectModel(id: model.modelId)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(model.organization)
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Text("/")
                            .font(.caption)
                            .foregroundStyle(.gray.opacity(0.5))
                        Text(model.displayName)
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                    }
                    
                    HStack(spacing: 12) {
                        badgeView(icon: "arrow.down", text: model.formattedDownloads)
                        badgeView(icon: "heart.fill", text: model.formattedLikes, iconColor: .red)

                        // Tags
                        let displayTags = Array(model.tags.prefix(3))
                        ForEach(displayTags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 9, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(4)
                                .foregroundStyle(.gray)
                        }
                        
                        if model.pipelineTag == "text-generation" {
                            Text("✓ Inference API")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundStyle(.green)
                                .cornerRadius(4)
                        }
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.title3)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color.black.opacity(0.2))
            .cornerRadius(10)
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }
    
    private func badgeView(icon: String, text: String, iconColor: Color = .gray) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(iconColor)
            Text(text)
                .font(.system(size: 10))
                .foregroundStyle(.gray)
        }
    }
    
    private var loadingOverlay: some View {
        VStack {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.5))
    }
    
    private func errorOverlay(message: String) -> some View {
        VStack {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .font(.largeTitle)
                .padding(.bottom, 8)
            Text(message)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task {
                    viewModel.error = nil
                    if viewModel.selectedTab == .trending {
                        await viewModel.loadTrending(apiKey: apiKey)
                    } else if viewModel.selectedTab == .popular {
                        await viewModel.loadPopular(apiKey: apiKey)
                    } else if viewModel.selectedTab == .search, !viewModel.searchQuery.isEmpty {
                        await viewModel.search(query: viewModel.searchQuery, apiKey: apiKey)
                    }
                }
            }
            .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.5))
    }
    
    private var bottomBar: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Selected Model")
                    .font(.caption)
                    .foregroundStyle(.gray)
                Text(viewModel.selectedModelId)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
            }
            Spacer()
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            
            Button("Use Selected Model") {
                onModelSelected(viewModel.selectedModelId)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .keyboardShortcut(.defaultAction)
        }
        .padding()
        .background(Color.black.opacity(0.3))
    }
}
