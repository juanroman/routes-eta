import Foundation

// Temporary instrumentation: see ios/tools/tap-study/REMOVING.md. Everything for the
// tap study lives in this directory, so deleting it (plus five tagged hook lines)
// removes the feature.

/// One thing the study recorded. Screen-space numbers only: no coordinates, place
/// names or route names, so an export is safe to share.
struct TapEvent: Codable, Equatable, Sendable {
  enum Kind: String, Codable, Sendable {
    /// A finger went down and came up on the map.
    case touch
    /// The map's own tap handler fired (the one that adds via points).
    case tap
    case viaAdded
    case viaRemoved
    case viaMoved
    /// The tester pressed "Tap didn't work".
    case flag
  }

  enum Screen: String, Codable, Sendable {
    case inline
    case full
  }

  /// Seconds since the app session started; no wall-clock time is stored.
  var time: Double
  var session: String
  var kind: Kind
  var screen: Screen
  /// How far the map is zoomed: metres on the ground per screen point.
  var metresPerPoint: Double?
  /// Points in the drawn route line (0 = nothing to hit).
  var vertices: Int
  var viaCount: Int
  /// Touch position in window points.
  var x: Double?
  var y: Double?
  /// At touch-down, in points.
  var distToLine: Double?
  var distToHandle: Double?
  var travel: Double?
  var duration: Double?
  /// True when the touch never reported an end (something else took it over).
  var cancelled: Bool?
}

/// What the observer knew about the map when a touch began.
struct TapStudyContext: Equatable, Sendable {
  var screen: TapEvent.Screen = .inline
  var metresPerPoint: Double?
  var vertices = 0
  var viaCount = 0
}

/// The measurements of one touch.
struct TapTouch: Equatable, Sendable {
  var distToLine: Double?
  var distToHandle: Double?
  var travel: Double?
  var duration: Double?
  var cancelled = false
}

/// The shareable file.
struct TapStudyExport: Codable, Equatable, Sendable {
  var schemaVersion = 1
  var app: String
  var device: String
  var os: String
  /// The tolerance the app used to decide a tap was "on the line".
  var hitRadiusPt: Double
  var events: [TapEvent]
}

enum TapStudyViaDiff {
  /// What an edit to the via list was; nil if nothing meaningful changed.
  static func kind<Element: Equatable>(from old: [Element], to new: [Element]) -> TapEvent.Kind? {
    if new.count == old.count + 1 { return .viaAdded }
    if new.count == old.count - 1 { return .viaRemoved }
    if new.count == old.count && new != old { return .viaMoved }
    return nil
  }
}
