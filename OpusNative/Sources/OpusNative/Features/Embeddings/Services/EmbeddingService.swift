import Foundation

/// Service responsible for interacting with the Ollama Embedding API.
/// This service is independent of the Chat module but reuses the shared Keychain configuration for the base URL.
final class EmbeddingService: Sendable {
    static let shared = EmbeddingService()
    
    private let session = URLSession.shared
    
    /// Get the configured Ollama base URL (defaults to localhost)
    /// Reuses the same key as the main app to ensure consistency.
    private var baseURL: String {
        let saved = KeychainService.shared.load(key: KeychainService.ollamaBaseURL)
        if let url = saved, !url.isEmpty {
            return url.hasSuffix("/") ? String(url.dropLast()) : url
        }
        return "http://localhost:11434"
    }
    
    // MARK: - API Models
    
    struct EmbeddingResponse: Decodable {
        let embedding: [Double]
    }
    
    struct EmbeddingRequest: Encodable {
        let model: String
        let prompt: String
    }
    
    // MARK: - Public API
    
    /// Fetches the list of available models from Ollama, filtering for embedding-capable models if possible.
    /// Note regarding Ollama: /api/tags returns all models. We will try to heuristic filter or return all.
    /// For a robust "Embedding Intelligence" dashboard, we might want to let the user select any model,
    /// but ideally we highlight those with "embed" in the name.
    func fetchEmbeddingModels() async throws -> [String] {
        let endpoint = "\(baseURL)/api/tags"
        guard let url = URL(string: endpoint) else {
            throw EmbeddingError.invalidURL(endpoint)
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw EmbeddingError.serverError("Failed to fetch models")
        }
        
        // Decode logic similar to OllamaProvider but simplified for this context
        struct OllamaModelList: Decodable {
            struct Model: Decodable {
                let name: String
            }
            let models: [Model]
        }
        
        let list = try JSONDecoder().decode(OllamaModelList.self, from: data)
        
        // Heuristic: Prefer models with "embed" or "nomic" or "bert" in name, but return all for flexibility
        // or let the UI handle the sorting.
        // For now, return all model names.
        return list.models.map { $0.name }
    }
    
    /// Generates an embedding vector for the given text using the specified model.
    func generateEmbedding(prompt: String, model: String) async throws -> [Double] {
        let endpoint = "\(baseURL)/api/embeddings"
        guard let url = URL(string: endpoint) else {
            throw EmbeddingError.invalidURL(endpoint)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30 // Embeddings can be slow for large texts
        
        let body = EmbeddingRequest(model: model, prompt: prompt)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmbeddingError.networkError("Invalid response")
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw EmbeddingError.serverError(errorMsg)
        }
        
        let result = try JSONDecoder().decode(EmbeddingResponse.self, from: data)
        return result.embedding
    }
}

enum EmbeddingError: Error, LocalizedError {
    case invalidURL(String)
    case networkError(String)
    case serverError(String)
    case decodingError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL(let url): return "Invalid URL: \(url)"
        case .networkError(let msg): return "Network Error: \(msg)"
        case .serverError(let msg): return "Ollama Server Error: \(msg)"
        case .decodingError(let msg): return "Failed to decode response: \(msg)"
        }
    }
}
