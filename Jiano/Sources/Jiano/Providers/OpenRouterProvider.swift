import Foundation

// MARK: - OpenRouter Provider

/// Connects to OpenRouter.ai API to access hundreds of models.
/// Inherits from OpenAICompatibleProvider since OpenRouter exposes an OpenAI-compatible endpoint.
final class OpenRouterProvider: OpenAICompatibleProvider, @unchecked Sendable {
    
    private let keychain: KeychainService
    
    init(keychain: KeychainService) {
        self.keychain = keychain
        super.init(
            id: "openrouter",
            name: "OpenRouter",
            baseURL: "https://openrouter.ai/api/v1",
            apiKey: "", // will be fetched dynamically
            defaultModel: "anthropic/claude-3.5-sonnet", // Sensible default
            availableModels: [] // Populated dynamically or fetched from registry
        )
    }
    
    override func customHeaders() -> [String : String] {
        return [
            "HTTP-Referer": "https://github.com/Rudra-iitg/OpusNative",
            "X-Title": "OpusNative"
        ]
    }
    
    override func getAPIKey() throws -> String {
        guard let key = keychain.load(key: KeychainService.openRouterAPIKey), !key.isEmpty else {
            throw AIProviderError.missingAPIKey(provider: displayName)
        }
        return key
    }
    
    // MARK: - Fetch Models
    
    struct OpenRouterModelList: Decodable {
        struct ORModel: Decodable {
            let id: String
            let name: String
            let context_length: Int
            let pricing: Pricing
            
            struct Pricing: Decodable {
                let prompt: String
                let completion: String
            }
        }
        let data: [ORModel]
    }
    
    /// Fetches all available models from OpenRouter API
    func fetchAvailableModels() async throws -> [ModelInfo] {
        guard let url = URL(string: "https://openrouter.ai/api/v1/models") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoded = try JSONDecoder().decode(OpenRouterModelList.self, from: data)
        return decoded.data.map { orModel in
            // Pricing is provided as string representation of cost per token. 
            // We need to multiply by 1_000_000 to get cost per 1M tokens.
            let promptPrice = (Double(orModel.pricing.prompt) ?? 0.0) * 1_000_000
            let completionPrice = (Double(orModel.pricing.completion) ?? 0.0) * 1_000_000
            
            // Note: Capabilities extraction from OpenRouter requires more deeper parsing of `architecture` block
            // Here we provide sensible defaults, though a real implementation might look for "vision" key if it exists in JSON
            return ModelInfo(
                id: orModel.id,
                displayName: orModel.name,
                provider: "OpenRouter",
                contextWindow: orModel.context_length,
                inputCostPer1MTokens: promptPrice,
                outputCostPer1MTokens: completionPrice,
                capabilities: [.toolUse] // Baseline
            )
        }
    }
}
