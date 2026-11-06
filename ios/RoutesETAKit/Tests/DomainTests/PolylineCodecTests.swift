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
}
