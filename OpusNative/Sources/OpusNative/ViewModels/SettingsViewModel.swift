import Foundation
import SwiftData

/// ViewModel for the Settings view.
/// Manages all provider API keys, model settings, and appearance preferences.
@Observable
@MainActor
final class SettingsViewModel {
    // Provider API Keys
    var anthropicKey: String = ""
    var openaiKey: String = ""
    var huggingfaceToken: String = ""
    var geminiKey: String = ""
    var grokKey: String = ""
    var ollamaBaseURL: String = "http://localhost:11434"

    // OpenRouter
    var openRouterKey: String = ""

    // LiteLLM
    var liteLLMBaseURL: String = "http://localhost:4000"
    var liteLLMKey: String = ""

    // LM Studio
    var lmstudioBaseURL: String = "http://localhost:1234"
    var isLMStudioRunning: Bool = false

    // Azure OpenAI
    var azureOpenAIResourceName: String = ""
    var azureOpenAIDeploymentName: String = ""
    var azureOpenAIApiVersion: String = "2024-02-01"
    var azureOpenAIKey: String = ""

    // AWS Bedrock
    var accessKey: String = ""
    var secretKey: String = ""
    var region: String = "us-east-1"
    var modelId: String = "us.anthropic.claude-sonnet-4-20250514-v1:0"

    // S3 Backup
    var s3AccessKey: String = ""
    var s3SecretKey: String = ""
    var s3BucketName: String = ""
    var s3Region: String = "us-east-1"

    // Model Settings
    var temperature: Double = 0.7
    var maxTokens: Int = 4096
    var topP: Double = 1.0

    // Persona
    var systemPrompt: String = ""

    // Appearance
    var backgroundImagePath: String = ""
    var backgroundOpacity: Double = 0.15

    // Status
    var saveStatus: String = ""

    // SwiftData context (set from view)
    var modelContext: ModelContext?

    let diContainer: AppDIContainer
    
    init(diContainer: AppDIContainer) {
        self.diContainer = diContainer
    }

    static let regions = [
        // US
        "us-east-1",       // N. Virginia
        "us-east-2",       // Ohio
        "us-west-1",       // N. California
        "us-west-2",       // Oregon
        // India
        "ap-south-1",      // Mumbai
        "ap-south-2",      // Hyderabad
        // Asia Pacific
        "ap-northeast-1",  // Tokyo
        "ap-northeast-2",  // Seoul
        "ap-northeast-3",  // Osaka
        "ap-southeast-1",  // Singapore
        "ap-southeast-2",  // Sydney
        "ap-east-1",       // Hong Kong
        // Europe
        "eu-west-1",       // Ireland
        "eu-west-2",       // London
        "eu-west-3",       // Paris
        "eu-central-1",    // Frankfurt
        "eu-central-2",    // Zurich
        "eu-north-1",      // Stockholm
        "eu-south-1",      // Milan
        // Middle East & Africa
        "me-south-1",      // Bahrain
        "me-central-1",    // UAE
        "af-south-1",      // Cape Town
        // South America
        "sa-east-1",       // São Paulo
        // Canada
        "ca-central-1",    // Canada
    ]

    func loadSettings() {
        // Provider keys
        anthropicKey = diContainer.keychainService.load(key: KeychainService.anthropicAPIKey) ?? ""
        openaiKey = diContainer.keychainService.load(key: KeychainService.openaiAPIKey) ?? ""
        huggingfaceToken = diContainer.keychainService.load(key: KeychainService.huggingfaceToken) ?? ""
        geminiKey = diContainer.keychainService.load(key: KeychainService.geminiAPIKey) ?? ""
        grokKey = diContainer.keychainService.load(key: KeychainService.grokAPIKey) ?? ""
        ollamaBaseURL = diContainer.keychainService.load(key: KeychainService.ollamaBaseURL) ?? "http://localhost:11434"
        openRouterKey = diContainer.keychainService.load(key: KeychainService.openRouterAPIKey) ?? ""
        liteLLMKey = diContainer.keychainService.load(key: KeychainService.liteLLMAPIKey) ?? ""
        azureOpenAIKey = diContainer.keychainService.load(key: KeychainService.azureOpenAIAPIKey) ?? ""

        liteLLMBaseURL = UserDefaults.standard.string(forKey: "liteLLMBaseURL") ?? "http://localhost:4000"
        lmstudioBaseURL = UserDefaults.standard.string(forKey: "lmstudioBaseURL") ?? "http://localhost:1234"
        azureOpenAIResourceName = UserDefaults.standard.string(forKey: "azureOpenAIResourceName") ?? ""
        azureOpenAIDeploymentName = UserDefaults.standard.string(forKey: "azureOpenAIDeploymentName") ?? ""
        azureOpenAIApiVersion = UserDefaults.standard.string(forKey: "azureOpenAIApiVersion") ?? "2024-02-01"

        // Bedrock
        accessKey = diContainer.keychainService.load(key: KeychainService.accessKeyID) ?? ""
        secretKey = diContainer.keychainService.load(key: KeychainService.secretAccessKey) ?? ""
        region = UserDefaults.standard.string(forKey: "awsRegion") ?? "us-east-1"
        modelId = UserDefaults.standard.string(forKey: "modelId") ?? "us.anthropic.claude-sonnet-4-20250514-v1:0"

        // S3
        s3AccessKey = diContainer.keychainService.load(key: KeychainService.s3AccessKey) ?? ""
        s3SecretKey = diContainer.keychainService.load(key: KeychainService.s3SecretKey) ?? ""
        s3BucketName = diContainer.keychainService.load(key: KeychainService.s3BucketName) ?? ""
        s3Region = diContainer.keychainService.load(key: KeychainService.s3Region) ?? "us-east-1"

        // Model Settings
        temperature = diContainer.aiManager.settings.temperature
        maxTokens = diContainer.aiManager.settings.maxTokens
        topP = diContainer.aiManager.settings.topP

        // Persona
        systemPrompt = UserDefaults.standard.string(forKey: "systemPrompt") ?? ""

        // Appearance
        backgroundImagePath = UserDefaults.standard.string(forKey: "backgroundImagePath") ?? ""
        backgroundOpacity = UserDefaults.standard.double(forKey: "backgroundOpacity")
        if backgroundOpacity == 0 { backgroundOpacity = 0.15 }
    }

