import Domain
import SwiftUI

/// App entry screen: owns the `NavigationStack` and maps routes to screens.
public struct RootView: View {
  @Bindable private var router: AppRouter
  private let store: ConfigStore
  private let placeSearch: any PlaceSearchService
  private let savedPlaces: SavedPlacesStore
  private let routePreview: any RoutePreviewService
  private let etaService: any ETAService

  public init(
    store: ConfigStore, router: AppRouter, placeSearch: any PlaceSearchService,
    savedPlaces: SavedPlacesStore, routePreview: any RoutePreviewService,
    etaService: any ETAService
  ) {
    self.store = store
    self.placeSearch = placeSearch
    self.savedPlaces = savedPlaces
    self.routePreview = routePreview
    self.etaService = etaService
    self.router = router
  }

  public var body: some View {
    NavigationStack(path: $router.path) {
      CommutesListView(store: store)
        .navigationDestination(for: AppRoute.self) { route in
          switch route {
          case .commute(let id):
            CommuteDetailView(
              store: store, router: router, placeSearch: placeSearch, savedPlaces: savedPlaces,
              etaService: etaService, commuteID: id)
          case .routeEditor(let commuteID, let route):
            RouteEditorView(
              store: store, routePreview: routePreview, commuteID: commuteID, routeIndex: route)
          case .scheduleEditor(let commuteID):
            ScheduleEditorView(store: store, commuteID: commuteID)
          }
        }
    }
    .task {
      await savedPlaces.load()
      await store.load()
    }
  }
}
