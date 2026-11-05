import Foundation

/// Google's computeRoutes allows 25 intermediates; the API reserves two.
public let maxViaPoints = 23

/// One thing wrong with a config. Mirrors the validators in
/// `api/app/config_models.py` so the app rejects what the API would (HTTP 422).
public enum ConfigIssue: Hashable, Sendable, CustomStringConvertible {
  case emptyCommuteName
  case duplicateCommuteName(String)
  case emptyRouteName(commute: String)
  case duplicateRouteName(commute: String, route: String)
  case invalidColor(commute: String, route: String)
  case tooManyViaPoints(commute: String, route: String)
  case invalidCoordinate(commute: String, what: String)
  case emptyWeekdays(commute: String)
  case invalidTime(commute: String, time: String)
  case weekdayScheduledTwice(commute: String, weekday: Weekday)

  public var description: String {
    switch self {
    case .emptyCommuteName:
      "A commute needs a name."
    case .duplicateCommuteName(let name):
      "There is already a commute named \"\(name)\"."
    case .emptyRouteName(let commute):
      "A route in \"\(commute)\" needs a name."
    case .duplicateRouteName(_, let route):
      "There is already a route named \"\(route)\" in this commute."
    case .invalidColor(_, let route):
      "Route \"\(route)\" has an invalid color."
    case .tooManyViaPoints(_, let route):
      "Route \"\(route)\" has more than \(maxViaPoints) via points."
    case .invalidCoordinate(_, let what):
      "\(what) has an invalid coordinate."
    case .emptyWeekdays:
      "A schedule needs at least one weekday."
    case .invalidTime(_, let time):
      "\"\(time)\" is not a valid time (use HH:MM, 24-hour)."
    case .weekdayScheduledTwice(_, let weekday):
      "\(weekday.shortName) is scheduled by more than one rule."
    }
  }
}

extension Config {
  public func validate() -> [ConfigIssue] {
    var issues: [ConfigIssue] = []
    var seen = Set<String>()
    for commute in commutes {
      if !seen.insert(commute.name).inserted {
        issues.append(.duplicateCommuteName(commute.name))
      }
      issues += commute.validate()
    }
    return issues
  }
}

extension Commute {
  public func validate() -> [ConfigIssue] {
    var issues: [ConfigIssue] = []
    if name.trimmingCharacters(in: .whitespaces).isEmpty { issues.append(.emptyCommuteName) }
    if let origin, !origin.latLng.isValid {
      issues.append(.invalidCoordinate(commute: name, what: "Origin"))
    }
    if let destination, !destination.latLng.isValid {
      issues.append(.invalidCoordinate(commute: name, what: "Destination"))
    }
    return issues + routeIssues() + scheduleIssues()
  }

  private func routeIssues() -> [ConfigIssue] {
    var issues: [ConfigIssue] = []
    var routeNames = Set<String>()
    for route in routes {
      if route.name.trimmingCharacters(in: .whitespaces).isEmpty {
        issues.append(.emptyRouteName(commute: name))
      } else if !routeNames.insert(route.name).inserted {
        issues.append(.duplicateRouteName(commute: name, route: route.name))
      }
      if !Self.isValidColor(route.color) {
        issues.append(.invalidColor(commute: name, route: route.name))
      }
      if route.via.count > maxViaPoints {
        issues.append(.tooManyViaPoints(commute: name, route: route.name))
      }
      if route.via.contains(where: { !$0.isValid }) {
        issues.append(.invalidCoordinate(commute: name, what: "A via point of \"\(route.name)\""))
      }
    }
    return issues
  }

  private func scheduleIssues() -> [ConfigIssue] {
    var issues: [ConfigIssue] = []
    var scheduledDays = Set<Weekday>()
    for rule in schedules {
      if rule.weekdays.isEmpty { issues.append(.emptyWeekdays(commute: name)) }
      if !Self.isValidTime(rule.time) {
        issues.append(.invalidTime(commute: name, time: rule.time))
      }
      for day in rule.weekdays where !scheduledDays.insert(day).inserted {
        issues.append(.weekdayScheduledTwice(commute: name, weekday: day))
      }
    }
    return issues
  }

  /// `^#[0-9a-fA-F]{6}$`
  static func isValidColor(_ value: String) -> Bool {
    let chars = Array(value)
    return chars.count == 7 && chars[0] == "#" && chars.dropFirst().allSatisfy(\.isHexDigit)
  }

  /// `^([01]\d|2[0-3]):[0-5]\d$`
  static func isValidTime(_ value: String) -> Bool {
    let parts = value.split(separator: ":", omittingEmptySubsequences: false)
    guard parts.count == 2, parts[0].count == 2, parts[1].count == 2,
      let hour = Int(parts[0]), let minute = Int(parts[1]),
      parts.allSatisfy({ $0.allSatisfy(\.isASCII) })
    else { return false }
    return (0...23).contains(hour) && (0...59).contains(minute)
  }
}

extension LatLng {
  var isValid: Bool { (-90...90).contains(lat) && (-180...180).contains(lng) }
}
