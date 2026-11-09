import Domain
import MapKit
import SwiftUI

/// The editable map plus its overlays (loading/error banner and the expand or
/// collapse button). Used inline in the route editor and, with `isFullScreen`,
/// edge to edge in a full-screen cover; both edit the same data.
struct RouteMapEditor: View {
  let origin: NamedPoint
  let destination: NamedPoint
  let route: RouteDef
  let model: RouteMapModel
  @Binding var selectedVia: Int?
  @Binding var cameraRegion: MKCoordinateRegion?
  let isFullScreen: Bool
  let onAdd: (LatLng) -> Void
  let onMove: (Int, LatLng) -> Void
  let onRetry: () -> Void
  let onToggleFullScreen: () -> Void

  var body: some View {
    ZStack(alignment: .top) {
      RouteMapView(
        origin: origin, destination: destination, color: Color(hex: route.color),
        via: route.via, polyline: model.polyline, selectedVia: $selectedVia,
        cameraRegion: $cameraRegion, onAdd: onAdd, onMove: onMove
      )
      // Full screen: the map runs under the status bar and home indicator, while the
      // buttons below stay inside the safe area.
      .ignoresSafeArea(edges: isFullScreen ? .all : [])

      statusBanner
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 56)  // keep clear of the corner button

      HStack {
        Spacer()
        Button(
          isFullScreen ? "Close full screen" : "Full screen",
          systemImage: isFullScreen
            ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
          action: onToggleFullScreen
        )
        .labelStyle(.iconOnly)
        .font(.title3)
        .frame(width: 44, height: 44)
        .background(.regularMaterial, in: Circle())
        .accessibilityIdentifier(isFullScreen ? "collapse-map" : "expand-map")
      }
      .padding(8)
      .frame(maxHeight: .infinity, alignment: .topTrailing)
      .allowsHitTesting(true)
    }
    .tapStudyScreen(isFullScreen: isFullScreen)  // TAP-STUDY
  }

  @ViewBuilder private var statusBanner: some View {
    switch model.status {
    case .loading:
      ProgressView().padding(8).background(.regularMaterial, in: Capsule()).padding(8)
    case .failed:
      VStack(spacing: 6) {
        Text(model.failureMessage ?? "Couldn't draw the route")
          .font(.footnote)
          .multilineTextAlignment(.center)
          .lineLimit(4)
        Button("Retry", action: onRetry)
          .font(.subheadline.bold())
      }
      .padding(10)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
      .padding(8)
    case .idle, .loaded:
      EmptyView()
    }
  }
}

/// "N via points" plus the hint or the Remove button for the selected handle.
struct ViaBar: View {
  let route: RouteDef
  @Binding var selectedVia: Int?
  let onRemove: (Int) -> Void

  var body: some View {
    HStack {
      Text(summary)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("via-count")
      Spacer()
      if let selected = selectedVia, route.via.indices.contains(selected) {
        Button("Remove via point \(selected + 1)", role: .destructive) {
          onRemove(selected)
          selectedVia = nil
        }
        .accessibilityIdentifier("remove-via")
      } else if route.canAddVia {
        Text("Tap the route to add a via point").font(.footnote).foregroundStyle(.secondary)
      } else {
        Text("Maximum of \(maxViaPoints) via points").font(.footnote).foregroundStyle(.orange)
      }
    }
    .padding(.horizontal)
    .padding(.vertical, 8)
  }

  private var summary: String {
    switch route.via.count {
    case 0: "No via points"
    case 1: "1 via point"
    default: "\(route.via.count) via points"
    }
  }
}
