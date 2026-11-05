import Domain
import Features
import Mocks
import Platform
import SwiftUI

@main
struct RoutesETAApp: App {
  @State private var store: ConfigStore
  @State private var savedPlaces: SavedPlacesStore
  @State private var router = AppRouter()
  private let placeSearch: any PlaceSearchService

  /// The commute config still runs on in-memory mocks (real API client comes in a
  /// later phase); place search and Home/Work use the real MapKit/UserDefaults
  /// services, except under UI tests (`-mock-services`), which must be offline
  /// and start from a clean slate.
  init() {
    let useMocks = CommandLine.arguments.contains("-mock-services")
    _store = State(initialValue: ConfigStore(repository: InMemoryConfigRepository()))
    if useMocks {
      placeSearch = MockPlaceSearchService()
      _savedPlaces = State(
        initialValue: SavedPlacesStore(repository: InMemorySavedPlacesRepository()))
    } else {
      placeSearch = MapKitPlaceSearchService()
      _savedPlaces = State(
        initialValue: SavedPlacesStore(repository: UserDefaultsSavedPlacesRepository()))
    }
  }

  var body: some Scene {
    WindowGroup {
      RootView(store: store, router: router, placeSearch: placeSearch, savedPlaces: savedPlaces)
    }
  }
}
