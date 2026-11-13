#if DEBUG
  import Domain
  import Mocks
  import SwiftUI

  @MainActor
  private func previewRoot() -> some View {
    let repository = InMemoryConfigRepository()
    return RootView(
      store: ConfigStore(repository: repository),
      router: AppRouter(),
      placeSearch: MockPlaceSearchService(),
      savedPlaces: SavedPlacesStore(repository: InMemorySavedPlacesRepository()),
      routePreview: MockRoutePreviewService(),
      etaService: MockETAService(repository: repository),
      location: FixedLocationProvider(authorization: .authorized, location: SampleData.home.latLng),
      recents: InMemoryRecentCommutesRepository(),
      locationPrompt: InMemoryLocationPromptRepository())
  }

  #Preview("Home") { previewRoot() }
#endif
