import Testing

@testable import Domain

struct ValidationTests {
  private func commute(
    name: String = "A", routes: [RouteDef] = [], schedules: [ScheduleRule] = []
  ) -> Commute {
    Commute(name: name, routes: routes, schedules: schedules)
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

  @Test(arguments: ["24:00", "6:30", "06:60", "0630", "06:3", "ab:cd", "", "06:30:00"])
  func rejectsBadTimes(time: String) {
    let issues = commute(schedules: [ScheduleRule(weekdays: [.mon], time: time)]).validate()
    #expect(issues == [.invalidTime(commute: "A", time: time)])
  }

  @Test(arguments: ["00:00", "07:30", "23:59"])
  func acceptsGoodTimes(time: String) {
    #expect(commute(schedules: [ScheduleRule(weekdays: [.mon], time: time)]).validate().isEmpty)
  }

  @Test func rejectsWeekdayInTwoRules() {
    let rules = [
      ScheduleRule(weekdays: [.mon, .tue], time: "06:30"),
      ScheduleRule(weekdays: [.tue], time: "07:30"),
    ]
    #expect(
      commute(schedules: rules).validate()
        == [.weekdayScheduledTwice(commute: "A", weekday: .tue)])
  }

  @Test func rejectsRuleWithNoWeekdays() {
    #expect(
      commute(schedules: [ScheduleRule(weekdays: [])]).validate()
        == [.emptyWeekdays(commute: "A")])
  }

  @Test func rejectsOutOfRangeCoordinates() {
    var bad = commute()
    bad.origin = NamedPoint(label: "X", lat: 91, lng: 0)
    #expect(bad.validate() == [.invalidCoordinate(commute: "A", what: "Origin")])
  }
}
