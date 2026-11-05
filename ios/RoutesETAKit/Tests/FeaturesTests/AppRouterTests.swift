import Domain
import Foundation
import Testing

@testable import Features

@MainActor
struct AppRouterTests {
  @Test func pushBuildsAPathAndPopToRootClearsIt() {
    let router = AppRouter()
    let id = UUID()
    router.push(.commute(id))
    router.push(.scheduleEditor(commute: id))
    #expect(router.path == [.commute(id), .scheduleEditor(commute: id)])
    router.popToRoot()
    #expect(router.path.isEmpty)
  }
}
