import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var locationDataStore: LocationDataStore
    @EnvironmentObject private var locationSharingManager: LocationSharingManager
    
    @State private var selectedTab = 0
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                TabView(selection: $selectedTab) {
                    MapView()
                        .tabItem {
                            Label("Map", systemImage: "map")
                        }
                        .tag(0)
                    
                    UserProfileView()
                        .tabItem {
                            Label("Profile", systemImage: "person")
                        }
                        .tag(1)
                }
                .onAppear {
                    // Start location tracking when the app is opened
                    locationManager.startTracking()
                }
                .onDisappear {
                    // Stop location tracking when the app is closed
                    locationManager.stopTracking()
                }
            } else {
                LoginView()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthManager())
            .environmentObject(LocationManager())
            .environmentObject(LocationDataStore())
            .environmentObject(LocationSharingManager())
    }
}