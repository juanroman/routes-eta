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
  @Test func emptyQueryListsSuggestions() async {
    let model = PlacePickerModel(service: MockPlaceSearchService())
    await model.update(query: "")
    #expect(model.results == MockPlaceSearchService.places)
  }

  @Test func queryFiltersIgnoringCaseAndAccents() async {
    let model = PlacePickerModel(service: MockPlaceSearchService())
    await model.update(query: "satelite")
    #expect(model.results.map(\.label) == ["Satélite"])
  }

  @Test func searchFailureIsReported() async {
    struct Broken: PlaceSearchService {
      func search(query: String) async throws -> [NamedPoint] { throw CancellationError() }
    }
    let model = PlacePickerModel(service: Broken())
    await model.update(query: "x")
    #expect(model.failed)
    #expect(model.results.isEmpty)
  }
}
