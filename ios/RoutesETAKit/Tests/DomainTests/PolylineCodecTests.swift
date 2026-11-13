import Testing

@testable import Domain

struct PolylineCodecTests {
  /// The worked example from Google's polyline algorithm documentation.
  @Test func decodesGoogleDocumentedExample() throws {
    let points = try PolylineCodec.decode("_p~iF~ps|U_ulLnnqC_mqNvxq`@")
    #expect(points.count == 3)
    #expect(points[0] == LatLng(lat: 38.5, lng: -120.2))
    #expect(points[1] == LatLng(lat: 40.7, lng: -120.95))
    #expect(points[2] == LatLng(lat: 43.252, lng: -126.453))
  }

  @Test func emptyStringIsAnEmptyLine() throws {
    #expect(try PolylineCodec.decode("").isEmpty)
  }

  @Test func truncatedInputThrowsInsteadOfCrashing() {
    #expect(throws: PolylineCodec.DecodeError.malformed) {
      try PolylineCodec.decode("_p~iF~ps|U_ulLnn")  // cut mid-point
    }
    #expect(throws: PolylineCodec.DecodeError.malformed) {
      try PolylineCodec.decode("_p~iF")  // latitude without a longitude
    }
  }

  @Test func charactersOutsideTheAlphabetThrow() {
    #expect(throws: PolylineCodec.DecodeError.malformed) {
      try PolylineCodec.decode(" \u{1}")
    }
  }

  @Test func encodesGoogleDocumentedExample() {
    let points = [
      LatLng(lat: 38.5, lng: -120.2), LatLng(lat: 40.7, lng: -120.95),
      LatLng(lat: 43.252, lng: -126.453),
    ]
    #expect(PolylineCodec.encode(points) == "_p~iF~ps|U_ulLnnqC_mqNvxq`@")
  }

  @Test func encodingThenDecodingGivesTheSameLine() throws {
    // Includes a repeated point (zero delta) and negative and positive steps in both axes.
    let points = [
      LatLng(lat: 19.43261, lng: -99.13321), LatLng(lat: 19.43261, lng: -99.13321),
      LatLng(lat: 19.45502, lng: -99.20498), LatLng(lat: 19.39999, lng: -99.01234),
      LatLng(lat: -33.86882, lng: 151.20929),
    ]
    #expect(try PolylineCodec.decode(PolylineCodec.encode(points)) == points)
  }

  @Test func anEmptyLineEncodesToAnEmptyString() {
    #expect(PolylineCodec.encode([]) == "")
  }

  @Test func encodingRoundsToFiveDecimals() throws {
    let rounded = try PolylineCodec.decode(
      PolylineCodec.encode([LatLng(lat: 19.4326077, lng: -99.1332080)]))
    #expect(rounded == [LatLng(lat: 19.43261, lng: -99.13321)])
  }
}
