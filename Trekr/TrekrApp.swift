import SwiftUI

@main
struct TrekrApp: App {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var locationDataStore = LocationDataStore()
    @StateObject private var locationSharingManager = LocationSharingManager()
    @StateObject private var authManager = AuthManager()
    @StateObject private var locationAPIManager = LocationAPIManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .environmentObject(locationDataStore)
                .environmentObject(locationSharingManager)
                .environmentObject(authManager)
                .environmentObject(locationAPIManager)
        }
    }
}