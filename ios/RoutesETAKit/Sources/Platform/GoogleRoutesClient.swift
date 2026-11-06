import Domain
import Foundation

/// Why a Google Routes request failed, with a message fit to show the user.
public enum GoogleRoutesError: Error, Equatable, LocalizedError {
  case missingKey(GoogleAPIKey.Failure)
  case network
  case http(status: Int, message: String)
  case badResponse(String)

  public var errorDescription: String? {
    switch self {
    case .missingKey(let failure):
      failure.errorDescription
    case .network:
      "Couldn't reach Google. Check your connection and try again."
    case .http(let status, let message):
      switch status {
      case 400: "Google couldn't route that: \(message)"
      case 401, 403: "Google rejected the API key. Check its restrictions. (\(message))"
      case 429: "Google's request limit was reached. Try again later."
      default: "Google returned an error (\(status)): \(message)"
      }
    case .badResponse(let detail):
      "Google sent a response the app couldn't read (\(detail))."
    }
  }
}

/// Thin client for Google's Routes API `computeRoutes`, ported from
/// `api/app/google_routes_client.py` so the app and the Pi's checker ask the
/// same question and get the same answer: same endpoint, field masks, `via`
/// intermediates, and traffic-aware duration. No SDK, plain REST.
public struct GoogleRoutesClient: Sendable {
  public static let endpoint = URL(
    string: "https://routes.googleapis.com/directions/v2:computeRoutes")!
  static let previewFieldMask = "routes.distanceMeters,routes.polyline.encodedPolyline"
  static let durationFieldMask = "routes.duration"
  static let trafficAware = "TRAFFIC_AWARE"
  static let timeout: TimeInterval = 15

  private let session: URLSession
  /// Read on every call, so a missing key surfaces as an error at use time (with
  /// instructions) rather than crashing at launch.
  private let apiKey: @Sendable () throws -> String
  private let bundleIdentifier: String?

  public init(
    session: URLSession = .shared,
    apiKey: @escaping @Sendable () throws -> String = { try GoogleAPIKey.load() },
    bundleIdentifier: String? = Bundle.main.bundleIdentifier
  ) {
    self.session = session
    self.apiKey = apiKey
    self.bundleIdentifier = bundleIdentifier
  }

  /// Fails with `missingKey` before any request is made.
  public func validateKey() throws {
    _ = try resolveKey()
  }

  public func previewRoute(
    origin: LatLng, destination: LatLng, via: [LatLng]
  ) async throws -> RoutePreview {
    let route = try await send(
      GoogleWire.Body(origin: origin, destination: destination, via: via, routingPreference: nil),
      fieldMask: Self.previewFieldMask)
    guard let encoded = route.polyline?.encodedPolyline else {
      throw GoogleRoutesError.badResponse("no polyline")
    }
    do {
      return RoutePreview(
        distanceMeters: route.distanceMeters ?? 0, polyline: try PolylineCodec.decode(encoded))
    } catch {
      throw GoogleRoutesError.badResponse("malformed polyline")
    }
  }

  /// Traffic-aware driving time in seconds, departing now.
  public func routeDurationSeconds(
    origin: LatLng, destination: LatLng, via: [LatLng]
  ) async throws -> Int {
    let route = try await send(
      GoogleWire.Body(
        origin: origin, destination: destination, via: via, routingPreference: Self.trafficAware),
      fieldMask: Self.durationFieldMask)
    // Google encodes durations as "1234s".
    guard let raw = route.duration, raw.hasSuffix("s"), let seconds = Int(raw.dropLast()) else {
      throw GoogleRoutesError.badResponse("missing duration")
    }
    return seconds
  }

  // MARK: Request

  private func resolveKey() throws -> String {
    do {
      return try apiKey()
    } catch let failure as GoogleAPIKey.Failure {
      throw GoogleRoutesError.missingKey(failure)
    }
  }

  private func send(_ body: GoogleWire.Body, fieldMask: String) async throws
    -> GoogleWire.Route
  {
    let key = try resolveKey()

    var request = URLRequest(url: Self.endpoint, timeoutInterval: Self.timeout)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(key, forHTTPHeaderField: "X-Goog-Api-Key")
    request.setValue(fieldMask, forHTTPHeaderField: "X-Goog-FieldMask")
    // Lets a key restricted to this iOS app's bundle ID be accepted.
    if let bundleIdentifier {
      request.setValue(bundleIdentifier, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
    }
    request.httpBody = try JSONEncoder().encode(body)

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await session.data(for: request)
    } catch let error as URLError where error.code != .cancelled {
      throw GoogleRoutesError.network
    }

    guard let status = (response as? HTTPURLResponse)?.statusCode else {
      throw GoogleRoutesError.badResponse("no HTTP status")
    }
    guard status == 200 else {
      throw GoogleRoutesError.http(status: status, message: Self.errorMessage(in: data))
    }
    guard let route = try? JSONDecoder().decode(GoogleWire.Envelope.self, from: data).routes?.first
    else {
      throw GoogleRoutesError.badResponse("no route")
    }
    return route
  }

  /// Google's `{"error": {"message": ...}}`, shortened; never the raw body, which
  /// could echo request details.
  static func errorMessage(in data: Data) -> String {
    let message =
      (try? JSONDecoder().decode(GoogleWire.ErrorEnvelope.self, from: data))?.error?.message
      ?? String(bytes: data.prefix(160), encoding: .utf8) ?? ""
    return String(message.split(whereSeparator: \.isWhitespace).joined(separator: " ").prefix(160))
  }
}
