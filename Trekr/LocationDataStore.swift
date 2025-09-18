import Foundation
import CoreLocation
import Combine

class LocationDataStore: ObservableObject {
    @Published var routes: [Route] = []
    
    private var cancellables = Set<AnyCancellable>()
    private let fileManager = FileManager.default
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let locationAPIManager = LocationAPIManager.shared
    
    init() {
        loadAllRoutes()
        
        // Subscribe to location updates
        if let locationManager = (UIApplication.shared.delegate as? AppDelegate)?.locationManager {
            locationManager.locationPublisher
                .sink { [weak self] locationPoint in
                    self?.saveLocationPoint(locationPoint)
                }
                .store(in: &cancellables)
        }
    }
    
    // MARK: - Public Methods
    
    func getLocationPoints(in dateRange: ClosedRange<Date>) -> [LocationPoint] {
        let filteredRoutes = routes.filter { route in
            let startOfDay = Calendar.current.startOfDay(for: route.date)
            return dateRange.contains(startOfDay)
        }
        
        return filteredRoutes.flatMap { $0.points }
    }
    
    func loadLocationData(for dateRange: ClosedRange<Date>) {
        // Load routes from API for the specified date range
        locationAPIManager.fetchRoutes(page: 1, limit: 100)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Failed to load routes from API: \(error)")
                    }
                },
                receiveValue: { [weak self] apiRoutes in
                    DispatchQueue.main.async {
                        // Filter routes by date range and merge with local routes
                        let filteredRoutes = apiRoutes.filter { route in
                            dateRange.contains(route.date)
                        }
                        
                        // Update local routes with API data
                        self?.mergeRoutesFromAPI(filteredRoutes)
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func saveRoute(name: String, description: String? = nil, points: [LocationPoint]) {
        guard !points.isEmpty else { return }
        
        // Save route to API
        locationAPIManager.saveRoute(name: name, description: description, points: points)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Failed to save route to API: \(error)")
                    }
                },
                receiveValue: { apiRoute in
                    print("Route saved to API successfully: \(apiRoute.name)")
                }
            )
            .store(in: &cancellables)
        
        // Also save locally
        let route = Route(
            id: UUID(),
            date: points.first?.timestamp ?? Date(),
            points: points,
            name: name
        )
        
        routes.append(route)
        saveRoute(route)
    }
    
    // MARK: - Private Methods
    
    private func saveLocationPoint(_ point: LocationPoint) {
        // Get today's route or create a new one
        let today = Calendar.current.startOfDay(for: Date())
        
        if let routeIndex = routes.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            // Add point to existing route
            routes[routeIndex].points.append(point)
            saveRoute(routes[routeIndex])
        } else {
            // Create new route for today
            let newRoute = Route(date: today, points: [point])
            routes.append(newRoute)
            saveRoute(newRoute)
        }
    }
    
    private func mergeRoutesFromAPI(_ apiRoutes: [Route]) {
        for apiRoute in apiRoutes {
            // Check if we already have this route locally
            if let existingIndex = routes.firstIndex(where: { $0.id == apiRoute.id }) {
                // Update existing route
                routes[existingIndex] = apiRoute
            } else {
                // Add new route
                routes.append(apiRoute)
            }
        }
        
        // Sort routes by date
        routes.sort { $0.date > $1.date }
    }
    
    private func loadAllRoutes() {
        guard let documentsDirectory = getDocumentsDirectory() else { return }
        
        do {
            let routeFiles = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "route" }
            
            routes = try routeFiles.compactMap { url in
                let data = try Data(contentsOf: url)
                return try decoder.decode(Route.self, from: data)
            }
            
            // Sort routes by date (newest first)
            routes.sort { $0.date > $1.date }
            
        } catch {
            print("Error loading routes: \(error.localizedDescription)")
        }
    }
    
    private func saveRoute(_ route: Route) {
        guard let documentsDirectory = getDocumentsDirectory() else { return }
        
        do {
            let data = try encoder.encode(route)
            let fileURL = documentsDirectory.appendingPathComponent("\(route.id.uuidString).route")
            try data.write(to: fileURL)
        } catch {
            print("Error saving route: \(error.localizedDescription)")
        }
    }
    
    private func getDocumentsDirectory() -> URL? {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
    }
}