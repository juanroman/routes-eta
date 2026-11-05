#if DEBUG
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
      etaService: MockETAService(repository: repository))
  }

  #Preview("Commutes") { previewRoot() }
#endif
