import Foundation

// MARK: - LM Studio Provider

/// Connects to a local LM Studio server running an OpenAI-compatible endpoint.
final class LMStudioProvider: OpenAICompatibleProvider, @unchecked Sendable {
    
    init() {
        let storedBaseURL = UserDefaults.standard.string(forKey: "lmstudioBaseURL") ?? "http://localhost:1234"
        
        super.init(
            id: "lmstudio",
            name: "LM Studio",
            baseURL: storedBaseURL,
            apiKey: "lm-studio", // No real API key needed
            defaultModel: "local-model",
            availableModels: [] // Fetched dynamically
        )
    }
    
    override func getAPIKey() throws -> String {
        return "lm-studio"
    }
    
    // MARK: - Dynamic Fetching and Status
    
    struct LMStudioModelList: Decodable {
        struct ModelObj: Decodable {
            let id: String
        }
        let data: [ModelObj]
    }
    
    /// Contacts LM Studio to see what models are loaded in memory
    func fetchAvailableModels() async throws -> [String] {
        var base = baseURL
        if base.hasSuffix("/") {
            base.removeLast()
        }
        if !base.hasSuffix("/v1") {
            base += "/v1"
        }
        
        let urlString = base + "/models"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 3.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoded = try JSONDecoder().decode(LMStudioModelList.self, from: data)
        return decoded.data.map { $0.id }
    }
    
    /// Tests if the server is available within a 2-second timeout
    func isServerRunning() async -> Bool {
        do {
            // Using a simple fetch models as health check for LM Studio
            _ = try await fetchAvailableModels()
            return true
        } catch {
            return false
        }
    }
}
