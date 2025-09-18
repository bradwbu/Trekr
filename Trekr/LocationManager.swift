import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    private let significantLocationManager = CLLocationManager()
    
    @Published var lastLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    // For background tracking
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    // For publishing location updates to subscribers
    let locationPublisher = PassthroughSubject<LocationPoint, Never>()
    
    override init() {
        super.init()
        
        // Configure main location manager for foreground use
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.allowsBackgroundLocationUpdates = true
        
        // Configure significant location manager for background use
        significantLocationManager.delegate = self
        significantLocationManager.distanceFilter = 100 // Significant changes (100m)
        significantLocationManager.pausesLocationUpdatesAutomatically = false
        significantLocationManager.allowsBackgroundLocationUpdates = true
        
        // Check current authorization status
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }
    
    func startUpdatingLocation() {
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            locationManager.startUpdatingLocation()
            significantLocationManager.startMonitoringSignificantLocationChanges()
            registerBackgroundTask()
        } else {
            requestAuthorization()
        }
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
        significantLocationManager.stopMonitoringSignificantLocationChanges()
        endBackgroundTask()
    }
    
    private func registerBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    private func processLocation(_ location: CLLocation) {
        lastLocation = location
        
        // Create a location point from the CLLocation
        let locationPoint = LocationPoint(
            timestamp: location.timestamp,
            coordinate: location.coordinate,
            accuracy: location.horizontalAccuracy
        )
        
        // Publish the location point for subscribers
        locationPublisher.send(locationPoint)
        
        // Send location to backend API if user is authenticated
        if AuthManager.shared.isAuthenticated {
            LocationAPIManager.shared.updateCurrentLocation(location)
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Filter out inaccurate locations
        guard location.horizontalAccuracy >= 0 && location.horizontalAccuracy < 100 else { return }
        
        // Process the location
        processLocation(location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
}