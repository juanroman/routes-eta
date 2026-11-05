import Foundation

/// Route colors offered by the editor; the same set as the web builder.
public enum RoutePalette {
  public static let colors = [
    "#2563eb", "#dc2626", "#16a34a", "#d97706", "#7c3aed", "#0891b2",
  ]

  /// First palette color not in `used`, falling back to the first one.
  public static func nextColor(avoiding used: [String]) -> String {
    let taken = Set(used.map { $0.lowercased() })
    return colors.first { !taken.contains($0) } ?? colors[0]
  }
}

extension Commute {
  /// Appends a new route named "Route N" (first free N) in the next unused
  /// palette color, and returns its index.
  @discardableResult
  public mutating func addRoute() -> Int {
    let names = Set(routes.map(\.name))
    var number = routes.count + 1
    while names.contains("Route \(number)") { number += 1 }
    routes.append(
      RouteDef(
        name: "Route \(number)", color: RoutePalette.nextColor(avoiding: routes.map(\.color))))
    return routes.count - 1
  }

  /// Why `name` can't be used for the route at `index`, or nil if it's fine.
  public func routeNameProblem(_ name: String, at index: Int) -> ConfigIssue? {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    if trimmed.isEmpty { return .emptyRouteName(commute: self.name) }
    let taken = routes.enumerated().contains { $0.offset != index && $0.element.name == trimmed }
    return taken ? .duplicateRouteName(commute: self.name, route: trimmed) : nil
  }
}
