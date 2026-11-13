/// Persistence of the whole config (`GET`/`PUT /config` on the API).
public protocol ConfigRepository: Sendable {
  func load() async throws -> Config
  /// Throws `ConfigRepositoryError.invalid` when the config fails validation,
  /// like the API's 422.
  func save(_ config: Config) async throws
}

public enum ConfigRepositoryError: Error, Equatable, Sendable {
  case invalid([ConfigIssue])
}

/// A drawn route (`POST /preview`).
public struct RoutePreview: Hashable, Sendable {
  public var distanceMeters: Int
  public var polyline: [LatLng]

  public init(distanceMeters: Int, polyline: [LatLng]) {
    self.distanceMeters = distanceMeters
    self.polyline = polyline
  }
}

public protocol RoutePreviewService: Sendable {
  func preview(origin: LatLng, destination: LatLng, via: [LatLng]) async throws -> RoutePreview
}

/// What a drawn route depends on. Place labels are left out on purpose: renaming
/// "Home" must not throw away a line that still goes to the same coordinates.
public struct RouteLineKey: Hashable, Codable, Sendable {
  public var origin: LatLng
  public var destination: LatLng
  public var via: [LatLng]

  public init(origin: LatLng, destination: LatLng, via: [LatLng]) {
    self.origin = origin
    self.destination = destination
    self.via = via
  }
}

/// Remembers drawn routes so they don't have to be asked from Google again. A cache
/// is best effort: it never throws, and a failure to read or write is just a miss.
public protocol RouteLineCache: Sendable {
  func line(for key: RouteLineKey) async -> RoutePreview?
  func store(_ preview: RoutePreview, for key: RouteLineKey) async
}

/// One route's ETA. `minutes == nil` means this route failed (`error` says why).
public struct RouteETA: Hashable, Sendable {
  public var name: String
  public var minutes: Int?
  public var error: String?

  public init(name: String, minutes: Int?, error: String? = nil) {
    self.name = name
    self.minutes = minutes
    self.error = error
  }
}

/// Result of "send ETAs now" for one commute (`POST /run-now`).
public struct ETAReport: Hashable, Sendable {
  public var commute: String
  public var message: String
  public var results: [RouteETA]

  public init(commute: String, message: String, results: [RouteETA]) {
    self.commute = commute
    self.message = message
    self.results = results
  }
}

public enum ETAServiceError: Error, Equatable, Sendable {
  case unknownCommute(String)
  /// Missing origin, destination or routes; see `Commute.etaBlocker`.
  case notReady(String)
}

public protocol ETAService: Sendable {
  func run(commute: String) async throws -> ETAReport

  /// Traffic-aware minutes for one route, departing now: what the commute screen shows for the
  /// selected route. Throws when it can't be fetched.
  func minutes(
    for route: RouteDef, from origin: LatLng, to destination: LatLng
  ) async throws -> Int
}

/// Finds places to use as a commute's origin or destination, in two steps like
/// Calendar's Location field: cheap suggestions while typing, then resolving the
/// chosen one to coordinates. The real implementation uses MapKit.
public protocol PlaceSearchService: Sendable {
  /// An empty query returns no suggestions.
  func suggestions(for query: String) async throws -> [PlaceSuggestion]
  func resolve(_ suggestion: PlaceSuggestion) async throws -> NamedPoint
}

public enum PlaceSearchError: Error, Equatable, Sendable {
  case notFound
}

/// Where the user's "Home" and "Work" shortcuts are kept (on the device).
public protocol SavedPlacesRepository: Sendable {
  func load() async throws -> SavedPlaces
  func save(_ places: SavedPlaces) async throws
}
