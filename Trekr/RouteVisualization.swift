import SwiftUI
import MapKit

struct RouteOverlay: UIViewRepresentable {
    var locationPoints: [LocationPoint]
    var lineColor: UIColor = .blue
    var lineWidth: CGFloat = 3.0
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Remove existing overlays
        uiView.removeOverlays(uiView.overlays)
        
        // Add new route overlay if we have points
        if locationPoints.count > 1 {
            let coordinates = locationPoints.map { $0.coordinate }
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            uiView.addOverlay(polyline)
            
            // Add point annotations
            let annotations = locationPoints.map { point -> MKPointAnnotation in
                let annotation = MKPointAnnotation()
                annotation.coordinate = point.coordinate
                return annotation
            }
            
            uiView.removeAnnotations(uiView.annotations)
            uiView.addAnnotations(annotations)
            
            // Zoom to fit the route
            if let first = coordinates.first, let last = coordinates.last {
                let region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(
                        latitude: (first.latitude + last.latitude) / 2,
                        longitude: (first.longitude + last.longitude) / 2
                    ),
                    span: MKCoordinateSpan(
                        latitudeDelta: max(abs(first.latitude - last.latitude), 0.01) * 1.5,
                        longitudeDelta: max(abs(first.longitude - last.longitude), 0.01) * 1.5
                    )
                )
                uiView.setRegion(region, animated: true)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: RouteOverlay
        
        init(_ parent: RouteOverlay) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = parent.lineColor
                renderer.lineWidth = parent.lineWidth
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Skip user location annotation
            if annotation is MKUserLocation {
                return nil
            }
            
            let identifier = "LocationPoint"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false
            } else {
                annotationView?.annotation = annotation
            }
            
            // Customize the annotation view
            if let markerView = annotationView as? MKMarkerAnnotationView {
                markerView.markerTintColor = .blue
                markerView.glyphImage = UIImage(systemName: "circle.fill")
                markerView.glyphTintColor = .white
            }
            
            return annotationView
        }
    }
}

struct LocationPointAnnotation: View {
    var point: LocationPoint
    var color: Color = .blue
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 12, height: 12)
        }
    }
}

struct RouteLineView: Shape {
    var points: [CGPoint]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        guard !points.isEmpty else { return path }
        
        path.move(to: points[0])
        
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        
        return path
    }
}