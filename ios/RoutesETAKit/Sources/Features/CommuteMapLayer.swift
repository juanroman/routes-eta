import Domain
import MapKit
import SwiftUI

/// What the commute screen's map shows and how it answers taps, as a plain function of the
/// commute, the lines drawn so far and the selected route (by name).
@MainActor
struct CommuteMapLayer {
  let commute: Commute
  /// Lines by route index.
  let lines: [Int: [LatLng]]
  let selected: String?

  /// How close (in points) a tap must be to a line to select its route.
  static let hitRadius = 30.0

  var selectedIndex: Int? {
    guard let selected else { return nil }
    return commute.routes.firstIndex { $0.name == selected }
  }

  /// The selected route's line if there is one, else every line; always the endpoints.
  var framing: [LatLng] {
    var points = [commute.origin?.latLng, commute.destination?.latLng].compactMap { $0 }
    if let selectedIndex, let line = lines[selectedIndex] {
      points += line
    } else {
      points += lines.keys.sorted().flatMap { lines[$0] ?? [] }
    }
    return points
  }

  var summary: String {
    guard let origin = commute.origin, let destination = commute.destination else {
      return "Map of \(commute.name)"
    }
    let count = commute.routes.count
    let noun = count == 1 ? "route" : "routes"
    return "Map of \(count) \(noun) from \(origin.label) to \(destination.label)"
  }

  @MapContentBuilder var content: some MapContent {
    if let origin = commute.origin {
      Marker(origin.label, systemImage: "circle.fill", coordinate: origin.latLng.coordinate)
        .tint(.green)
    }
    if let destination = commute.destination {
      Marker(
        destination.label, systemImage: "flag.fill", coordinate: destination.latLng.coordinate
      )
      .tint(.red)
    }
    // Drawn in two passes, in this order, so the selected route ends up on top: the others
    // (faded while one is selected), then the selected one, thicker. (A white outline under
    // it was tried; it never showed, so the highlight is just size and the fading.)
    let selectedIndex = selectedIndex
    ForEach(commute.routes.indices.filter { $0 != selectedIndex }, id: \.self) { index in
      if let line = lines[index] {
        MapPolyline(coordinates: line.map(\.coordinate))
          .stroke(
            Color(hex: commute.routes[index].color).opacity(selectedIndex == nil ? 1 : 0.35),
            lineWidth: 6)
      }
    }
    if let selectedIndex, let line = lines[selectedIndex] {
      MapPolyline(coordinates: line.map(\.coordinate))
        .stroke(Color(hex: commute.routes[selectedIndex].color), lineWidth: 9)
    }
  }

  /// The route whose line passes closest to a tap, if any is within reach; `nil` for a tap
  /// on empty map (which clears the selection). `screenLine` converts a route's line to
  /// screen points.
  func route(near point: CGPoint, screenLine: ([LatLng]) -> [CGPoint]) -> String? {
    var nearest: (name: String, distance: Double)?
    for (index, route) in commute.routes.enumerated() {
      guard let line = lines[index] else { continue }
      let distance = ScreenGeometry.distance(from: point, toPolyline: screenLine(line))
      if distance <= Self.hitRadius, distance < (nearest?.distance ?? .infinity) {
        nearest = (route.name, distance)
      }
    }
    return nearest?.name
  }
}
