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
}

public protocol ETAService: Sendable {
  func run(commute: String) async throws -> ETAReport
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
