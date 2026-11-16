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
    return issues + routeIssues()
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

  /// `^#[0-9a-fA-F]{6}$`
  static func isValidColor(_ value: String) -> Bool {
    let chars = Array(value)
    return chars.count == 7 && chars[0] == "#" && chars.dropFirst().allSatisfy(\.isHexDigit)
  }
}

extension LatLng {
  var isValid: Bool { (-90...90).contains(lat) && (-180...180).contains(lng) }
}
