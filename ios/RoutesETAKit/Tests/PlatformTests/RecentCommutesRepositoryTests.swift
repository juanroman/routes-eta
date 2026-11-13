import Domain
import Foundation
import Testing

@testable import Platform

struct RecentCommutesRepositoryTests {
  private func makeRepository(suite: String = "test.\(UUID().uuidString)")
    -> UserDefaultsRecentCommutesRepository
  {
    UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    return UserDefaultsRecentCommutesRepository(suiteName: suite)
  }

  @Test func startsEmpty() async throws {
    #expect(try await makeRepository().load().isEmpty)
  }

  @Test func roundTripsTheNamesInOrder() async throws {
    let repository = makeRepository()
    try await repository.save(["Work to Home", "Home to Work"])
    #expect(try await repository.load() == ["Work to Home", "Home to Work"])
  }

  @Test func savingReplacesWhatWasThere() async throws {
    let repository = makeRepository()
    try await repository.save(["A", "B"])
    try await repository.save(["B"])
    #expect(try await repository.load() == ["B"])
  }

  @Test func twoInstancesOnTheSameSuiteShareTheHistory() async throws {
    let suite = "test.\(UUID().uuidString)"
    let writer = makeRepository(suite: suite)
    try await writer.save(["A"])
    let reader = UserDefaultsRecentCommutesRepository(suiteName: suite)
    #expect(try await reader.load() == ["A"])
  }
}
