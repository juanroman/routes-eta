import Domain

public actor InMemorySavedPlacesRepository: SavedPlacesRepository {
  private var places: SavedPlaces

  public init(initial: SavedPlaces = SavedPlaces()) {
    places = initial
  }

  public func load() async throws -> SavedPlaces { places }

  public func save(_ places: SavedPlaces) async throws { self.places = places }
}
