import Domain
import SwiftUI

/// The commute detail's routes: list, add, swipe-to-delete (confirmed) and
/// reorder (via the Edit button).
struct RoutesSection: View {
  let store: ConfigStore
  let router: AppRouter
  let commuteID: CommuteEntry.ID
  let routes: [RouteDef]

  @State private var pendingDelete: Int?
  @State private var errorMessage: String?

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
          errorMessage = await store.updateCommute(id: commuteID) {
            $0.routes.move(fromOffsets: source, toOffset: destination)
          }
        }
      }

      Button("Add Route", systemImage: "plus") { Task { await add() } }
        .accessibilityIdentifier("add-route")
    }
    .alert(
      "Delete \"\(pendingName)\"?", isPresented: isConfirming,
      presenting: pendingDelete
    ) { index in
      Button("Delete Route", role: .destructive) {
        Task { errorMessage = await store.deleteRoute(in: commuteID, at: index) }
      }
      Button("Cancel", role: .cancel) {}
    } message: { index in
      Text(routes.indices.contains(index) ? routes[index].deletionWarning : "")
    }
    .alert("Couldn't save", isPresented: hasError) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(errorMessage ?? "")
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

  private var pendingName: String {
    guard let index = pendingDelete, routes.indices.contains(index) else { return "" }
    return routes[index].name
  }

  private var isConfirming: Binding<Bool> {
    Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
  }

  private var hasError: Binding<Bool> {
    Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
  }
}
