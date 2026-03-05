import Foundation

// MARK: - Saved Endpoint Model

/// User-configured custom OpenAI-compatible endpoint
struct SavedEndpoint: Codable, Sendable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var baseURL: String
    var apiKey: String // Only holds a reference identifier or raw string depending on security needs, here we can store raw strings for local networks as requested
    var modelName: String
    var customHeaders: [String: String]

    /// Validates if the base URL has a proper http or https prefix
    var isValidBaseURL: Bool {
        return baseURL.hasPrefix("http://") || baseURL.hasPrefix("https://")
    }
}

// MARK: - Manager for Saved Endpoints

@Observable
final class GenericEndpointManager {
    static let shared = GenericEndpointManager()
    
    var endpoints: [SavedEndpoint] = [] {
        didSet {
            save()
        }
    }
    
    private let storageKey = "generic_saved_endpoints"
    
    init() {
        load()
    }
    
    func addOrUpdate(_ endpoint: SavedEndpoint) {
        if let idx = endpoints.firstIndex(where: { $0.id == endpoint.id }) {
            endpoints[idx] = endpoint
        } else {
            endpoints.append(endpoint)
        }
    }
    
    func delete(_ id: UUID) {
        endpoints.removeAll { $0.id == id }
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(endpoints) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([SavedEndpoint].self, from: data) {
            self.endpoints = saved
        } else {
            // Default placeholder if needed
            self.endpoints = []
        }
    }
}

// MARK: - Generic OpenAI Compatible Provider

/// Connects to any "Bring Your Own Endpoint" that is OpenAI compatible
final class GenericOpenAICompatibleProvider: OpenAICompatibleProvider, @unchecked Sendable {
    
    let endpoint: SavedEndpoint
    
    init(endpoint: SavedEndpoint) {
        self.endpoint = endpoint
        super.init(
            id: "generic-\(endpoint.id.uuidString)",
            name: endpoint.name.isEmpty ? "Custom Endpoint" : endpoint.name,
            baseURL: endpoint.baseURL,
            apiKey: endpoint.apiKey,
            defaultModel: endpoint.modelName,
            availableModels: [endpoint.modelName]
        )
    }
    
    override func customHeaders() -> [String : String] {
        return endpoint.customHeaders
    }
    
    // API key is stored securely/in memory inside endpoint data (usually for localhost/BYOE)
    override func getAPIKey() throws -> String {
        return apiKey
    }
    
    // MARK: - Test Connection
    
    /// Tests if the endpoint is reachable
    func testConnection() async -> Bool {
        guard endpoint.isValidBaseURL else { return false }
        
        var base = baseURL
        if base.hasSuffix("/") {
            base.removeLast()
        }
        
        // Try /health first, fallback to /v1/models
        let urlsToTry = [
            base + "/health",
            base.hasSuffix("/v1") ? base + "/models" : base + "/v1/models",
            base
        ]
        
        for urlString in urlsToTry {
            guard let url = URL(string: urlString) else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 2.0 // Fast timeout
            
            for (k, v) in endpoint.customHeaders {
                request.setValue(v, forHTTPHeaderField: k)
            }
            if !endpoint.apiKey.isEmpty {
                request.setValue("Bearer \(endpoint.apiKey)", forHTTPHeaderField: "Authorization")
            }
            
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                    return true
                }
            } catch {
                continue
            }
        }
        return false
    }
}
