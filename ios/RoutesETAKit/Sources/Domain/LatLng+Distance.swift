import Foundation

extension LatLng {
  /// Great-circle distance in meters (haversine). Plenty accurate for "is this within a
  /// kilometer", and it keeps `Domain` free of CoreLocation so a watch target can use it.
  public func distance(to other: LatLng) -> Double {
    let earthRadius = 6_371_000.0
    let lat1 = lat * .pi / 180
    let lat2 = other.lat * .pi / 180
    let deltaLat = (other.lat - lat) * .pi / 180
    let deltaLng = (other.lng - lng) * .pi / 180
    let haversine =
      sin(deltaLat / 2) * sin(deltaLat / 2)
      + cos(lat1) * cos(lat2) * sin(deltaLng / 2) * sin(deltaLng / 2)
    return 2 * earthRadius * atan2(haversine.squareRoot(), (1 - haversine).squareRoot())
  }
}
