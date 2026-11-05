import Domain
import Foundation
import Mocks
import Testing

@testable import Features

@MainActor
struct ConfigStoreTests {
  private func loadedStore() async -> (ConfigStore, InMemoryConfigRepository) {
    let repository = InMemoryConfigRepository()
    let store = ConfigStore(repository: repository)
    await store.load()
    return (store, repository)
  }

  @Test func loadsSeedCommutesInOrder() async {
    let (store, _) = await loadedStore()
    #expect(store.loadState == .loaded)
    #expect(store.entries.map(\.commute.name) == ["Work to Home", "Home to Work"])
  }

  @Test func addPersistsAndTrimsTheName() async throws {
    let (store, repository) = await loadedStore()
    #expect(await store.addCommute(named: "  Gym  ") == nil)
    #expect(store.entries.last?.commute.name == "Gym")
    #expect(try await repository.load().commutes.last?.name == "Gym")
  }

  @Test func addRejectsBlankAndDuplicateNames() async {
    let (store, _) = await loadedStore()
    #expect(await store.addCommute(named: "   ") != nil)
    #expect(await store.addCommute(named: "Work to Home") != nil)
    #expect(store.entries.count == 2)
  }

  @Test func renameKeepsIdentityAndPersists() async throws {
    let (store, repository) = await loadedStore()
    let id = try #require(store.entries.first?.id)
    #expect(await store.renameCommute(id: id, to: "Evening") == nil)
    #expect(store.entry(id: id)?.commute.name == "Evening")
    #expect(try await repository.load().commutes.first?.name == "Evening")
  }

  @Test func renameToAnExistingNameFailsAndChangesNothing() async throws {
    let (store, _) = await loadedStore()
    let id = try #require(store.entries.first?.id)
    #expect(await store.renameCommute(id: id, to: "Home to Work") != nil)
    #expect(store.entry(id: id)?.commute.name == "Work to Home")
  }

  @Test func deleteRemovesAndPersists() async throws {
    let (store, repository) = await loadedStore()
    let id = try #require(store.entries.first?.id)
    #expect(await store.deleteCommute(id: id) == nil)
    #expect(store.entry(id: id) == nil)
    #expect(try await repository.load().commutes.count == 1)
  }

  @Test func loadFailureIsReported() async {
    struct Broken: ConfigRepository {
      func load() async throws -> Config { throw ConfigRepositoryError.invalid([]) }
      func save(_ config: Config) async throws {}
    }
    let store = ConfigStore(repository: Broken())
    await store.load()
    #expect(store.loadState == .failed("Couldn't load your commutes."))
  }
}

@MainActor
struct ConfigStoreUpdateTests {
  @Test func updateChangesOneCommuteAndPersists() async throws {
    let repository = InMemoryConfigRepository()
    let store = ConfigStore(repository: repository)
    await store.load()
    let id = try #require(store.entries.first?.id)

    #expect(await store.updateCommute(id: id) { $0.origin = SampleData.home } == nil)
    #expect(store.entry(id: id)?.commute.origin == SampleData.home)
    #expect(try await repository.load().commutes.first?.origin == SampleData.home)
  }

  @Test func updateThatBreaksValidationIsRejectedAndNotApplied() async throws {
    let store = ConfigStore(repository: InMemoryConfigRepository())
    await store.load()
    let id = try #require(store.entries.first?.id)
    let before = store.entry(id: id)

    #expect(await store.updateCommute(id: id) { $0.name = "Home to Work" } != nil)
    #expect(store.entry(id: id) == before)
  }

  @Test func updatingAnUnknownCommuteIsANoOp() async {
    let store = ConfigStore(repository: InMemoryConfigRepository())
    await store.load()
    #expect(await store.updateCommute(id: UUID()) { $0.name = "X" } == nil)
    #expect(store.entries.count == 2)
  }
}

@MainActor
struct PlacePickerModelTests {
  @Test func emptyQueryHasNoSuggestions() async {
    let model = PlacePickerModel(service: MockPlaceSearchService())
    await model.update(query: "")
    #expect(model.suggestions.isEmpty)
  }

  @Test func queryFiltersIgnoringCaseAndAccents() async {
    let model = PlacePickerModel(service: MockPlaceSearchService())
    await model.update(query: "satelite")
    #expect(model.suggestions.map(\.title) == ["Satélite"])
  }

  @Test func resolveReturnsCoordinates() async throws {
    let model = PlacePickerModel(service: MockPlaceSearchService())
    await model.update(query: "polanco")
    let suggestion = try #require(model.suggestions.first)
    let point = await model.resolve(suggestion)
    #expect(point?.label == "Polanco")
    #expect(model.resolveFailed == false)
  }

  @Test func resolveFailureIsReported() async {
    let model = PlacePickerModel(service: MockPlaceSearchService())
    let point = await model.resolve(PlaceSuggestion(id: "nope", title: "Nope", subtitle: ""))
    #expect(point == nil)
    #expect(model.resolveFailed)
  }

  @Test func searchFailureIsReported() async {
    struct Broken: PlaceSearchService {
      func suggestions(for query: String) async throws -> [PlaceSuggestion] {
        throw PlaceSearchError.notFound
      }
      func resolve(_ suggestion: PlaceSuggestion) async throws -> NamedPoint {
        throw PlaceSearchError.notFound
      }
    }
    let model = PlacePickerModel(service: Broken())
    await model.update(query: "x")
    #expect(model.failed)
    #expect(model.suggestions.isEmpty)
  }
}

@MainActor
struct SavedPlacesStoreTests {
  @Test func startsUnset() async {
    let store = SavedPlacesStore(repository: InMemorySavedPlacesRepository())
    await store.load()
    #expect(store.places == SavedPlaces())
  }

  @Test func setForcesTheKeywordLabelAndPersists() async throws {
    let repository = InMemorySavedPlacesRepository()
    let store = SavedPlacesStore(repository: repository)
    let found = NamedPoint(label: "Calle Amores 12", lat: 19.4, lng: -99.1)

    let saved = await store.set(.home, to: found, detail: "Del Valle, CDMX")
    #expect(saved == NamedPoint(label: "Home", lat: 19.4, lng: -99.1))
    #expect(store.places.home?.detail == "Del Valle, CDMX")
    #expect(store.places.work == nil)
    #expect(try await repository.load().home == store.places.home)
  }

  @Test func changingAShortcutDoesNotTouchExistingCommutes() async throws {
    let configStore = ConfigStore(repository: InMemoryConfigRepository())
    await configStore.load()
    let id = try #require(configStore.entries.first?.id)
    let places = SavedPlacesStore(repository: InMemorySavedPlacesRepository())

    let first = try #require(
      await places.set(.work, to: NamedPoint(label: "A", lat: 1, lng: 2), detail: ""))
    await configStore.updateCommute(id: id) { $0.origin = first }
    await places.set(.work, to: NamedPoint(label: "B", lat: 5, lng: 6), detail: "")

    #expect(configStore.entry(id: id)?.commute.origin == NamedPoint(label: "Work", lat: 1, lng: 2))
  }
}
