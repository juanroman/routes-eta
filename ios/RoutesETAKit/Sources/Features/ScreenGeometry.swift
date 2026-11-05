import CoreGraphics

/// Hit-testing in screen points, used to decide whether a map tap landed on
/// the route line or on an existing via handle.
enum ScreenGeometry {
  /// Shortest distance from `point` to the polyline through `vertices`.
  static func distance(from point: CGPoint, toPolyline vertices: [CGPoint]) -> Double {
    guard let first = vertices.first else { return .infinity }
    guard vertices.count > 1 else { return hypot(point.x - first.x, point.y - first.y) }
    var best = Double.infinity
    for (start, end) in zip(vertices, vertices.dropFirst()) {
      let dx = end.x - start.x
      let dy = end.y - start.y
      let lengthSquared = dx * dx + dy * dy
      let fraction =
        lengthSquared == 0
        ? 0 : max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
      best = min(
        best, hypot(point.x - (start.x + fraction * dx), point.y - (start.y + fraction * dy)))
    }
    return best
  }

  static func isNear(_ point: CGPoint, anyOf others: [CGPoint], within radius: Double) -> Bool {
    others.contains { hypot(point.x - $0.x, point.y - $0.y) <= radius }
  }
}
