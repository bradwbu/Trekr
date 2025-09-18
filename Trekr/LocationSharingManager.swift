import Foundation
import CoreLocation
import Combine

class LocationSharingManager: ObservableObject {
    @Published var sharedLocations: [SharedLocation] = []
    @Published var isSharing: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?
    private let locationAPIManager = LocationAPIManager.shared
    
    init() {
        // Use real API instead of mock data
        setupLocationSharing()
        
        // Set up a timer to periodically refresh friend locations
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refreshFriendLocations()
        }
    }
    
    func startSharing() {
        isSharing = true
        // Location sharing is automatically handled by LocationManager -> LocationAPIManager
    }
    
    func stopSharing() {
        isSharing = false
        // Could add API call to disable location sharing if needed
    }
    
    func shareLocationWith(friends: [String]) {
        locationAPIManager.enableLocationSharing(with: friends)
    }
    
    func addFriend(email: String, completion: @escaping (Result<UserProfile, Error>) -> Void) {
        locationAPIManager.searchUser(by: email)
            .flatMap { user in
                self.locationAPIManager.addFriend(friendId: user.id)
            }
            .sink(
                receiveCompletion: { completionResult in
                    if case .failure(let error) = completionResult {
                        completion(.failure(error))
                    }
                },
                receiveValue: { user in
                    completion(.success(user))
                }
            )
            .store(in: &cancellables)
    }
    
    func removeFriend(friendId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        locationAPIManager.removeFriend(friendId: friendId)
            .sink(
                receiveCompletion: { completionResult in
                    switch completionResult {
                    case .finished:
                        completion(.success(()))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Private Methods
    
    private func setupLocationSharing() {
        // Subscribe to shared locations from API
        locationAPIManager.$sharedLocations
            .assign(to: \.sharedLocations, on: self)
            .store(in: &cancellables)
        
        // Initial fetch
        refreshFriendLocations()
    }
    
    private func refreshFriendLocations() {
        locationAPIManager.fetchSharedLocations()
    }
    
    deinit {
        timer?.invalidate()
    }
}