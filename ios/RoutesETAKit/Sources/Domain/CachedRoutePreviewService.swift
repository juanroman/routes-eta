/// Asks the wrapped service only for lines the cache doesn't already have. An edit to
/// the origin, destination or via points changes the `RouteLineKey`, so it is a miss
/// and the stale line is simply never looked up again; nothing needs invalidating.
/// Failures are not cached, so a request that failed is tried again next time.
public struct CachedRoutePreviewService: RoutePreviewService {
  private let wrapped: any RoutePreviewService
  private let cache: any RouteLineCache

  public init(wrapping wrapped: any RoutePreviewService, cache: any RouteLineCache) {
    self.wrapped = wrapped
    self.cache = cache
  }

  public func preview(
    origin: LatLng, destination: LatLng, via: [LatLng]
  ) async throws -> RoutePreview {
    let key = RouteLineKey(origin: origin, destination: destination, via: via)
    if let cached = await cache.line(for: key) { return cached }
    let preview = try await wrapped.preview(origin: origin, destination: destination, via: via)
    await cache.store(preview, for: key)
    return preview
  }
}
