/// Ported from `web/src/map/polylineGeometry.ts`. Google returns one combined
/// polyline per route, not one per via point, so where a new via point belongs
/// in `via[]` is found by comparing nearest-vertex indices.
public enum PolylineGeometry {
  /// Index of the polyline vertex closest to `point`. Squared lat/lng distance
  /// is enough at this app's small, local scale.
  public static func nearestIndex(of point: LatLng, in polyline: [LatLng]) -> Int? {
    polyline.indices.min {
      squaredDistance(point, polyline[$0]) < squaredDistance(point, polyline[$1])
    }
  }

  /// Where to insert a via point at `click` so the order along the route holds.
  public static func viaInsertionIndex(
    for click: LatLng, polyline: [LatLng], existingVia: [LatLng]
  ) -> Int {
    guard let clickIndex = nearestIndex(of: click, in: polyline) else { return existingVia.count }
    var insertAt = 0
    for via in existingVia {
      guard let viaIndex = nearestIndex(of: via, in: polyline), viaIndex <= clickIndex else {
        break
      }
      insertAt += 1
    }
    return insertAt
  }

  private static func squaredDistance(_ lhs: LatLng, _ rhs: LatLng) -> Double {
    let dLat = lhs.lat - rhs.lat
    let dLng = lhs.lng - rhs.lng
    return dLat * dLat + dLng * dLng
  }
}

extension RouteDef {
  public var canAddVia: Bool { via.count < maxViaPoints }

  /// Inserts a via point in route order. Returns its index, or nil if the route
  /// already has the maximum.
  @discardableResult
  public mutating func addVia(at point: LatLng, along polyline: [LatLng]) -> Int? {
    guard canAddVia else { return nil }
    let index = PolylineGeometry.viaInsertionIndex(for: point, polyline: polyline, existingVia: via)
    via.insert(point, at: index)
    return index
  }

  public mutating func moveVia(at index: Int, to point: LatLng) {
    guard via.indices.contains(index) else { return }
    via[index] = point
  }

  public mutating func removeVia(at index: Int) {
    guard via.indices.contains(index) else { return }
    via.remove(at: index)
  }
}
