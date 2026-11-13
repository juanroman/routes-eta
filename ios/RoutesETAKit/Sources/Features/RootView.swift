import Domain
import SwiftUI

/// App entry screen: owns the `NavigationStack` (rooted at Home) and maps routes to screens.
public struct RootView: View {
  @Bindable private var router: AppRouter
  private let store: ConfigStore
  private let placeSearch: any PlaceSearchService
  private let savedPlaces: SavedPlacesStore
  private let routePreview: any RoutePreviewService
  private let etaService: any ETAService
  private let location: any LocationProvider
  private let showsSchedules: Bool
  @State private var home: HomeModel

  public init(
    store: ConfigStore, router: AppRouter, placeSearch: any PlaceSearchService,
    savedPlaces: SavedPlacesStore, routePreview: any RoutePreviewService,
    etaService: any ETAService, location: any LocationProvider,
    recents: any RecentCommutesRepository, locationPrompt: any LocationPromptRepository,
    showsSchedules: Bool = false
  ) {
    self.store = store
    self.placeSearch = placeSearch
    self.savedPlaces = savedPlaces
    self.routePreview = routePreview
    self.etaService = etaService
    self.location = location
    self.showsSchedules = showsSchedules
    self.router = router
    _home = State(
      initialValue: HomeModel(
        store: store, service: etaService, location: location, recents: recents,
        prompts: locationPrompt))
  }

  public var body: some View {
    NavigationStack(path: $router.path) {
      HomeView(store: store, router: router, model: home)
        .navigationDestination(for: AppRoute.self) { route in
          switch route {
          case .commutes:
            CommutesListView(
              store: store, router: router, placeSearch: placeSearch, savedPlaces: savedPlaces,
              location: location)
          case .commute(let id):
            CommuteMapScreen(
              store: store, router: router, placeSearch: placeSearch, savedPlaces: savedPlaces,
              etaService: etaService, routePreview: routePreview, showsSchedules: showsSchedules,
              commuteID: id)
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
