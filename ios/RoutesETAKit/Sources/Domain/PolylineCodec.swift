/// Google's encoded polyline format (precision 5). Swift port of
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
}
