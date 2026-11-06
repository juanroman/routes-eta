import Domain

/// JSON shapes for `computeRoutes`, kept apart from the client. Only the fields
/// the app asks for (via the field mask) are decoded.
enum GoogleWire {
  struct Body: Encodable {
    var origin: Waypoint
    var destination: Waypoint
    var intermediates: [Waypoint]
    var travelMode = "DRIVE"
    var routingPreference: String?

    init(origin: LatLng, destination: LatLng, via: [LatLng], routingPreference: String?) {
      self.origin = Waypoint(origin, via: false)
      self.destination = Waypoint(destination, via: false)
      self.intermediates = via.map { Waypoint($0, via: true) }
      self.routingPreference = routingPreference
    }
  }

  struct Waypoint: Encodable {
    var location: Location
    /// `true` makes the route pass through the point without stopping; omitted otherwise.
    var via: Bool?

    init(_ point: LatLng, via isVia: Bool) {
      location = Location(latLng: Coordinates(latitude: point.lat, longitude: point.lng))
      via = isVia ? true : nil
    }
  }

  struct Location: Encodable {
    var latLng: Coordinates
  }

  struct Coordinates: Encodable {
    var latitude: Double
    var longitude: Double
  }

  struct Envelope: Decodable {
    var routes: [Route]?
  }

  struct Route: Decodable {
    var distanceMeters: Int?
    var duration: String?
    var polyline: Polyline?
  }

  struct Polyline: Decodable {
    var encodedPolyline: String?
  }

  struct ErrorEnvelope: Decodable {
    var error: ErrorDetail?
  }

  struct ErrorDetail: Decodable {
    var message: String?
  }
}
