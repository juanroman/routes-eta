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

/// Frames points in the part of a map that nothing covers. The sheet over the map and the
/// navigation bar hide the bottom and top of it, so the content is fitted into, and
/// centred in, what is left.
///
/// This works in `MKMapPoint` space (the projection the map itself draws in) instead of
/// latitude/longitude spans: a span-based fit has to guess whether width or height limits
/// the zoom, and guessing wrong is what hid markers under the sheet.
enum CameraFit {
  /// A single point (or a tiny route) must not zoom in to street level.
  static let minimumExtentMeters = 1_000.0

  /// The map rectangle to show, or nil when there is nothing to frame or no size yet.
  /// `mapSize` is the whole map, including the parts under the bars; the insets are the
  /// heights covered at the top and the bottom; `padding` is the margin left around the
  /// content inside the uncovered part. All in screen points.
  static func rect(
    fitting points: [LatLng], mapSize: CGSize, topInset: CGFloat, bottomInset: CGFloat,
    padding: CGFloat = 48
  ) -> MKMapRect? {
    guard let first = points.first, mapSize.width > 0, mapSize.height > 0 else { return nil }
    let mapPoints = points.map { MKMapPoint($0.coordinate) }
    let minX = mapPoints.map(\.x).min() ?? 0
    let maxX = mapPoints.map(\.x).max() ?? 0
    let minY = mapPoints.map(\.y).min() ?? 0
    let maxY = mapPoints.map(\.y).max() ?? 0

    let minimum = minimumExtentMeters * MKMapPointsPerMeterAtLatitude(first.lat)
    let contentWidth = max(maxX - minX, minimum)
    let contentHeight = max(maxY - minY, minimum)

    // Never squeeze the content into a sliver, however tall the sheet is.
    let visibleHeight = max(mapSize.height - topInset - bottomInset, mapSize.height * 0.25)
    let availableWidth = max(mapSize.width - 2 * padding, 1)
    let availableHeight = max(visibleHeight - 2 * padding, 1)

    // Map points per screen point: whichever axis is tighter decides the zoom.
    let scale = max(contentWidth / availableWidth, contentHeight / availableHeight)

    // Put the content's centre at the centre of the uncovered part.
    let visibleCenterY = topInset + visibleHeight / 2
    return MKMapRect(
      x: (minX + maxX) / 2 - mapSize.width / 2 * scale,
      y: (minY + maxY) / 2 - visibleCenterY * scale,
      width: mapSize.width * scale,
      height: mapSize.height * scale)
  }
}
