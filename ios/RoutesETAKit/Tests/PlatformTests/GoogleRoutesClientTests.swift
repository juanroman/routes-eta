import Domain
import Foundation
import Testing

@testable import Platform

/// A `URLProtocol` that answers from an in-memory handler instead of the network.
/// Each test registers its handler under its own id (sent as a session header) so
/// tests can run in parallel.
class StubURLProtocol: URLProtocol, @unchecked Sendable {
  typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

  private static let lock = NSLock()
  nonisolated(unsafe) private static var handlers: [String: Handler] = [:]

  static func register(_ handler: @escaping Handler) -> String {
    let id = UUID().uuidString
    lock.withLock { handlers[id] = handler }
    return id
  }

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    let id = request.value(forHTTPHeaderField: "X-Test-ID") ?? ""
    guard let handler = Self.lock.withLock({ Self.handlers[id] }) else {
      client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
      return
    }
    do {
      let (response, data) = try handler(request)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}

enum Stub {
  static func session(_ handler: @escaping StubURLProtocol.Handler) -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    configuration.httpAdditionalHeaders = ["X-Test-ID": StubURLProtocol.register(handler)]
    return URLSession(configuration: configuration)
  }

  static func respond(_ status: Int, _ body: String, for request: URLRequest)
    -> (HTTPURLResponse, Data)
  {
    let url = request.url ?? GoogleRoutesClient.endpoint
    let response = HTTPURLResponse(
      url: url, statusCode: status, httpVersion: nil, headerFields: nil)
    return (response ?? HTTPURLResponse(), Data(body.utf8))
  }

  /// Request body as JSON, for assertions.
  static func json(_ request: URLRequest) throws -> [String: Any] {
    var data = request.httpBody
    if data == nil, let stream = request.httpBodyStream {
      stream.open()
      defer { stream.close() }
      var collected = Data()
      var buffer = [UInt8](repeating: 0, count: 4096)
      while stream.hasBytesAvailable {
        let count = stream.read(&buffer, maxLength: buffer.count)
        if count <= 0 { break }
        collected.append(buffer, count: count)
      }
      data = collected
    }
    let object = try JSONSerialization.jsonObject(with: try #require(data))
    return try #require(object as? [String: Any])
  }
}

struct GoogleRoutesClientTests {
  private let origin = LatLng(lat: 19.4284, lng: -99.1677)
  private let destination = LatLng(lat: 19.5095, lng: -99.2383)
  private let via = [LatLng(lat: 19.455, lng: -99.205)]
  private let previewJSON = """
    {"routes":[{"distanceMeters":12345,
    "polyline":{"encodedPolyline":"_p~iF~ps|U_ulLnnqC_mqNvxq`@"}}]}
    """

  private func client(
    key: @escaping @Sendable () throws -> String = { "test-key" },
    handler: @escaping StubURLProtocol.Handler
  ) -> GoogleRoutesClient {
    GoogleRoutesClient(
      session: Stub.session(handler), apiKey: key, bundleIdentifier: "com.example.app")
  }

