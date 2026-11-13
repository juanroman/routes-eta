import Testing

@testable import Mocks

struct InMemoryLocationPromptRepositoryTests {
  @Test func startsUndeclinedAndRemembersNotNow() async {
    let repository = InMemoryLocationPromptRepository()
    #expect(await repository.wasDeclined() == false)
    await repository.markDeclined()
    #expect(await repository.wasDeclined())
  }

  @Test func canStartDeclined() async {
    #expect(await InMemoryLocationPromptRepository(declined: true).wasDeclined())
  }
}
