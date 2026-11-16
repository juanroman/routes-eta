import Testing

@testable import Domain

struct ValidationTests {
  private func commute(
    name: String = "A", routes: [RouteDef] = []
  ) -> Commute {
    Commute(name: name, routes: routes)
  }

  @Test func emptyConfigIsValid() {
    #expect(Config().validate().isEmpty)
  }

  @Test func rejectsBlankAndDuplicateCommuteNames() {
    let config = Config(commutes: [commute(name: "A"), commute(name: "A"), commute(name: "  ")])
    let issues = config.validate()
    #expect(issues.contains(.duplicateCommuteName("A")))
    #expect(issues.contains(.emptyCommuteName))
  }

  @Test func rejectsDuplicateRouteNamesWithinACommute() {
    let routes = [
      RouteDef(name: "City", color: "#000000"), RouteDef(name: "City", color: "#ffffff"),
    ]
    #expect(
      commute(routes: routes).validate()
        == [.duplicateRouteName(commute: "A", route: "City")])
  }

  @Test func sameRouteNameInDifferentCommutesIsFine() {
    let route = RouteDef(name: "City", color: "#000000")
    let config = Config(commutes: [
      commute(name: "A", routes: [route]), commute(name: "B", routes: [route]),
    ])
    #expect(config.validate().isEmpty)
  }

  @Test(arguments: ["#12345", "123456", "#12345g", "#1234567", ""])
  func rejectsBadColors(color: String) {
    let issues = commute(routes: [RouteDef(name: "R", color: color)]).validate()
    #expect(issues == [.invalidColor(commute: "A", route: "R")])
  }

  @Test func acceptsUpperAndLowerHexColors() {
    #expect(commute(routes: [RouteDef(name: "R", color: "#aBc012")]).validate().isEmpty)
  }

  @Test func capsViaPoints() {
    let via = Array(repeating: LatLng(lat: 0, lng: 0), count: maxViaPoints + 1)
    let ok = Array(via.dropLast())
    #expect(
      commute(routes: [RouteDef(name: "R", color: "#000000", via: via)]).validate()
        == [.tooManyViaPoints(commute: "A", route: "R")])
    #expect(commute(routes: [RouteDef(name: "R", color: "#000000", via: ok)]).validate().isEmpty)
  }

  @Test func rejectsOutOfRangeCoordinates() {
    var bad = commute()
    bad.origin = NamedPoint(label: "X", lat: 91, lng: 0)
    #expect(bad.validate() == [.invalidCoordinate(commute: "A", what: "Origin")])
  }
}
