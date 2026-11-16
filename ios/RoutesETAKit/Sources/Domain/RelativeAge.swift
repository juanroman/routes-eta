import Foundation

/// "12 seconds ago": how old the ETAs on screen are.
///
/// Written by hand rather than with `RelativeDateTimeFormatter`: the wording is ours (so the
/// Spanish matches the rest of the app's translation, "Actualizado hace 1 minuto"), and exact
/// strings keep the tests independent of the OS's ICU data. Every wording is its own string
/// (no plural variations) so the English key doubles as the fallback where no catalog is loaded.
public enum RelativeAge {
  public enum Style: Sendable {
    /// "1 minute ago".
    case full
    /// "1 min ago", for small screens.
    case short
  }

  public static func text(since date: Date, now: Date, style: Style = .full) -> String {
    let seconds = Int(max(0, now.timeIntervalSince(date)))
    if seconds < 1 { return String(localized: "just now") }
    switch style {
    case .full: return full(seconds: seconds)
    case .short: return short(seconds: seconds)
    }
  }

  /// When the text will next change, so a `TimelineView` redraws once per change and not
  /// more: every second for the first minute, then every minute, then every hour.
  public static func nextChange(since date: Date, now: Date) -> Date {
    let age = max(0, now.timeIntervalSince(date))
    let step: Double
    switch age {
    case ..<60: step = 1
    case ..<3_600: step = 60
    default: step = 3_600
    }
    return date.addingTimeInterval((age / step).rounded(.down) * step + step)
  }

  private static func full(seconds: Int) -> String {
    switch seconds {
    case ..<60:
      return seconds == 1
        ? String(localized: "1 second ago") : String(localized: "\(seconds) seconds ago")
    case ..<3_600:
      let minutes = seconds / 60
      return minutes == 1
        ? String(localized: "1 minute ago") : String(localized: "\(minutes) minutes ago")
    case ..<86_400:
      let hours = seconds / 3_600
      return hours == 1
        ? String(localized: "1 hour ago") : String(localized: "\(hours) hours ago")
    default:
      let days = seconds / 86_400
      return days == 1 ? String(localized: "1 day ago") : String(localized: "\(days) days ago")
    }
  }

  private static func short(seconds: Int) -> String {
    switch seconds {
    case ..<60: String(localized: "\(seconds)s ago")
    case ..<3_600: String(localized: "\(seconds / 60) min ago")
    case ..<86_400: String(localized: "\(seconds / 3_600) hr ago")
    default: String(localized: "\(seconds / 86_400) d ago")
    }
  }
}
