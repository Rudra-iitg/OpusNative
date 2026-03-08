import SwiftUI

enum HFModelValidationStatus {
    case none
    case loading
    case valid
    case warning(String)
    case invalid
}
struct SettingsProvidersTab: View {
    @Bindable var viewModel: SettingsViewModel
    let accentColor: Color
    
    @State private var showingOpenRouterModels = false
    
    // HuggingFace
    @State private var showingHuggingFacePicker = false
    @State private var customHFModelInput = ""
    @State private var hfModelValidationStatus: HFModelValidationStatus = .none
    
    @AppStorage("huggingface_selected_model") private var hfSelectedModel: String = "mistralai/Mistral-7B-Instruct-v0.3"

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("API Keys & Credentials")
                .font(.headline)
                .foregroundStyle(.white)

            SettingsCardView(title: "Anthropic", icon: "sparkle", accentColor: accentColor) {
                SettingsSecureFieldView(label: "API Key", text: $viewModel.anthropicKey)
            }

            SettingsCardView(title: "OpenAI", icon: "brain", accentColor: accentColor) {
                SettingsSecureFieldView(label: "API Key", text: $viewModel.openaiKey)
            }

            SettingsCardView(title: "HuggingFace", icon: "text.magnifyingglass", accentColor: accentColor) {
                VStack(alignment: .leading, spacing: 12) {
                    SettingsSecureFieldView(label: "Access Token", text: $viewModel.huggingfaceToken)
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    Button {
                        showingHuggingFacePicker = true
                    } label: {
                        HStack {
                            Text("Model")
                                .foregroundStyle(.white)
                            Spacer()
                            Text(hfSelectedModel)
                                .foregroundStyle(.gray)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.gray)
                        }
                        .padding()
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Or enter model ID:")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                        
                        TextField("e.g. google/flan-t5-xxl", text: $customHFModelInput)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                validateCustomHFModel()
                            }
                        
                        HStack {
                            switch hfModelValidationStatus {
                            case .none: EmptyView()
                            case .loading: 
                                ProgressView().controlSize(.small)
                                Text("Validating...").font(.caption).foregroundStyle(.gray)
                            case .valid:
                                Text("✅ Model found and accessible").font(.caption).foregroundStyle(.green)
                            case .warning(let msg):
                                Text("⚠️ \(msg)").font(.caption).foregroundStyle(.yellow)
                            case .invalid:
                                Text("❌ Model not found — check the ID").font(.caption).foregroundStyle(.red)
                            }
                            
                            Spacer()
                            
                            if !customHFModelInput.isEmpty {
                                Link("Open on HuggingFace ↗", destination: URL(string: "https://huggingface.co/\(customHFModelInput)") ?? URL(string: "https://huggingface.co")!)
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    
                    Text("Browse 300,000+ models at huggingface.co. Only models with Inference API support will work without self-hosting.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 4)
                }
            }

            SettingsCardView(title: "Google Gemini", icon: "sparkles", accentColor: accentColor) {
                SettingsSecureFieldView(label: "API Key", text: $viewModel.geminiKey)
            }

            SettingsCardView(title: "Grok (xAI)", icon: "bolt.fill", accentColor: accentColor) {
                SettingsSecureFieldView(label: "API Key", text: $viewModel.grokKey)
            }

            SettingsCardView(title: "Ollama (Local)", icon: "desktopcomputer", accentColor: accentColor) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Base URL")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                    TextField("http://localhost:11434", text: $viewModel.ollamaBaseURL)
                        .textFieldStyle(.roundedBorder)
                }
            }

            SettingsCardView(title: "AWS Bedrock", icon: "cloud", accentColor: accentColor) {
                VStack(spacing: 12) {
                    SettingsSecureFieldView(label: "Access Key ID", text: $viewModel.accessKey)
                    SettingsSecureFieldView(label: "Secret Access Key", text: $viewModel.secretKey)
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

            SettingsCardView(title: "OpenRouter", icon: "arrow.triangle.branch", accentColor: accentColor) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Access 200+ models from multiple providers.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                        Spacer()
                    }
                    SettingsSecureFieldView(label: "API Key", text: $viewModel.openRouterKey)
                    
                    Button {
                        showingOpenRouterModels = true
                    } label: {
                        HStack {
                            Image(systemName: "list.bullet.rectangle")
                            Text("Browse Models")
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(accentColor)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }

            SettingsCardView(title: "LiteLLM", icon: "link.badge.plus", accentColor: accentColor) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Self-hosted proxy for multiple providers.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Base URL")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                        TextField("http://localhost:4000", text: $viewModel.liteLLMBaseURL)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    SettingsSecureFieldView(label: "API Key (Optional)", text: $viewModel.liteLLMKey)
                }
            }

            SettingsCardView(title: "LM Studio", icon: "cpu", accentColor: accentColor) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Local open-source models endpoint.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Base URL")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                        TextField("http://localhost:1234", text: $viewModel.lmstudioBaseURL)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            SettingsCardView(title: "Azure OpenAI", icon: "cloud.microsoft", accentColor: accentColor) {
                VStack(alignment: .leading, spacing: 12) {
                    SettingsSecureFieldView(label: "API Key", text: $viewModel.azureOpenAIKey)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Resource Name")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                        TextField("my-resource", text: $viewModel.azureOpenAIResourceName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Deployment Name")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                        TextField("my-deployment", text: $viewModel.azureOpenAIDeploymentName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Version")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                        TextField("2024-02-01", text: $viewModel.azureOpenAIApiVersion)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
            
            SettingsGenericEndpointsView(accentColor: accentColor)
        }
        .sheet(isPresented: $showingOpenRouterModels) {
            OpenRouterModelsSheet { selectedModel in
                // Currently settings just holds provider credentials. 
                // AIManager active settings configures the current model.
                // We'll just let them browse for now, real model selection happens in SettingsModelTab.
            }
        }
        .sheet(isPresented: $showingHuggingFacePicker) {
            HuggingFaceModelPickerView(apiKey: viewModel.huggingfaceToken) { selectedId in
                hfSelectedModel = selectedId
                customHFModelInput = selectedId
                hfModelValidationStatus = .valid
            }
        }
    }

    // MARK: - Validation
    
    private func validateCustomHFModel() {
        let input = customHFModelInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            hfModelValidationStatus = .none
            return
        }
        
        hfModelValidationStatus = .loading
        
        Task {
            do {
                let isValid = try await HuggingFaceModelService.shared.validateModel(modelId: input, apiKey: viewModel.huggingfaceToken)
                if isValid {
                    hfModelValidationStatus = .valid
                    hfSelectedModel = input
                    UserDefaults.standard.set(input, forKey: "huggingface_selected_model")
                } else {
                    hfModelValidationStatus = .invalid
                }
            } catch {
                hfModelValidationStatus = .warning("Model exists but may not support Inference API")
                hfSelectedModel = input 
                UserDefaults.standard.set(input, forKey: "huggingface_selected_model")
            }
        }
    }
}