    func saveSettings() {
        // Provider keys (all secure via Keychain)
        var allSaved = true

        if !anthropicKey.isEmpty {
            allSaved = diContainer.keychainService.save(key: KeychainService.anthropicAPIKey, value: anthropicKey) && allSaved
        }
        if !openaiKey.isEmpty {
            allSaved = diContainer.keychainService.save(key: KeychainService.openaiAPIKey, value: openaiKey) && allSaved
        }
        if !huggingfaceToken.isEmpty {
            allSaved = diContainer.keychainService.save(key: KeychainService.huggingfaceToken, value: huggingfaceToken) && allSaved
        }
        if !geminiKey.isEmpty {
            allSaved = diContainer.keychainService.save(key: KeychainService.geminiAPIKey, value: geminiKey) && allSaved
        }
        if !grokKey.isEmpty {
            allSaved = diContainer.keychainService.save(key: KeychainService.grokAPIKey, value: grokKey) && allSaved
        }
        if !ollamaBaseURL.isEmpty {
            allSaved = diContainer.keychainService.save(key: KeychainService.ollamaBaseURL, value: ollamaBaseURL) && allSaved
        }
        if !openRouterKey.isEmpty {
            allSaved = diContainer.keychainService.save(key: KeychainService.openRouterAPIKey, value: openRouterKey) && allSaved
        }
        if !liteLLMKey.isEmpty {
            allSaved = diContainer.keychainService.save(key: KeychainService.liteLLMAPIKey, value: liteLLMKey) && allSaved
        }
        if !azureOpenAIKey.isEmpty {
            allSaved = diContainer.keychainService.save(key: KeychainService.azureOpenAIAPIKey, value: azureOpenAIKey) && allSaved
        }

        UserDefaults.standard.set(liteLLMBaseURL, forKey: "liteLLMBaseURL")
        UserDefaults.standard.set(lmstudioBaseURL, forKey: "lmstudioBaseURL")
        UserDefaults.standard.set(azureOpenAIResourceName, forKey: "azureOpenAIResourceName")
        UserDefaults.standard.set(azureOpenAIDeploymentName, forKey: "azureOpenAIDeploymentName")
        UserDefaults.standard.set(azureOpenAIApiVersion, forKey: "azureOpenAIApiVersion")

        // Bedrock
        if !accessKey.isEmpty {
            allSaved = diContainer.keychainService.save(key: KeychainService.accessKeyID, value: accessKey) && allSaved
        }
        if !secretKey.isEmpty {
            allSaved = diContainer.keychainService.save(key: KeychainService.secretAccessKey, value: secretKey) && allSaved
        }

        // S3
        if !s3AccessKey.isEmpty {
            allSaved = diContainer.keychainService.save(key: KeychainService.s3AccessKey, value: s3AccessKey) && allSaved
        }
        if !s3SecretKey.isEmpty {
            allSaved = diContainer.keychainService.save(key: KeychainService.s3SecretKey, value: s3SecretKey) && allSaved
        }
        if !s3BucketName.isEmpty {
            diContainer.keychainService.save(key: KeychainService.s3BucketName, value: s3BucketName)
        }
        if !s3Region.isEmpty {
            diContainer.keychainService.save(key: KeychainService.s3Region, value: s3Region)
        }

        // UserDefaults
        UserDefaults.standard.set(region, forKey: "awsRegion")
        UserDefaults.standard.set(modelId, forKey: "modelId")
        UserDefaults.standard.set(systemPrompt, forKey: "systemPrompt")
        UserDefaults.standard.set(backgroundImagePath, forKey: "backgroundImagePath")
        UserDefaults.standard.set(backgroundOpacity, forKey: "backgroundOpacity")

        // Update AIManager settings
        var settings = diContainer.aiManager.settings
        settings.temperature = temperature
        settings.maxTokens = maxTokens
        settings.topP = topP
        settings.systemPrompt = systemPrompt
        diContainer.aiManager.settings = settings

        if allSaved {
            saveStatus = "✓ Settings saved securely"
        } else {
            saveStatus = "⚠ Some credentials failed to save"
        }

        Task {
            try? await Task.sleep(for: .seconds(3))
            saveStatus = ""
        }
    }

    func clearBackgroundImage() {
        backgroundImagePath = ""
        UserDefaults.standard.removeObject(forKey: "backgroundImagePath")
    }
}
