import Foundation

// MARK: - LiteLLM Provider

/// Connects to a self-hosted LiteLLM Proxy which exposes an OpenAI-compatible endpoint.
final class LiteLLMProvider: OpenAICompatibleProvider, @unchecked Sendable {
    
    private let keychain: KeychainService
    
    init(keychain: KeychainService) {
        self.keychain = keychain
        
        let storedBaseURL = UserDefaults.standard.string(forKey: "liteLLMBaseURL") ?? "http://localhost:4000"
        
        super.init(
            id: "litellm",
            name: "LiteLLM",
            baseURL: storedBaseURL,
            apiKey: "", // dynamically fetched from keychain
            defaultModel: "anthropic/claude-3-5-sonnet-20241022", // users can specify provider/model
            availableModels: [] // Typically manually typed by user
        )
    }
    
    override func getAPIKey() throws -> String {
        return keychain.load(key: KeychainService.liteLLMAPIKey) ?? ""
    }
    
    // MARK: - Test Connection
    
    /// Tests if the LiteLLM proxy is running by hitting the /health endpoint
    func testConnection() async -> Bool {
        var base = baseURL
        if base.hasSuffix("/") {
            base.removeLast()
        }
        
        let healthURLString = base + "/health"
        guard let url = URL(string: healthURLString) else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 3.0 // quick check
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return (200...299).contains(httpResponse.statusCode)
            }
            return false
        } catch {
            return false
        }
    }
}
