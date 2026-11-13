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
  private let routePreview: any RoutePreviewService
  private let showsSchedules: Bool

  /// Standalone app: commutes are saved on the device (a JSON file), place search
  /// is MapKit, and route lines and ETAs come straight from Google's Routes API
  /// (the key is read from the git-ignored `Secrets.plist`; see `ios/README.md`).
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

    // ETA services share the store's repository so ETAs reflect what was just edited.
    if useMocks {
      routePreview = MockRoutePreviewService()
      etaService = MockETAService(repository: configRepository)
    } else {
      let google = GoogleRoutesClient()
      // Lines are cached on the device, so only new or edited routes cost a Google call.
      routePreview = CachedRoutePreviewService(
        wrapping: GoogleRoutePreviewService(client: google), cache: Self.lineCache())
      // A selected route's ETA is remembered for a couple of minutes, so selecting it again
      // right away doesn't ask Google again.
      etaService = CachedETAService(
        wrapping: GoogleETAService(client: google, repository: configRepository))
    }

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
        routePreview: routePreview, etaService: etaService,
        showsSchedules: showsSchedules)
    }
  }

  private static func lineCache() -> FileRouteLineCache {
    // Same last resort as the config file: a cache in the temporary directory still works.
    let url =
      (try? FileRouteLineCache.defaultURL())
      ?? FileManager.default.temporaryDirectory.appending(path: "route-lines.json")
    return FileRouteLineCache(url: url)
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
