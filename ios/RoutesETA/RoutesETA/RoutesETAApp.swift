import Domain
import Features
import Foundation
import Mocks
import Platform
import SwiftUI

@main
struct RoutesETAApp: App {
  @State private var store: ConfigStore
  @State private var savedPlaces: SavedPlacesStore
  @State private var router = AppRouter()
  private let placeSearch: any PlaceSearchService
  private let etaService: any ETAService
  private let showsSchedules: Bool

  /// Commutes are saved on the device (a JSON file) and place search is MapKit.
  /// Route previews and ETAs are still mocks until the Google client lands.
  /// `-mock-services` (UI tests) swaps everything for offline, in-memory, seeded
  /// doubles so each run starts from a clean slate. `-show-schedules` reveals the
  /// schedule editor, which is hidden by default (see `CommuteDetailView`).
  init() {
    let arguments = CommandLine.arguments
    let useMocks = arguments.contains("-mock-services")
    showsSchedules = arguments.contains("-show-schedules")

    let configRepository: any ConfigRepository =
      useMocks ? InMemoryConfigRepository() : Self.fileRepository()
    _store = State(initialValue: ConfigStore(repository: configRepository))
    // Shares the store's repository so ETAs reflect what was just edited.
    etaService = MockETAService(repository: configRepository)

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
      RootView(
        store: store, router: router, placeSearch: placeSearch, savedPlaces: savedPlaces,
        routePreview: MockRoutePreviewService(), etaService: etaService,
        showsSchedules: showsSchedules)
    }
  }

  private static func fileRepository() -> FileConfigRepository {
    // Application Support always resolves on iOS; the temporary directory is only a
    // last resort so the app can still launch (and lose data) rather than crash.
    let url =
      (try? FileConfigRepository.defaultURL())
      ?? FileManager.default.temporaryDirectory.appending(path: "config.json")
    return FileConfigRepository(url: url)
  }
}
