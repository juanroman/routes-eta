import Domain

/// Keeps drawn routes in memory for the app's lifetime (lost on relaunch).
public actor InMemoryRouteLineCache: RouteLineCache {
  private var lines: [RouteLineKey: RoutePreview] = [:]

  public init() {}

  public func line(for key: RouteLineKey) async -> RoutePreview? { lines[key] }

  public func store(_ preview: RoutePreview, for key: RouteLineKey) async {
    lines[key] = preview
  }
}
