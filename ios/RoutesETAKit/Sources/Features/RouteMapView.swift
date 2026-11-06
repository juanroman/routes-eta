import Domain
import MapKit
import SwiftUI

/// The route on a map. Tap the line to add a via point, drag a handle to move
/// it, tap a handle to select it. The view reports edits; it owns no data.
///
/// Spike findings that shaped this (verified in the simulator):
/// - A drag that starts on a handle does not pan the map.
/// - Tap and drag locations are only consistent with `MapProxy.convert` in the
///   `.global` space; a named space shifts by the safe-area inset.
/// - A tap on a handle also reaches the map's own tap handler, so taps near an
///   existing handle are ignored there.
struct RouteMapView: View {
  let origin: NamedPoint
  let destination: NamedPoint
  let color: Color
  let via: [LatLng]
  let polyline: [LatLng]
  @Binding var selectedVia: Int?
  let onAdd: (LatLng) -> Void
  let onMove: (Int, LatLng) -> Void

  /// How close (in points) a tap must be to the line to add a via point, and to
  /// a handle to count as hitting it.
  private let hitRadius = 30.0

  @State private var dragging: DragState?
  /// The last region this map (or the other copy of it, inline vs full screen) settled
  /// on, so pan/zoom survive switching between them. Each map only *starts* there
  /// (`initialPosition`) and reports changes back; binding a `MapCameraPosition`
  /// directly made the full-screen copy open on a world view and ignore zoom.
  /// nil until a camera has settled, then the route is fitted.
  @Binding var cameraRegion: MKCoordinateRegion?
  private let fittedRegion: MKCoordinateRegion

  struct DragState: Equatable {
    var index: Int
    var coordinate: LatLng
  }

  init(
    origin: NamedPoint, destination: NamedPoint, color: Color, via: [LatLng], polyline: [LatLng],
    selectedVia: Binding<Int?>, cameraRegion: Binding<MKCoordinateRegion?>,
    onAdd: @escaping (LatLng) -> Void,
    onMove: @escaping (Int, LatLng) -> Void
  ) {
    self.origin = origin
    self.destination = destination
    self.color = color
    self.via = via
    self.polyline = polyline
    _selectedVia = selectedVia
    self.onAdd = onAdd
    self.onMove = onMove
    _cameraRegion = cameraRegion
    // Fit the route until a camera has been chosen; later edits keep the user's pan/zoom.
    fittedRegion = MapRegionFit.region(fitting: [origin.latLng, destination.latLng] + via)
  }

  var body: some View {
    MapReader { proxy in
      Map(initialPosition: .region(cameraRegion ?? fittedRegion)) {
        if polyline.count > 1 {
          MapPolyline(coordinates: polyline.map(\.coordinate)).stroke(color, lineWidth: 6)
        }
        Marker(origin.label, systemImage: "circle.fill", coordinate: origin.latLng.coordinate)
          .tint(.green)
        Marker(
          destination.label, systemImage: "flag.fill", coordinate: destination.latLng.coordinate
        )
        .tint(.red)
        ForEach(displayedVia.indices, id: \.self) { index in
          Annotation("", coordinate: displayedVia[index].coordinate) {
            handle(index: index, proxy: proxy)
          }
        }
      }
      .onMapCameraChange(frequency: .onEnd) { context in
        cameraRegion = context.region
      }
      .onTapGesture(coordinateSpace: .global) { point in
        handleTap(at: point, proxy: proxy)
      }
    }
  }

  /// While dragging, the handle follows the finger; the edit is only committed on release.
  private var displayedVia: [LatLng] {
    var shown = via
    if let dragging, shown.indices.contains(dragging.index) {
      shown[dragging.index] = dragging.coordinate
    }
    return shown
  }

  private func handle(index: Int, proxy: MapProxy) -> some View {
    let isSelected = selectedVia == index
    return Text("\(index + 1)")
      .font(.caption.bold())
      .foregroundStyle(.white)
      .frame(width: 28, height: 28)
      .background(color, in: Circle())
      .overlay(Circle().stroke(.white, lineWidth: isSelected ? 4 : 2))
      .shadow(radius: isSelected ? 6 : 2)
      .frame(width: 44, height: 44)  // touch-friendly target (FR-10)
      .contentShape(Circle())
      .onTapGesture { selectedVia = index }
      .gesture(
        DragGesture(coordinateSpace: .global)
          .onChanged { value in
            guard let coordinate = proxy.convert(value.location, from: .global) else { return }
            selectedVia = index
            dragging = DragState(index: index, coordinate: LatLng(coordinate))
          }
          .onEnded { _ in
            if let dragging { onMove(dragging.index, dragging.coordinate) }
            dragging = nil
          }
      )
      .accessibilityLabel("Via point \(index + 1)")
      .accessibilityIdentifier("via-handle-\(index)")
  }

  private func handleTap(at point: CGPoint, proxy: MapProxy) {
    let handles = via.compactMap { proxy.convert($0.coordinate, to: .global) }
    if ScreenGeometry.isNear(point, anyOf: handles, within: hitRadius) { return }
    selectedVia = nil

    let line = polyline.compactMap { proxy.convert($0.coordinate, to: .global) }
    guard ScreenGeometry.distance(from: point, toPolyline: line) <= hitRadius,
      let coordinate = proxy.convert(point, from: .global)
    else { return }
    onAdd(LatLng(coordinate))
  }
}
