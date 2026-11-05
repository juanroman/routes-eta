import Testing

@testable import Domain

struct ScheduleSummaryTests {
  @Test func singleDay() {
    #expect(ScheduleRule(weekdays: [.mon], time: "06:30").summary == "Mon · 06:30")
  }

  @Test func runOfThreeOrMoreCollapses() {
    #expect(
      ScheduleRule(weekdays: [.mon, .tue, .wed, .thu, .fri], time: "18:30").summary
        == "Mon–Fri · 18:30")
    #expect(
      ScheduleRule(weekdays: [.tue, .wed, .thu, .fri], time: "07:30").summary
        == "Tue–Fri · 07:30")
  }

  @Test func shortRunsAreListed() {
    #expect(ScheduleRule(weekdays: [.mon, .tue], time: "08:00").summary == "Mon, Tue · 08:00")
  }

  @Test func unorderedInputIsSortedAndMixedRunsWork() {
    #expect(
      ScheduleRule(weekdays: [.sun, .wed, .mon, .tue, .thu], time: "09:00").summary
        == "Mon–Thu, Sun · 09:00")
  }
}
