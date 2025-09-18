import Foundation
import CoreLocation
import Combine

// MARK: - API Response Models
struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let message: String?
    let data: T?
    let errors: [APIError]?
}

struct APIError: Codable {
    let field: String?
    let message: String
}

struct AuthResponse: Codable {
    let user: APIUser
    let token: String
}

struct APIUser: Codable {
    let id: String
    let name: String
    let email: String
    let locationSharingEnabled: Bool
    let shareLocationWith: [APIUser]?
    let preferences: UserPreferences?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, email, locationSharingEnabled, shareLocationWith, preferences
    }
}

struct UserPreferences: Codable {
    let trackingAccuracy: String
    let backgroundTracking: Bool
    let dataRetentionDays: Int
}

struct APIRoute: Codable {
    let id: String
    let name: String
    let description: String?
    let startTime: Date
    let endTime: Date
    let totalDistance: Double
    let totalDuration: Double
    let locations: [APILocationPoint]?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, description, startTime, endTime, totalDistance, totalDuration, locations
    }
}

struct APILocationPoint: Codable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let altitude: Double?
    let speed: Double?
    let accuracy: Double?
}

// MARK: - API Service
class APIService: ObservableObject {
    static let shared = APIService()
    
    private let baseURL = "https://yondr.me/api"
    private let session = URLSession.shared
    private var authToken: String?
    
    // MARK: - Initialization
    private init() {
        loadAuthToken()
    }
    
    // MARK: - Authentication Methods
    
    func signIn(email: String, password: String) -> AnyPublisher<AuthResponse, Error> {
        let endpoint = "/auth/login"
        let body = [
            "email": email,
            "password": password
        ]
        
        return makeRequest<AuthResponse>(
            endpoint: endpoint,
            method: "POST",
            body: body,
            requiresAuth: false
        )
        .handleEvents(receiveOutput: { [weak self] response in
            self?.setAuthToken(response.token)
        })
        .eraseToAnyPublisher()
    }
    
    func signUp(name: String, email: String, password: String) -> AnyPublisher<AuthResponse, Error> {
        let endpoint = "/auth/register"
        let body = [
            "name": name,
            "email": email,
            "password": password
        ]
        
        return makeRequest<AuthResponse>(
            endpoint: endpoint,
            method: "POST",
            body: body,
            requiresAuth: false
        )
        .handleEvents(receiveOutput: { [weak self] response in
            self?.setAuthToken(response.token)
        })
        .eraseToAnyPublisher()
    }
    
    func refreshToken() -> AnyPublisher<AuthResponse, Error> {
        let endpoint = "/auth/refresh"
        
        return makeRequest<AuthResponse>(
            endpoint: endpoint,
            method: "POST",
            requiresAuth: true
        )
        .handleEvents(receiveOutput: { [weak self] response in
            self?.setAuthToken(response.token)
        })
        .eraseToAnyPublisher()
    }
    
    func signOut() {
        clearAuthToken()
    }
    
    // MARK: - User Profile Methods
    
    func getCurrentUser() -> AnyPublisher<APIUser, Error> {
        return makeRequest<APIUser>(
            endpoint: "/users/profile",
            method: "GET",
            requiresAuth: true
        )
    }
    
    func updateProfile(name: String, email: String) -> AnyPublisher<APIUser, Error> {
        let body = [
            "name": name,
            "email": email
        ]
        
        return makeRequest<APIUser>(
            endpoint: "/users/profile",
            method: "PUT",
            body: body,
            requiresAuth: true
        )
    }
    
    func updatePreferences(trackingAccuracy: String, backgroundTracking: Bool, dataRetentionDays: Int) -> AnyPublisher<UserPreferences, Error> {
        let body = [
            "trackingAccuracy": trackingAccuracy,
            "backgroundTracking": backgroundTracking,
            "dataRetentionDays": dataRetentionDays
        ] as [String : Any]
        
        return makeRequest<UserPreferences>(
            endpoint: "/users/preferences",
            method: "PUT",
            body: body,
            requiresAuth: true
        )
    }
    
    // MARK: - Friends Management
    
