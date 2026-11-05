import Domain
import Foundation
import Testing

@testable import Platform

struct SavedPlacesRepositoryTests {
  private func makeRepository() -> UserDefaultsSavedPlacesRepository {
    let suite = "test.\(UUID().uuidString)"
    UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    return UserDefaultsSavedPlacesRepository(suiteName: suite)
  }

  @Test func startsEmpty() async throws {
    #expect(try await makeRepository().load() == SavedPlaces())
  }

  @Test func roundTripsHomeAndWork() async throws {
    let repository = makeRepository()
    let places = SavedPlaces(
      home: SavedPlace(point: NamedPoint(label: "Home", lat: 1, lng: 2), detail: "Calle A"),
      work: SavedPlace(point: NamedPoint(label: "Work", lat: 3, lng: 4), detail: "Calle B"))
    try await repository.save(places)
    #expect(try await repository.load() == places)
  }
}
