import Foundation
import Testing

@testable import Platform

struct LocationPromptRepositoryTests {
  private func makeRepository(suite: String = "test.\(UUID().uuidString)")
    -> UserDefaultsLocationPromptRepository
  {
    UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    return UserDefaultsLocationPromptRepository(suiteName: suite)
  }

  @Test func startsUndeclined() async {
    #expect(await makeRepository().wasDeclined() == false)
  }

  @Test func remembersNotNowAcrossInstances() async {
    let suite = "test.\(UUID().uuidString)"
    await makeRepository(suite: suite).markDeclined()
    #expect(await UserDefaultsLocationPromptRepository(suiteName: suite).wasDeclined())
  }
}
