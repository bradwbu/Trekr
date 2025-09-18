import Foundation
import Combine

class AuthManager: ObservableObject {
    @Published var currentUser: UserProfile?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    
    init() {
        // Check for saved credentials and validate token
        checkForSavedUser()
    }
    
    // MARK: - Public Methods
    
    func signIn(email: String, password: String) {
        isLoading = true
        error = nil
        
        apiService.signIn(email: email, password: password)
            .sink(
                receiveCompletion: { [weak self] completion in
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        if case .failure(let error) = completion {
                            self?.error = error.localizedDescription
                        }
                    }
                },
                receiveValue: { [weak self] authResponse in
                    DispatchQueue.main.async {
                        self?.handleSuccessfulAuth(authResponse)
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func signUp(name: String, email: String, password: String) {
        isLoading = true
        error = nil
        
        apiService.signUp(name: name, email: email, password: password)
            .sink(
                receiveCompletion: { [weak self] completion in
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        if case .failure(let error) = completion {
                            self?.error = error.localizedDescription
                        }
                    }
                },
                receiveValue: { [weak self] authResponse in
                    DispatchQueue.main.async {
                        self?.handleSuccessfulAuth(authResponse)
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func signOut() {
        apiService.signOut()
        currentUser = nil
        isAuthenticated = false
        clearSavedCredentials()
    }
    
    func updateProfile(name: String, email: String) {
        guard currentUser != nil else { return }
        
        isLoading = true
        error = nil
        
        apiService.updateProfile(name: name, email: email)
            .sink(
                receiveCompletion: { [weak self] completion in
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        if case .failure(let error) = completion {
                            self?.error = error.localizedDescription
                        }
                    }
                },
                receiveValue: { [weak self] apiUser in
                    DispatchQueue.main.async {
                        self?.currentUser = self?.convertAPIUserToUserProfile(apiUser)
                        self?.saveUserCredentials()
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Private Methods
    
    private func handleSuccessfulAuth(_ authResponse: AuthResponse) {
        self.currentUser = convertAPIUserToUserProfile(authResponse.user)
        self.isAuthenticated = true
        self.saveUserCredentials()
    }
    
    private func convertAPIUserToUserProfile(_ apiUser: APIUser) -> UserProfile {
        let shareLocationWith = apiUser.shareLocationWith?.map { $0.id } ?? []
        return UserProfile(
            id: apiUser.id,
            name: apiUser.name,
            email: apiUser.email,
            shareLocationWith: shareLocationWith
        )
    }
    
    private func checkForSavedUser() {
        // Check if we have a saved auth token
        if UserDefaults.standard.string(forKey: "auth_token") != nil {
            // Try to get current user from API to validate token
            apiService.getCurrentUser()
                .sink(
                    receiveCompletion: { [weak self] completion in
                        if case .failure(_) = completion {
                            // Token is invalid, clear it
                            self?.clearSavedCredentials()
                        }
                    },
                    receiveValue: { [weak self] apiUser in
                        // Token is valid, set user as authenticated
                        DispatchQueue.main.async {
                            self?.currentUser = self?.convertAPIUserToUserProfile(apiUser)
                            self?.isAuthenticated = true
                        }
                    }
                )
                .store(in: &cancellables)
        }
    }
    
    private func saveUserCredentials() {
        // Token is already saved by APIService
        // We could save additional user data here if needed
        if let userData = try? JSONEncoder().encode(currentUser) {
            UserDefaults.standard.set(userData, forKey: "saved_user")
        }
    }
    
    private func clearSavedCredentials() {
        UserDefaults.standard.removeObject(forKey: "auth_token")
        UserDefaults.standard.removeObject(forKey: "saved_user")
    }
}