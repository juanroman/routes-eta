import Foundation

/// "12 seconds ago": how old the ETAs on screen are.
///
/// Written by hand rather than with `RelativeDateTimeFormatter`: the app is English-only, so the
/// text must not follow the device's language (a Spanish phone would show "hace 1 minuto" next
/// to an English screen), and exact strings keep the tests independent of the OS's ICU data.
public enum RelativeAge {
  public enum Style: Sendable {
    /// "1 minute ago".
    case full
    /// "1 min ago", for small screens.
    case short
  }

  public static func text(since date: Date, now: Date, style: Style = .full) -> String {
    let seconds = Int(max(0, now.timeIntervalSince(date)))
    if seconds < 1 { return "just now" }
    let (value, unit) = amount(seconds: seconds, style: style)
    switch style {
    case .full: return "\(value) \(unit)\(value == 1 ? "" : "s") ago"
    case .short: return "\(value)\(unit) ago"
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

  private static func amount(seconds: Int, style: Style) -> (Int, String) {
    let full = style == .full
    switch seconds {
    case ..<60: return (seconds, full ? "second" : "s")
    case ..<3_600: return (seconds / 60, full ? "minute" : " min")
    case ..<86_400: return (seconds / 3_600, full ? "hour" : " hr")
    default: return (seconds / 86_400, full ? "day" : " d")
    }
  }
}
