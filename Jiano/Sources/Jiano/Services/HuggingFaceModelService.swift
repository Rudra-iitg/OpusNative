import Foundation

// MARK: - HFModel

struct HFModel: Identifiable, Codable, Hashable {
    let id: String
    let modelId: String
    let pipelineTag: String?
    let downloads: Int?
    let likes: Int?
    let trendingScore: Double?
    let tags: [String]
    let `private`: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case modelId
        case pipelineTag = "pipeline_tag"
        case downloads
        case likes
        case trendingScore = "trending_score"
        case tags
        case `private`
    }
    
    // Computed Properties
    
    var displayName: String {
        return modelId.components(separatedBy: "/").last ?? modelId
    }
    
    var organization: String {
        let components = modelId.components(separatedBy: "/")
        return components.count > 1 ? components.first! : ""
    }
    
    var isConversational: Bool {
        return tags.contains("conversational")
    }
    
    var formattedDownloads: String {
        guard let d = downloads else { return "0" }
        if d >= 1_000_000 {
            return String(format: "%.1fM", Double(d) / 1_000_000.0)
        } else if d >= 1_000 {
            return String(format: "%.1fK", Double(d) / 1_000.0)
        }
        return "\(d)"
    }
    
    var formattedLikes: String {
        guard let l = likes else { return "0" }
        if l >= 1_000_000 {
            return String(format: "%.1fM", Double(l) / 1_000_000.0)
        } else if l >= 1_000 {
            return String(format: "%.1fK", Double(l) / 1_000.0)
        }
        return "\(l)"
    }
}

// MARK: - HuggingFaceModelService

enum HuggingFaceAPIError: Error {
    case invalidURL
    case authenticationFailed
    case networkError(statusCode: Int)
}

/// Service to handle discovery, search, and validation of HuggingFace models.
actor HuggingFaceModelService {
    static let shared = HuggingFaceModelService()
    
    private let baseURL = "https://huggingface.co/api/models"
    
    // In-memory caches
    private var trendingCache: [HFModel] = []
    private var popularCache: [HFModel] = []
    private var searchCaches: [String: [HFModel]] = [:]
    
    // Cache timestamps
    private var trendingCacheTimestamp: Date?
    private var popularCacheTimestamp: Date?
    private var searchCacheTimestamps: [String: Date] = [:]
    
    private let cacheTTL: TimeInterval = 600 // 10 minutes
    
    /// Internal generic fetch method
    private func fetch(queryItems: [URLQueryItem], apiKey: String) async throws -> [HFModel] {
        var components = URLComponents(string: baseURL)!
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw HuggingFaceAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw HuggingFaceAPIError.authenticationFailed
            }
            if !(200...299).contains(httpResponse.statusCode) {
                throw HuggingFaceAPIError.networkError(statusCode: httpResponse.statusCode)
            }
        }
        
        return try JSONDecoder().decode([HFModel].self, from: data)
    }
    
    /// Fetch trending text-generation models currently warm on inference servers
    func fetchTrendingModels(apiKey: String) async throws -> [HFModel] {
        if let timestamp = trendingCacheTimestamp, Date().timeIntervalSince(timestamp) < cacheTTL, !trendingCache.isEmpty {
            return trendingCache
        }
        
        let queryItems = [
            URLQueryItem(name: "pipeline_tag", value: "text-generation"),
            URLQueryItem(name: "inference", value: "warm"),
            URLQueryItem(name: "sort", value: "trending"),
            URLQueryItem(name: "limit", value: "50")
        ]
        
        let models = try await fetch(queryItems: queryItems, apiKey: apiKey)
        trendingCache = models
        trendingCacheTimestamp = Date()
        return models
    }
    
    /// Fetch most downloaded text-generation models currently warm on inference servers
    func fetchPopularModels(apiKey: String) async throws -> [HFModel] {
        if let timestamp = popularCacheTimestamp, Date().timeIntervalSince(timestamp) < cacheTTL, !popularCache.isEmpty {
            return popularCache
        }
        
        let queryItems = [
            URLQueryItem(name: "pipeline_tag", value: "text-generation"),
            URLQueryItem(name: "inference", value: "warm"),
            URLQueryItem(name: "sort", value: "downloads"),
            URLQueryItem(name: "limit", value: "50")
        ]
        
        let models = try await fetch(queryItems: queryItems, apiKey: apiKey)
        popularCache = models
        popularCacheTimestamp = Date()
        return models
    }
    
    /// Search for text-generation models (does not require them to be warm)
    func searchModels(query: String, apiKey: String) async throws -> [HFModel] {
        if let timestamp = searchCacheTimestamps[query], Date().timeIntervalSince(timestamp) < cacheTTL, let cached = searchCaches[query] {
            return cached
        }
        
        let queryItems = [
            URLQueryItem(name: "search", value: query),
            URLQueryItem(name: "pipeline_tag", value: "text-generation"),
            URLQueryItem(name: "limit", value: "30")
        ]
        
        let models = try await fetch(queryItems: queryItems, apiKey: apiKey)
        searchCaches[query] = models
        searchCacheTimestamps[query] = Date()
        return models
    }
    
    /// Validate if a model ID exists and is accessible
    func validateModel(modelId: String, apiKey: String) async throws -> Bool {
        guard let encodedId = modelId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(baseURL)/\(encodedId)") else {
            throw HuggingFaceAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 200 {
                return true
            } else if httpResponse.statusCode == 404 {
                return false
            } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw HuggingFaceAPIError.authenticationFailed
            }
        }
        return false
    }
}
