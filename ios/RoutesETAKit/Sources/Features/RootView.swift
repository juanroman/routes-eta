import Domain
import SwiftUI

/// App entry screen: owns the `NavigationStack` and maps routes to screens.
public struct RootView: View {
  @Bindable private var router: AppRouter
  private let store: ConfigStore
  private let placeSearch: any PlaceSearchService

  public init(store: ConfigStore, router: AppRouter, placeSearch: any PlaceSearchService) {
    self.store = store
    self.placeSearch = placeSearch
    self.router = router
  }

  public var body: some View {
    NavigationStack(path: $router.path) {
      CommutesListView(store: store)
        .navigationDestination(for: AppRoute.self) { route in
          switch route {
          case .commute(let id):
            CommuteDetailView(store: store, placeSearch: placeSearch, commuteID: id)
          case .routeEditor(let commuteID, let routeName):
            RouteEditorPlaceholderView(store: store, commuteID: commuteID, routeName: routeName)
          case .scheduleEditor(let commuteID):
            ScheduleEditorPlaceholderView(store: store, commuteID: commuteID)
          }
        }
    }
    .task { await store.load() }
  }
}
