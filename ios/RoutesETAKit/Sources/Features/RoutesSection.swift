import Domain
import SwiftUI

/// The commute detail's routes: list, add, swipe-to-delete (confirmed) and
/// reorder (via the Edit button).
struct RoutesSection: View {
  let store: ConfigStore
  let router: AppRouter
  let commuteID: CommuteEntry.ID
  let routes: [RouteDef]

  /// Owned by the commute screen, which presents the delete confirmation and error
  /// alerts: alerts attached to a `Section` inside a `List` proved unreliable.
  @Binding var pendingDelete: Int?
  @Binding var errorMessage: String?

  var body: some View {
    Section("Routes") {
      ForEach(Array(routes.enumerated()), id: \.element.name) { index, route in
        NavigationLink(value: AppRoute.routeEditor(commute: commuteID, route: index)) {
          HStack {
            Circle().fill(Color(hex: route.color)).frame(width: 14, height: 14)
            Text(route.name)
            Spacer()
            Text("\(route.via.count) via").foregroundStyle(.secondary)
          }
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

      Button("Add Route", systemImage: "plus") { Task { await add() } }
        .accessibilityIdentifier("add-route")
    }
  }

  private func add() async {
    switch await store.addRoute(to: commuteID) {
    case .success(let index):
      router.push(.routeEditor(commute: commuteID, route: index))
    case .failure(let error):
      errorMessage = error.message
    }
  }

}
