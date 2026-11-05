import Domain
import MapKit

extension LatLng {
  var coordinate: CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: lat, longitude: lng)
  }

  init(_ coordinate: CLLocationCoordinate2D) {
    self.init(lat: coordinate.latitude, lng: coordinate.longitude)
  }
}

enum MapRegionFit {
  /// Mexico City, used when there is nothing to fit.
  static let fallback = MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: 19.4326, longitude: -99.1332),
    span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2))

  /// A region centered on the bounding box of `points`, padded so none sit on
  /// the edge and never tighter than ~1 km.
  static func region(fitting points: [LatLng]) -> MKCoordinateRegion {
    guard let first = points.first else { return fallback }
    var minLat = first.lat
    var maxLat = first.lat
    var minLng = first.lng
    var maxLng = first.lng
    for point in points {
      minLat = min(minLat, point.lat)
      maxLat = max(maxLat, point.lat)
      minLng = min(minLng, point.lng)
      maxLng = max(maxLng, point.lng)
    }
    return MKCoordinateRegion(
      center: CLLocationCoordinate2D(
        latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2),
      span: MKCoordinateSpan(
        latitudeDelta: max((maxLat - minLat) * 1.5, 0.01),
        longitudeDelta: max((maxLng - minLng) * 1.5, 0.01)))
  }
}
