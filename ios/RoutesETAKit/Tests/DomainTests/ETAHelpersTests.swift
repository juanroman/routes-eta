import Testing

@testable import Domain

struct ETAHelpersTests {
  private func report(_ results: [RouteETA]) -> ETAReport {
    ETAReport(commute: "C", message: "", results: results)
  }

  @Test func fastestSkipsFailedRoutes() {
    let report = report([
      RouteETA(name: "A", minutes: 40),
      RouteETA(name: "B", minutes: nil, error: "x"),
      RouteETA(name: "C", minutes: 31),
    ])
    #expect(report.fastestRouteName == "C")
    #expect(report.allFailed == false)
  }

  @Test func allFailedWhenNoRouteHasMinutes() {
    let report = report([RouteETA(name: "A", minutes: nil, error: "x")])
    #expect(report.allFailed)
    #expect(report.fastestRouteName == nil)
  }

  @Test func noResultsIsNotAFailure() {
    #expect(report([]).allFailed == false)
  }

  @Test func blockerExplainsWhatIsMissing() {
    let point = NamedPoint(label: "X", lat: 0, lng: 0)
    let route = RouteDef(name: "R", color: "#000000")
    #expect(Commute(name: "A").etaBlocker == "Set origin and destination first")
    #expect(Commute(name: "A", origin: point).etaBlocker == "Set origin and destination first")
    #expect(Commute(name: "A", origin: point, destination: point).etaBlocker == "Add a route first")
    #expect(
      Commute(name: "A", origin: point, destination: point, routes: [route]).etaBlocker == nil)
  }
}