  @Test func previewSendsTheSameRequestAsThePythonClient() async throws {
    let captured = LockedBox<URLRequest?>(nil)
    let client = client { request in
      captured.value = request
      return Stub.respond(200, previewJSON, for: request)
    }
    _ = try await client.previewRoute(origin: origin, destination: destination, via: via)

    let request = try #require(captured.value)
    #expect(request.url == GoogleRoutesClient.endpoint)
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "X-Goog-Api-Key") == "test-key")
    #expect(
      request.value(forHTTPHeaderField: "X-Goog-FieldMask")
        == "routes.distanceMeters,routes.polyline.encodedPolyline")
    #expect(request.value(forHTTPHeaderField: "X-Ios-Bundle-Identifier") == "com.example.app")
    #expect(request.timeoutInterval == 15)

    let body = try Stub.json(request)
    #expect(body["travelMode"] as? String == "DRIVE")
    #expect(body["routingPreference"] == nil)  // no traffic model for the drawing

    let originBody = try #require(body["origin"] as? [String: Any])
    #expect(originBody["via"] == nil)
    let latLng =
      try #require((originBody["location"] as? [String: Any])?["latLng"] as? [String: Double])
    #expect(latLng["latitude"] == 19.4284)
    #expect(latLng["longitude"] == -99.1677)

    let intermediates = try #require(body["intermediates"] as? [[String: Any]])
    #expect(intermediates.count == 1)
    #expect(intermediates[0]["via"] as? Bool == true)  // pass through, don't stop
  }

  @Test func previewDecodesTheLineAndDistance() async throws {
    let client = client { Stub.respond(200, previewJSON, for: $0) }
    let preview = try await client.previewRoute(origin: origin, destination: destination, via: [])
    #expect(preview.distanceMeters == 12345)
    #expect(preview.polyline.count == 3)
    #expect(preview.polyline[0] == LatLng(lat: 38.5, lng: -120.2))
  }

  @Test func durationAsksForTrafficAwareAndParsesSeconds() async throws {
    let captured = LockedBox<URLRequest?>(nil)
    let client = client { request in
      captured.value = request
      return Stub.respond(200, #"{"routes":[{"duration":"1830s"}]}"#, for: request)
    }
    let seconds = try await client.routeDurationSeconds(
      origin: origin, destination: destination, via: via)
    #expect(seconds == 1830)

    let request = try #require(captured.value)
    #expect(request.value(forHTTPHeaderField: "X-Goog-FieldMask") == "routes.duration")
    #expect(try Stub.json(request)["routingPreference"] as? String == "TRAFFIC_AWARE")
  }

  @Test(arguments: [
    #"{"routes":[{"duration":"abc"}]}"#, #"{"routes":[{}]}"#, #"{"routes":[]}"#, #"{}"#,
    "not json",
  ])
  func malformedDurationResponsesAreBadResponses(body: String) async {
    let client = client { Stub.respond(200, body, for: $0) }
    await #expect(throws: GoogleRoutesError.self) {
      try await client.routeDurationSeconds(origin: origin, destination: destination, via: [])
    }
  }

  @Test func googleErrorsCarryTheirMessage() async {
    let body = #"{"error":{"code":403,"message":"API key not valid.\n  Please pass a valid key."}}"#
    let client = client { Stub.respond(403, body, for: $0) }
    await #expect(
      throws: GoogleRoutesError.http(
        status: 403, message: "API key not valid. Please pass a valid key.")
    ) {
      try await client.previewRoute(origin: origin, destination: destination, via: [])
    }
  }

  @Test func nonJSONErrorBodiesAreShortenedNotEchoed() async throws {
    let long = String(repeating: "x", count: 500)
    let client = client { Stub.respond(500, long, for: $0) }
    do {
      _ = try await client.previewRoute(origin: origin, destination: destination, via: [])
      Issue.record("expected an error")
    } catch let GoogleRoutesError.http(status, message) {
      #expect(status == 500)
      #expect(message.count == 160)
    }
  }

  @Test func offlineBecomesANetworkError() async {
    let client = client { _ in throw URLError(.notConnectedToInternet) }
    await #expect(throws: GoogleRoutesError.network) {
      try await client.previewRoute(origin: origin, destination: destination, via: [])
    }
  }

  @Test func missingKeyFailsBeforeAnyRequest() async {
    let called = LockedBox(false)
    let client = client(
      key: { throw GoogleAPIKey.Failure.missingFile },
      handler: { request in
        called.value = true
        return Stub.respond(200, previewJSON, for: request)
      })
    await #expect(throws: GoogleRoutesError.missingKey(.missingFile)) {
      try await client.previewRoute(origin: origin, destination: destination, via: [])
    }
    #expect(called.value == false)
  }

  @Test func userFacingMessagesAreActionable() {
    #expect(GoogleRoutesError.network.errorDescription?.contains("connection") == true)
    #expect(
      GoogleRoutesError.http(status: 429, message: "x").errorDescription?.contains("limit") == true
    )
    #expect(
      GoogleRoutesError.http(status: 403, message: "x").errorDescription?.contains("restrictions")
        == true)
    #expect(
      GoogleRoutesError.missingKey(.missingFile).errorDescription?.contains("Secrets.plist")
        == true)
  }
}

/// Mutable box for capturing values from `@Sendable` stub handlers in tests.
final class LockedBox<Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var stored: Value
  init(_ value: Value) { stored = value }
  var value: Value {
    get { lock.withLock { stored } }
    set { lock.withLock { stored = newValue } }
  }
}
