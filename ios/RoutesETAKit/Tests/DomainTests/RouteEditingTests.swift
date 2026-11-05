import Testing

@testable import Domain

struct RouteEditingTests {
  @Test func nextColorSkipsUsedOnesCaseInsensitively() {
    #expect(RoutePalette.nextColor(avoiding: []) == RoutePalette.colors[0])
    #expect(
      RoutePalette.nextColor(avoiding: [RoutePalette.colors[0].uppercased()])
        == RoutePalette.colors[1])
  }

  @Test func nextColorWrapsWhenEverythingIsUsed() {
    #expect(RoutePalette.nextColor(avoiding: RoutePalette.colors) == RoutePalette.colors[0])
  }

  @Test func addRouteNamesAndColorsSequentially() {
    var commute = Commute(name: "A")
    #expect(commute.addRoute() == 0)
    #expect(commute.addRoute() == 1)
    #expect(commute.routes.map(\.name) == ["Route 1", "Route 2"])
    #expect(commute.routes.map(\.color) == Array(RoutePalette.colors.prefix(2)))
    #expect(commute.validate().isEmpty)
  }

  @Test func addRouteNeverDuplicatesAnExistingName() {
    var commute = Commute(name: "A", routes: [RouteDef(name: "Route 2", color: "#000000")])
    commute.addRoute()
    #expect(commute.routes.map(\.name) == ["Route 2", "Route 3"])
    #expect(commute.validate().isEmpty)
  }

  @Test func routeNameProblems() {
    let commute = Commute(
      name: "A",
      routes: [
        RouteDef(name: "City", color: "#000000"), RouteDef(name: "Mordor", color: "#111111"),
      ]
    )
    #expect(commute.routeNameProblem("City", at: 0) == nil)  // unchanged is fine
    #expect(
      commute.routeNameProblem("Mordor", at: 0)
        == .duplicateRouteName(commute: "A", route: "Mordor"))
    #expect(commute.routeNameProblem("  ", at: 0) == .emptyRouteName(commute: "A"))
    #expect(commute.routeNameProblem(" Toll ", at: 0) == nil)
  }
}
