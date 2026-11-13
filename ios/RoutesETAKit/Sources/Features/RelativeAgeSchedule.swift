import Domain
import SwiftUI

/// Redraws a `TimelineView` exactly when "Updated 12 seconds ago" would read differently: every
/// second for the first minute, every minute after that, every hour after the first hour.
struct RelativeAgeSchedule: TimelineSchedule {
  let since: Date

  func entries(from startDate: Date, mode: Mode) -> UnfoldFirstSequence<Date> {
    sequence(first: startDate) { RelativeAge.nextChange(since: since, now: $0) }
  }
}
