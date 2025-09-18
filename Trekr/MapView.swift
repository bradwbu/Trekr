import SwiftUI
import MapKit

struct MapView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var locationDataStore: LocationDataStore
    @EnvironmentObject private var locationSharingManager: LocationSharingManager
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    @State private var selectedDateRange: ClosedRange<Date>?
    @State private var showingFriendLocations = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: annotationItems) { item in
                MapAnnotation(coordinate: item.coordinate) {
                    Circle()
                        .fill(annotationColor(for: item))
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                }
            }
            .overlay(
                routeOverlay
            )
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                locationManager.startUpdatingLocation()
                updateRegionToUserLocation()
            }
            
            VStack(spacing: 0) {
                if showingFriendLocations {
                    friendsListOverlay
                }
                
                TimelineView(selectedDateRange: $selectedDateRange)
                    .frame(height: 120)
                    .background(Color(.systemBackground).opacity(0.9))
                    .onChange(of: selectedDateRange) { _ in
                        loadLocationDataForSelectedDates()
                    }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingFriendLocations.toggle()
                }) {
                    Image(systemName: showingFriendLocations ? "person.fill" : "person")
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    updateRegionToUserLocation()
                }) {
                    Image(systemName: "location")
                }
            }
        }
    }
    
    private var annotationItems: [LocationPoint] {
        guard let selectedDateRange = selectedDateRange else {
            return []
        }
        
        return locationDataStore.getLocationPoints(in: selectedDateRange)
    }
    
    private var routeOverlay: some View {
        GeometryReader { geometry in
            let points = annotationItems
            
            Path { path in
                guard !points.isEmpty else { return }
                
                let firstPoint = points[0]
                let firstScreenPoint = geometry.convert(
                    CLLocationCoordinate2D(
                        latitude: firstPoint.coordinate.latitude,
                        longitude: firstPoint.coordinate.longitude
                    ),
                    from: region
                )
                
                path.move(to: firstScreenPoint)
                
                for point in points.dropFirst() {
                    let screenPoint = geometry.convert(
                        CLLocationCoordinate2D(
                            latitude: point.coordinate.latitude,
                            longitude: point.coordinate.longitude
                        ),
                        from: region
                    )
                    path.addLine(to: screenPoint)
                }
            }
            .stroke(Color.blue, lineWidth: 3)
        }
    }
    
    private var friendsListOverlay: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 15) {
                ForEach(locationSharingManager.sharedLocations) { friend in
                    Button(action: {
                        region.center = friend.coordinate
                    }) {
                        VStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(String(friend.name.prefix(1)))
                                        .foregroundColor(.white)
                                        .font(.headline)
                                )
                            
                            Text(friend.name)
                                .font(.caption)
                                .lineLimit(1)
                            
                            Text(timeAgo(from: friend.lastUpdated))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
        .background(Color(.systemBackground).opacity(0.9))
        .frame(height: 100)
    }
    
    private func annotationColor(for point: LocationPoint) -> Color {
        // Different colors based on time of day or accuracy
        if point.accuracy <= 10 {
            return .blue
        } else if point.accuracy <= 50 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func updateRegionToUserLocation() {
        if let userLocation = locationManager.lastLocation?.coordinate {
            withAnimation {
                region = MKCoordinateRegion(
                    center: userLocation,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            }
        }
    }
    
    private func loadLocationDataForSelectedDates() {
        guard let dateRange = selectedDateRange else { return }
        
        // Load location data for the selected date range
        locationDataStore.loadLocationData(for: dateRange)
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

extension GeometryProxy {
    func convert(_ coordinate: CLLocationCoordinate2D, from region: MKCoordinateRegion) -> CGPoint {
        let latRatio = (coordinate.latitude - region.center.latitude) / region.span.latitudeDelta
        let lonRatio = (coordinate.longitude - region.center.longitude) / region.span.longitudeDelta
        
        return CGPoint(
            x: size.width * (0.5 + lonRatio),
            y: size.height * (0.5 - latRatio)
        )
    }
}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            MapView()
                .environmentObject(LocationManager())
                .environmentObject(LocationDataStore())
                .environmentObject(LocationSharingManager())
        }
    }
}