    func searchUser(email: String) -> AnyPublisher<APIUser, Error> {
        let endpoint = "/users/search?email=\(email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        return makeRequest<APIUser>(
            endpoint: endpoint,
            method: "GET",
            requiresAuth: true
        )
    }
    
    func addFriend(friendId: String) -> AnyPublisher<APIUser, Error> {
        let body = ["friendId": friendId]
        
        return makeRequest<APIUser>(
            endpoint: "/users/friends/add",
            method: "POST",
            body: body,
            requiresAuth: true
        )
    }
    
    func removeFriend(friendId: String) -> AnyPublisher<Void, Error> {
        return makeRequest<EmptyResponse>(
            endpoint: "/users/friends/\(friendId)",
            method: "DELETE",
            requiresAuth: true
        )
        .map { _ in () }
        .eraseToAnyPublisher()
    }
    
    func getFriends() -> AnyPublisher<[APIUser], Error> {
        return makeRequest<[APIUser]>(
            endpoint: "/users/friends",
            method: "GET",
            requiresAuth: true
        )
    }
    
    // MARK: - Location Methods
    
    func updateLocation(latitude: Double, longitude: Double, accuracy: Double) -> AnyPublisher<Void, Error> {
        let body = [
            "latitude": latitude,
            "longitude": longitude,
            "accuracy": accuracy,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ] as [String : Any]
        
        return makeRequest<EmptyResponse>(
            endpoint: "/locations/update",
            method: "POST",
            body: body,
            requiresAuth: true
        )
        .map { _ in () }
        .eraseToAnyPublisher()
    }
    
    func getSharedLocations() -> AnyPublisher<[SharedLocationResponse], Error> {
        return makeRequest<[SharedLocationResponse]>(
            endpoint: "/locations/shared",
            method: "GET",
            requiresAuth: true
        )
    }
    
    func enableLocationSharing(userIds: [String]) -> AnyPublisher<Void, Error> {
        let body = ["userIds": userIds]
        
        return makeRequest<EmptyResponse>(
            endpoint: "/locations/share",
            method: "POST",
            body: body,
            requiresAuth: true
        )
        .map { _ in () }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Route Methods
    
    func createRoute(name: String, description: String?, locations: [LocationPoint], startTime: Date, endTime: Date) -> AnyPublisher<APIRoute, Error> {
        let apiLocations = locations.map { point in
            APILocationPoint(
                latitude: point.coordinate.latitude,
                longitude: point.coordinate.longitude,
                timestamp: point.timestamp,
                altitude: nil,
                speed: nil,
                accuracy: point.accuracy
            )
        }
        
        let body = [
            "name": name,
            "description": description ?? "",
            "locations": apiLocations,
            "startTime": ISO8601DateFormatter().string(from: startTime),
            "endTime": ISO8601DateFormatter().string(from: endTime)
        ] as [String : Any]
        
        return makeRequest<APIRoute>(
            endpoint: "/routes",
            method: "POST",
            body: body,
            requiresAuth: true
        )
    }
    
    func getRoutes(page: Int = 1, limit: Int = 10) -> AnyPublisher<RoutesResponse, Error> {
        let endpoint = "/routes?page=\(page)&limit=\(limit)"
        
        return makeRequest<RoutesResponse>(
            endpoint: endpoint,
            method: "GET",
            requiresAuth: true
        )
    }
    
    func getRoute(routeId: String) -> AnyPublisher<APIRoute, Error> {
        return makeRequest<APIRoute>(
            endpoint: "/routes/\(routeId)",
            method: "GET",
            requiresAuth: true
        )
    }
    
    func deleteRoute(routeId: String) -> AnyPublisher<Void, Error> {
        return makeRequest<EmptyResponse>(
            endpoint: "/routes/\(routeId)",
            method: "DELETE",
            requiresAuth: true
        )
        .map { _ in () }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Private Helper Methods
    
    private func makeRequest<T: Codable>(
        endpoint: String,
        method: String,
        body: [String: Any]? = nil,
        requiresAuth: Bool = true
    ) -> AnyPublisher<T, Error> {
        
        guard let url = URL(string: baseURL + endpoint) else {
            return Fail(error: APIServiceError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authorization header if required
        if requiresAuth {
            guard let token = authToken else {
                return Fail(error: APIServiceError.noAuthToken)
                    .eraseToAnyPublisher()
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add request body if provided
        if let body = body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                return Fail(error: APIServiceError.encodingError(error))
                    .eraseToAnyPublisher()
            }
        }
        
        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: APIResponse<T>.self, decoder: JSONDecoder.apiDecoder)
            .tryMap { response in
                if response.success, let data = response.data {
                    return data
                } else {
                    let errorMessage = response.message ?? "Unknown error"
                    throw APIServiceError.serverError(errorMessage)
                }
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Token Management
    
    private func setAuthToken(_ token: String) {
        self.authToken = token
        UserDefaults.standard.set(token, forKey: "auth_token")
    }
    
    private func loadAuthToken() {
        self.authToken = UserDefaults.standard.string(forKey: "auth_token")
    }
    
    private func clearAuthToken() {
        self.authToken = nil
        UserDefaults.standard.removeObject(forKey: "auth_token")
    }
}

// MARK: - Supporting Types

struct EmptyResponse: Codable {}

struct SharedLocationResponse: Codable {
    let userId: String
    let name: String
    let latitude: Double
    let longitude: Double
    let lastUpdated: Date
}

struct RoutesResponse: Codable {
    let routes: [APIRoute]
    let pagination: PaginationInfo
}

struct PaginationInfo: Codable {
    let page: Int
    let limit: Int
    let total: Int
    let pages: Int
}

// MARK: - Error Types

enum APIServiceError: LocalizedError {
    case invalidURL
    case noAuthToken
    case encodingError(Error)
    case serverError(String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noAuthToken:
            return "No authentication token available"
        case .encodingError(let error):
            return "Encoding error: \(error.localizedDescription)"
        case .serverError(let message):
            return message
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - JSON Decoder Extension

extension JSONDecoder {
    static let apiDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}