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
    let result = await store.addCommute(named: "  Gym  ")
    #expect(result == .success(try #require(store.entries.last?.id)))
    #expect(store.entries.last?.commute.name == "Gym")
    #expect(try await repository.load().commutes.last?.name == "Gym")
  }

  @Test func addKeepsTheChosenPlaces() async throws {
    let (store, repository) = await loadedStore()
    let gym = NamedPoint(label: "Gym", lat: 19.41, lng: -99.17)
    let result = await store.addCommute(
      named: "Evening", origin: SampleData.home, destination: gym)

    let id = try result.get()
    #expect(store.entry(id: id)?.commute.origin == SampleData.home)
    #expect(store.entry(id: id)?.commute.destination == gym)
    #expect(try await repository.load().commutes.last?.destination == gym)
  }

  @Test func addRejectsBlankAndDuplicateNames() async {
    let (store, _) = await loadedStore()
    for name in ["   ", "Work to Home"] {
      let result = await store.addCommute(named: name)
      #expect(throws: ConfigStoreError.self) { try result.get() }
    }
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

@MainActor
struct RouteEditingStoreTests {
  struct Fixture {
    let store: ConfigStore
    let id: CommuteEntry.ID
    let repository: InMemoryConfigRepository
  }

  private func loaded() async throws -> Fixture {
    let repository = InMemoryConfigRepository()
    let store = ConfigStore(repository: repository)
    await store.load()
    return Fixture(store: store, id: try #require(store.entries.first?.id), repository: repository)
  }

  @Test func addRouteAppendsPersistsAndReturnsItsIndex() async throws {
    let fixture = try await loaded()
    let (store, id, repository) = (fixture.store, fixture.id, fixture.repository)
    let result = await store.addRoute(to: id)
    #expect(result == .success(2))
    #expect(store.entry(id: id)?.commute.routes.last?.name == "Route 3")
    #expect(try await repository.load().commutes.first?.routes.count == 3)
  }

  @Test func deleteRouteRemovesOnlyThatRoute() async throws {
    let fixture = try await loaded()
    let (store, id) = (fixture.store, fixture.id)
    #expect(await store.deleteRoute(in: id, at: 0) == nil)
    #expect(store.entry(id: id)?.commute.routes.map(\.name) == ["Mordor"])
  }

  @Test func deleteRouteOutOfRangeIsANoOp() async throws {
    let fixture = try await loaded()
    let (store, id) = (fixture.store, fixture.id)
    #expect(await store.deleteRoute(in: id, at: 9) == nil)
    #expect(store.entry(id: id)?.commute.routes.count == 2)
  }

  @Test func renameAndRecolorGoThroughValidation() async throws {
    let fixture = try await loaded()
    let (store, id) = (fixture.store, fixture.id)
    #expect(
      await store.updateCommute(id: id) { $0.routes[0].color = RoutePalette.colors[3] } == nil)
    #expect(store.entry(id: id)?.commute.routes[0].color == RoutePalette.colors[3])
    #expect(await store.updateCommute(id: id) { $0.routes[0].name = "Mordor" } != nil)
    #expect(store.entry(id: id)?.commute.routes[0].name == "City")
  }

  @Test func moveRouteReordersAndPersists() async throws {
    let fixture = try await loaded()
    let (store, id, repository) = (fixture.store, fixture.id, fixture.repository)
    #expect(await store.moveRoute(in: id, from: IndexSet(integer: 1), to: 0) == nil)
    #expect(store.entry(id: id)?.commute.routes.map(\.name) == ["Mordor", "City"])
    #expect(try await repository.load().commutes.first?.routes.map(\.name) == ["Mordor", "City"])
  }

  @Test func moveCommuteReordersAndPersists() async throws {
    let fixture = try await loaded()
    let (store, repository) = (fixture.store, fixture.repository)
    #expect(await store.moveCommute(from: IndexSet(integer: 1), to: 0) == nil)
    #expect(store.entries.map(\.commute.name) == ["Home to Work", "Work to Home"])
    #expect(
      try await repository.load().commutes.map(\.name) == ["Home to Work", "Work to Home"])
  }

  @Test func reorderingKeepsRoutesIntact() async throws {
    let fixture = try await loaded()
    let (store, id) = (fixture.store, fixture.id)
    let before = try #require(store.entry(id: id)?.commute.routes)
    #expect(await store.updateCommute(id: id) { $0.routes.reverse() } == nil)
    #expect(store.entry(id: id)?.commute.routes == before.reversed())
  }
}

@MainActor
struct ConfigStoreWriteFailureTests {
  struct FailingSave: ConfigRepository {
    func load() async throws -> Config { SampleData.config }
    func save(_ config: Config) async throws { throw CocoaError(.fileWriteOutOfSpace) }
  }

  @Test func aFailedWriteLeavesTheVisibleStateUntouched() async throws {
    let store = ConfigStore(repository: FailingSave())
    await store.load()
    let before = store.entries

    #expect(
      await store.addCommute(named: "Gym")
        == .failure(ConfigStoreError(message: "Couldn't save your changes.")))
    let id = try #require(before.first?.id)
    #expect(await store.renameCommute(id: id, to: "Evening") != nil)
    #expect(await store.deleteCommute(id: id) != nil)
    #expect(await store.moveCommute(from: IndexSet(integer: 1), to: 0) != nil)
    #expect(await store.moveRoute(in: id, from: IndexSet(integer: 1), to: 0) != nil)
    #expect(store.entries == before)
  }
}
