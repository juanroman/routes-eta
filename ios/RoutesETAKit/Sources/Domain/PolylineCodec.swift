/// Google's encoded polyline format (precision 5). `decode` is a Swift port of
/// `api/app/polyline.py`'s `decode_polyline`, with bounds checks so a truncated
/// or corrupt string throws instead of crashing.
public enum PolylineCodec {
  public enum DecodeError: Error, Equatable, Sendable {
    case malformed
  }

  public static func decode(_ encoded: String) throws -> [LatLng] {
    let bytes = Array(encoded.utf8)
    var index = 0
    var lat = 0
    var lng = 0
    var coordinates: [LatLng] = []

    func nextDelta() throws -> Int {
      var shift = 0
      var result = 0
      while true {
        guard index < bytes.count, shift < 35 else { throw DecodeError.malformed }
        let byte = Int(bytes[index]) - 63
        index += 1
        guard byte >= 0 else { throw DecodeError.malformed }
        result |= (byte & 0x1F) << shift
        shift += 5
        if byte < 0x20 { break }
      }
      return (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
    }

    while index < bytes.count {
      lat += try nextDelta()
      lng += try nextDelta()
      coordinates.append(LatLng(lat: Double(lat) / 1e5, lng: Double(lng) / 1e5))
    }
    return coordinates
  }

  /// The inverse of `decode`. Lossless for lines that came from Google (they already
  /// have 5 decimals); other coordinates are rounded to 5 (about a metre).
  public static func encode(_ points: [LatLng]) -> String {
    var output = ""
    var previousLat = 0
    var previousLng = 0

    func append(_ delta: Int) {
      var value = delta < 0 ? ~(delta << 1) : (delta << 1)
      while value >= 0x20 {
        output.unicodeScalars.append(UnicodeScalar(UInt8((0x20 | (value & 0x1F)) + 63)))
        value >>= 5
      }
      output.unicodeScalars.append(UnicodeScalar(UInt8(value + 63)))
    }

    for point in points {
      let lat = Int((point.lat * 1e5).rounded())
      let lng = Int((point.lng * 1e5).rounded())
      append(lat - previousLat)
      append(lng - previousLng)
      previousLat = lat
      previousLng = lng
    }
    return output
  }
}
