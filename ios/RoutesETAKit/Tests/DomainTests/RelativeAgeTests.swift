import Foundation
import Testing

@testable import Domain

struct RelativeAgeTests {
  private let start = Date(timeIntervalSince1970: 1_000_000)

  private func text(after seconds: Double, _ style: RelativeAge.Style = .full) -> String {
    RelativeAge.text(since: start, now: start.addingTimeInterval(seconds), style: style)
  }

  @Test func underASecondIsJustNow() {
    #expect(text(after: 0) == "just now")
    #expect(text(after: 0.9) == "just now")
  }

  @Test func aClockBehindTheFetchIsJustNow() {
    #expect(text(after: -5) == "just now")
  }

  @Test func secondsAreSingularOrPlural() {
    #expect(text(after: 1) == "1 second ago")
    #expect(text(after: 12.7) == "12 seconds ago")
    #expect(text(after: 59) == "59 seconds ago")
  }

  @Test func minutesAreSingularOrPlural() {
    #expect(text(after: 60) == "1 minute ago")
    #expect(text(after: 119) == "1 minute ago")
    #expect(text(after: 120) == "2 minutes ago")
    #expect(text(after: 3_599) == "59 minutes ago")
  }

  @Test func hoursAndDays() {
    #expect(text(after: 3_600) == "1 hour ago")
    #expect(text(after: 7_200) == "2 hours ago")
    #expect(text(after: 86_400) == "1 day ago")
    #expect(text(after: 3 * 86_400) == "3 days ago")
  }

  @Test func shortStyleFitsASmallScreen() {
    #expect(text(after: 0, .short) == "just now")
    #expect(text(after: 12, .short) == "12s ago")
    #expect(text(after: 60, .short) == "1 min ago")
    #expect(text(after: 7_200, .short) == "2 hr ago")
    #expect(text(after: 86_400, .short) == "1 d ago")
  }

  @Test func theTextChangesEverySecondInTheFirstMinute() {
    let now = start.addingTimeInterval(12.4)
    #expect(RelativeAge.nextChange(since: start, now: now) == start.addingTimeInterval(13))
  }

  @Test func theTextChangesEveryMinuteAfterThat() {
    let now = start.addingTimeInterval(61)
    #expect(RelativeAge.nextChange(since: start, now: now) == start.addingTimeInterval(120))
    let later = start.addingTimeInterval(3_000)
    #expect(RelativeAge.nextChange(since: start, now: later) == start.addingTimeInterval(3_060))
  }

  @Test func theTextChangesEveryHourAfterAnHour() {
    let now = start.addingTimeInterval(3_700)
    #expect(RelativeAge.nextChange(since: start, now: now) == start.addingTimeInterval(7_200))
  }

  @Test func theNextChangeIsAlwaysInTheFuture() {
    for age in stride(from: 0.0, through: 7_300.0, by: 0.5) {
      let now = start.addingTimeInterval(age)
      #expect(RelativeAge.nextChange(since: start, now: now) > now)
    }
  }

  @Test func theTextReallyChangesAtTheNextChange() {
    for age in [0.0, 12.4, 59.9, 61, 3_000, 3_700] {
      let now = start.addingTimeInterval(age)
      let next = RelativeAge.nextChange(since: start, now: now)
      #expect(RelativeAge.text(since: start, now: next) != RelativeAge.text(since: start, now: now))
    }
  }
}
