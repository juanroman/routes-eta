import Domain
import SwiftUI

/// The commute's routes: tap a row to find it on the map, the trailing button opens
/// its editor, swipe to delete (confirmed) and reorder (via the Edit button).
struct RoutesSection: View {
  let store: ConfigStore
  let router: AppRouter
  let commuteID: CommuteEntry.ID
  let routes: [RouteDef]

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
          Button {
            selected = selected == route.name ? nil : route.name
          } label: {
            HStack {
              Circle().fill(Color(hex: route.color)).frame(width: 14, height: 14)
              Text(route.name)
              Spacer()
              if selected == route.name {
                Image(systemName: "checkmark").foregroundStyle(.tint)
              }
              Text("\(route.via.count) via").foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel(route.name)
          .accessibilityValue(viaDescription(route))
          .accessibilityAddTraits(selected == route.name ? .isSelected : [])

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

  private func viaDescription(_ route: RouteDef) -> String {
    route.via.count == 1 ? "1 via point" : "\(route.via.count) via points"
  }
}
