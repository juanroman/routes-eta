/// Mirrors `api/app/config_models.py`. The JSON keys are identical, so no
/// key-mapping is needed; `fixtures/sample-config.json` is the shared contract.

public enum Weekday: String, Codable, CaseIterable, Hashable, Sendable {
  case mon, tue, wed, thu, fri, sat, sun
}

public struct LatLng: Codable, Hashable, Sendable {
  public var lat: Double
  public var lng: Double

  public init(lat: Double, lng: Double) {
    self.lat = lat
    self.lng = lng
  }
}

/// A `LatLng` with a human label. Flat on the wire (`label`, `lat`, `lng`).
public struct NamedPoint: Codable, Hashable, Sendable {
  public var label: String
  public var lat: Double
  public var lng: Double

  public init(label: String, lat: Double, lng: Double) {
    self.label = label
    self.lat = lat
    self.lng = lng
  }

  public var latLng: LatLng { LatLng(lat: lat, lng: lng) }
}

public struct RouteDef: Codable, Hashable, Sendable {
  public var name: String
  /// `#RRGGBB`.
  public var color: String
  public var via: [LatLng]

  public init(name: String, color: String, via: [LatLng] = []) {
    self.name = name
    self.color = color
    self.via = via
  }
}

public struct ScheduleRule: Codable, Hashable, Sendable {
  public var weekdays: [Weekday]
  /// `HH:MM`, 24-hour, local time in `Config.timezone`.
  public var time: String

  public init(weekdays: [Weekday], time: String = "18:30") {
    self.weekdays = weekdays
    self.time = time
  }
}

public struct Commute: Codable, Hashable, Sendable {
  public var name: String
  public var origin: NamedPoint?
  public var destination: NamedPoint?
  public var routes: [RouteDef]
  public var schedules: [ScheduleRule]

  public init(
    name: String,
    origin: NamedPoint? = nil,
    destination: NamedPoint? = nil,
    routes: [RouteDef] = [],
    schedules: [ScheduleRule] = []
  ) {
    self.name = name
    self.origin = origin
    self.destination = destination
    self.routes = routes
    self.schedules = schedules
  }
}

public struct Config: Codable, Hashable, Sendable {
  public var timezone: String
  public var commutes: [Commute]

  public init(timezone: String = "America/Mexico_City", commutes: [Commute] = []) {
    self.timezone = timezone
    self.commutes = commutes
  }
}
