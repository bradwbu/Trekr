import Foundation
import CoreLocation
import MapKit

// Model for storing location data points
struct LocationPoint: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let coordinate: CLLocationCoordinate2D
    let accuracy: CLLocationAccuracy
    
    enum CodingKeys: String, CodingKey {
        case id, timestamp, latitude, longitude, accuracy
    }
    
    init(id: UUID = UUID(), timestamp: Date, coordinate: CLLocationCoordinate2D, accuracy: CLLocationAccuracy) {
        self.id = id
        self.timestamp = timestamp
        self.coordinate = coordinate
        self.accuracy = accuracy
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        accuracy = try container.decode(CLLocationAccuracy.self, forKey: .accuracy)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encode(accuracy, forKey: .accuracy)
    }
}

// Model for a complete route (collection of location points)
struct Route: Identifiable, Codable {
    let id: UUID
    let date: Date
    var points: [LocationPoint]
    var name: String?
    
    init(id: UUID = UUID(), date: Date = Date(), points: [LocationPoint] = [], name: String? = nil) {
        self.id = id
        self.date = date
        self.points = points
        self.name = name
    }
}

// Model for user profile
struct UserProfile: Identifiable, Codable {
    let id: String
    var name: String
    var email: String
    var profileImageURL: URL?
    var shareLocationWith: [String] // Array of user IDs
    
    init(id: String, name: String, email: String, profileImageURL: URL? = nil, shareLocationWith: [String] = []) {
        self.id = id
        self.name = name
        self.email = email
        self.profileImageURL = profileImageURL
        self.shareLocationWith = shareLocationWith
    }
}

// Model for shared location from friends
struct SharedLocation: Identifiable {
    let id: String // User ID
    let name: String
    let coordinate: CLLocationCoordinate2D
    let lastUpdated: Date
    
    var mapAnnotation: MKPointAnnotation {
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = name
        return annotation
    }
}