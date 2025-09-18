import Foundation
import CoreLocation
import Combine

class LocationAPIManager: ObservableObject {
    static let shared = LocationAPIManager()
    
    @Published var sharedLocations: [SharedLocation] = []
    @Published var isUpdatingLocation = false
    @Published var error: String?
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    private var locationUpdateTimer: Timer?
    
    private init() {
        startLocationSharingUpdates()
    }
    
    // MARK: - Location Sharing
    
    func updateCurrentLocation(_ location: CLLocation) {
        guard !isUpdatingLocation else { return }
        
        isUpdatingLocation = true
        error = nil
        
        apiService.updateLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            accuracy: location.horizontalAccuracy
        )
        .sink(
            receiveCompletion: { [weak self] completion in
                DispatchQueue.main.async {
                    self?.isUpdatingLocation = false
                    if case .failure(let error) = completion {
                        self?.error = error.localizedDescription
                    }
                }
            },
            receiveValue: { [weak self] _ in
                DispatchQueue.main.async {
                    self?.isUpdatingLocation = false
                }
            }
        )
        .store(in: &cancellables)
    }
    
    func fetchSharedLocations() {
        apiService.getSharedLocations()
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        DispatchQueue.main.async {
                            self?.error = error.localizedDescription
                        }
                    }
                },
                receiveValue: { [weak self] locations in
                    DispatchQueue.main.async {
                        self?.sharedLocations = locations.map { response in
                            SharedLocation(
                                id: response.userId,
                                name: response.name,
                                coordinate: CLLocationCoordinate2D(
                                    latitude: response.latitude,
                                    longitude: response.longitude
                                ),
                                lastUpdated: response.lastUpdated
                            )
                        }
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func enableLocationSharing(with userIds: [String]) {
        apiService.enableLocationSharing(userIds: userIds)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        DispatchQueue.main.async {
                            self?.error = error.localizedDescription
                        }
                    }
                },
                receiveValue: { _ in
                    // Location sharing enabled successfully
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Route Management
    
    func saveRoute(name: String, description: String?, points: [LocationPoint]) -> AnyPublisher<APIRoute, Error> {
        guard !points.isEmpty else {
            return Fail(error: LocationAPIError.noLocationPoints)
                .eraseToAnyPublisher()
        }
        
        let startTime = points.first?.timestamp ?? Date()
        let endTime = points.last?.timestamp ?? Date()
        
        return apiService.createRoute(
            name: name,
            description: description,
            locations: points,
            startTime: startTime,
            endTime: endTime
        )
    }
    
    func fetchRoutes(page: Int = 1, limit: Int = 10) -> AnyPublisher<[Route], Error> {
        return apiService.getRoutes(page: page, limit: limit)
            .map { response in
                response.routes.map { apiRoute in
                    let points = apiRoute.locations?.map { apiPoint in
                        LocationPoint(
                            timestamp: apiPoint.timestamp,
                            coordinate: CLLocationCoordinate2D(
                                latitude: apiPoint.latitude,
                                longitude: apiPoint.longitude
                            ),
                            accuracy: apiPoint.accuracy ?? 0
                        )
                    } ?? []
                    
                    return Route(
                        id: UUID(uuidString: apiRoute.id) ?? UUID(),
                        date: apiRoute.startTime,
                        points: points,
                        name: apiRoute.name
                    )
                }
            }
            .eraseToAnyPublisher()
    }
    
    func deleteRoute(routeId: String) -> AnyPublisher<Void, Error> {
        return apiService.deleteRoute(routeId: routeId)
    }
    
    // MARK: - Friends Management
    
    func searchUser(by email: String) -> AnyPublisher<UserProfile, Error> {
        return apiService.searchUser(email: email)
            .map { apiUser in
                UserProfile(
                    id: apiUser.id,
                    name: apiUser.name,
                    email: apiUser.email
                )
            }
            .eraseToAnyPublisher()
    }
    
    func addFriend(friendId: String) -> AnyPublisher<UserProfile, Error> {
        return apiService.addFriend(friendId: friendId)
            .map { apiUser in
                UserProfile(
                    id: apiUser.id,
                    name: apiUser.name,
                    email: apiUser.email
                )
            }
            .eraseToAnyPublisher()
    }
    
    func removeFriend(friendId: String) -> AnyPublisher<Void, Error> {
        return apiService.removeFriend(friendId: friendId)
    }
    
    func getFriends() -> AnyPublisher<[UserProfile], Error> {
        return apiService.getFriends()
            .map { apiUsers in
                apiUsers.map { apiUser in
                    UserProfile(
                        id: apiUser.id,
                        name: apiUser.name,
                        email: apiUser.email
                    )
                }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    
    private func startLocationSharingUpdates() {
        // Fetch shared locations every 30 seconds
        locationUpdateTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.fetchSharedLocations()
        }
    }
    
    deinit {
        locationUpdateTimer?.invalidate()
    }
}

// MARK: - Error Types

enum LocationAPIError: LocalizedError {
    case noLocationPoints
    case invalidRoute
    
    var errorDescription: String? {
        switch self {
        case .noLocationPoints:
            return "No location points available to save route"
        case .invalidRoute:
            return "Invalid route data"
        }
    }
}

// MARK: - Extensions

extension LocationAPIManager {
    func convertLocationPointsToAPIFormat(_ points: [LocationPoint]) -> [APILocationPoint] {
        return points.map { point in
            APILocationPoint(
                latitude: point.coordinate.latitude,
                longitude: point.coordinate.longitude,
                timestamp: point.timestamp,
                altitude: nil,
                speed: nil,
                accuracy: point.accuracy
            )
        }
    }
}