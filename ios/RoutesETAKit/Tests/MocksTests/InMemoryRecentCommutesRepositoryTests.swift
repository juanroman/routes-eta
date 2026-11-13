import Testing

@testable import Mocks

struct InMemoryRecentCommutesRepositoryTests {
  @Test func startsEmptyOrSeeded() async throws {
    #expect(try await InMemoryRecentCommutesRepository().load().isEmpty)
    #expect(try await InMemoryRecentCommutesRepository(initial: ["A"]).load() == ["A"])
  }

  @Test func savedNamesComeBackInOrder() async throws {
    let repository = InMemoryRecentCommutesRepository()
    try await repository.save(["B", "A"])
    #expect(try await repository.load() == ["B", "A"])
  }
}
