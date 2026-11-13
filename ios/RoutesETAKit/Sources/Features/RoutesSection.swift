import Domain
import SwiftUI

/// The commute's routes: tap a row to find it on the map (and see its ETA), the trailing
/// button opens its editor, swipe to delete (confirmed) and reorder (via the Edit button).
struct RoutesSection: View {
  let store: ConfigStore
  let router: AppRouter
  let commuteID: CommuteEntry.ID
  let routes: [RouteDef]
  /// Each route's length in meters, by route index (known once its line has loaded).
  let distances: [Int: Int]
  /// The ETA of the selected route.
  let selectedETA: SelectedRouteETAModel.State

  /// The route highlighted on the map, by name (names are unique within a commute, and
  /// unlike an index the name survives reordering).
  @Binding var selected: String?
  /// Owned by the commute screen, which presents the delete confirmation and error
  /// alerts: alerts attached to a `Section` inside a `List` proved unreliable.
  @Binding var pendingDelete: Int?
  @Binding var errorMessage: String?
  /// What the empty state's button does (the same as the sheet's "+").
  let onAdd: () -> Void

  var body: some View {
    Section("Routes") {
      if routes.isEmpty {
        Button("Add your first route", systemImage: "plus", action: onAdd)
      }
      ForEach(Array(routes.enumerated()), id: \.element.name) { index, route in
        HStack {
          RouteRow(
            route: route, distanceMeters: distances[index],
            isSelected: selected == route.name, eta: selectedETA
          ) {
            selected = selected == route.name ? nil : route.name
          }

          Button("Edit \(route.name)", systemImage: "slider.horizontal.3") {
            router.push(.routeEditor(commute: commuteID, route: index))
          }
          .labelStyle(.iconOnly)
          .buttonStyle(.borderless)
          .accessibilityIdentifier("edit-route-\(route.name)")
        }
        .swipeActions {
          Button("Delete", role: .destructive) { pendingDelete = index }
        }
      }
      .onMove { source, destination in
        Task {
          errorMessage = await store.moveRoute(in: commuteID, from: source, to: destination)
        }
      }
    }
  }
}

/// One route's row: its color, its name, and under the name how long it is, plus its ETA while
/// it is the selected one.
private struct RouteRow: View {
  let route: RouteDef
  let distanceMeters: Int?
  let isSelected: Bool
  let eta: SelectedRouteETAModel.State
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack {
        Circle().fill(Color(hex: route.color)).frame(width: 14, height: 14)
        VStack(alignment: .leading, spacing: 2) {
          Text(route.name)
          detail
        }
        Spacer()
        if isSelected { Image(systemName: "checkmark").foregroundStyle(.tint) }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    // The label stays the plain name (that is how the row is found); the numbers are its value.
    .accessibilityLabel(route.name)
    .accessibilityValue(spokenDetail)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  @ViewBuilder private var detail: some View {
    if distanceMeters != nil || isSelected {
      HStack(spacing: 4) {
        if let distanceMeters { Text(RouteDistanceFormat.text(meters: distanceMeters)) }
        if isSelected { etaDetail }
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    }
  }

  @ViewBuilder private var etaDetail: some View {
    switch eta {
    case .idle:
      EmptyView()
    case .loading:
      HStack(spacing: 4) {
        separator
        ProgressView().controlSize(.mini)
      }
    case .loaded(let minutes):
      HStack(spacing: 4) {
        separator
        Text("\(minutes) min").fontWeight(.semibold).foregroundStyle(.primary)
      }
    case .failed:
      HStack(spacing: 4) {
        separator
        Text("ETA unavailable")
      }
    }
  }

  /// The dot between the distance and the ETA, only when there is a distance to separate from.
  @ViewBuilder private var separator: some View {
    if distanceMeters != nil { Text("·") }
  }

  private var spokenDetail: String {
    var parts: [String] = []
    if let distanceMeters { parts.append(RouteDistanceFormat.text(meters: distanceMeters)) }
    if isSelected {
      switch eta {
      case .idle: break
      case .loading: parts.append("loading ETA")
      case .loaded(let minutes): parts.append("\(minutes) min")
      case .failed: parts.append("ETA unavailable")
      }
    }
    return parts.joined(separator: ", ")
  }
}
