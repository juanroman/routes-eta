import Testing

@testable import Domain

struct ETAReportBuilderTests {
  @Test func messageListsRoutesInOrderWithQuestionMarkForFailures() {
    let report = ETAReport(
      commute: "Work to Home",
      results: [
        RouteETA(name: "City", minutes: 31),
        RouteETA(name: "Mordor", minutes: nil, error: "x"),
      ])
    #expect(report.message == "Work to Home: City 31 · Mordor ?")
  }

  @Test func allFailedUsesTheFailureText() {
    let report = ETAReport(
      commute: "C", results: [RouteETA(name: "A", minutes: nil, error: "x")])
    #expect(report.message == "C: Couldn't fetch ETAs")
  }

  @Test func minutesRoundHalfToEvenLikePython() {
    #expect(RouteETA.minutes(fromSeconds: 1770) == 30)  // 29.5 -> 30
    #expect(RouteETA.minutes(fromSeconds: 1710) == 28)  // 28.5 -> 28
    #expect(RouteETA.minutes(fromSeconds: 1800) == 30)
    #expect(RouteETA.minutes(fromSeconds: 29) == 0)
    #expect(RouteETA.minutes(fromSeconds: 31) == 1)
  }
}
