import Testing

@testable import Domain

struct ScheduleEditingTests {
  private func commute(_ rules: [ScheduleRule]) -> Commute {
    Commute(name: "A", schedules: rules)
  }

  @Test func firstRuleDefaultsToWorkdays() {
    var commute = commute([])
    #expect(commute.addScheduleRule() == 0)
    #expect(commute.schedules[0].weekdays == [.mon, .tue, .wed, .thu, .fri])
    #expect(commute.validate().isEmpty)
  }

  @Test func newRuleTakesOnlyTheFreeDays() {
    var commute = commute([ScheduleRule(weekdays: [.mon], time: "06:30")])
    #expect(commute.addScheduleRule() == 1)
    #expect(commute.schedules[1].weekdays == [.tue, .wed, .thu, .fri])
    #expect(commute.validate().isEmpty)
  }

  @Test func weekendOnlyWhenWorkdaysAreTaken() {
    var commute = commute([ScheduleRule(weekdays: [.mon, .tue, .wed, .thu, .fri])])
    commute.addScheduleRule()
    #expect(commute.schedules[1].weekdays == [.sat])
  }

  @Test func noRuleCanBeAddedWhenEveryDayIsTaken() {
    var commute = commute([ScheduleRule(weekdays: Weekday.allCases)])
    #expect(commute.addScheduleRule() == nil)
    #expect(commute.schedules.count == 1)
  }

  @Test func cannotTurnOnADayAnotherRuleOwns() {
    var commute = commute([
      ScheduleRule(weekdays: [.mon]), ScheduleRule(weekdays: [.tue]),
    ])
    #expect(commute.canToggle(.mon, inRuleAt: 1) == false)
    #expect(commute.toggle(.mon, inRuleAt: 1) == false)
    #expect(commute.schedules[1].weekdays == [.tue])
  }

  @Test func cannotTurnOffTheLastDay() {
    var commute = commute([ScheduleRule(weekdays: [.mon])])
    #expect(commute.toggle(.mon, inRuleAt: 0) == false)
    #expect(commute.schedules[0].weekdays == [.mon])
  }

  @Test func togglingKeepsWeekOrder() {
    var commute = commute([ScheduleRule(weekdays: [.fri, .mon])])
    let changedWed = commute.toggle(.wed, inRuleAt: 0)
    #expect(changedWed)
    #expect(commute.schedules[0].weekdays == [.mon, .wed, .fri])
    let changedMon = commute.toggle(.mon, inRuleAt: 0)
    #expect(changedMon)
    #expect(commute.schedules[0].weekdays == [.wed, .fri])
  }

  @Test func timeHelpersRoundTrip() {
    var rule = ScheduleRule(weekdays: [.mon], time: "07:05")
    #expect(rule.hour == 7 && rule.minute == 5)
    rule.setTime(hour: 6, minute: 30)
    #expect(rule.time == "06:30")
    rule.setTime(hour: 18, minute: 0)
    #expect(rule.time == "18:00")
  }
}
