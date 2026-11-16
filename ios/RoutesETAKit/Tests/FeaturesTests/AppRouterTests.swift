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
    router.push(.routeEditor(commute: id, route: 0))
    #expect(router.path == [.commute(id), .routeEditor(commute: id, route: 0)])
    router.popToRoot()
    #expect(router.path.isEmpty)
  }
}
