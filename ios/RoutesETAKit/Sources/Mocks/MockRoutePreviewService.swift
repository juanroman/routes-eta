import Domain
import Foundation

/// Draws origin → via points → destination as straight segments, with a
/// distance inflated to look road-like. Deterministic, no network.
public struct MockRoutePreviewService: RoutePreviewService {
  public init() {}

  public func preview(
    origin: LatLng, destination: LatLng, via: [LatLng]
  ) async throws -> RoutePreview {
    let points = [origin] + via + [destination]
    var meters = 0.0
    for (from, to) in zip(points, points.dropFirst()) {
      meters += Self.haversineMeters(from, to)
    }
    return RoutePreview(distanceMeters: Int(meters * 1.3), polyline: points)
  }

  static func haversineMeters(_ from: LatLng, _ to: LatLng) -> Double {
    let radius = 6_371_000.0
    let dLat = (to.lat - from.lat) * .pi / 180
    let dLng = (to.lng - from.lng) * .pi / 180
    let lat1 = from.lat * .pi / 180
    let lat2 = to.lat * .pi / 180
    let haversine =
      sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2)
    return 2 * radius * asin(haversine.squareRoot())
  }
}
