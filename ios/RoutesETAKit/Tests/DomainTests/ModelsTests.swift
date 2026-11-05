import Foundation
import Testing

@testable import Domain

struct ModelsTests {
  private let json = """
    {
      "timezone": "America/Mexico_City",
      "commutes": [{
        "name": "A",
        "origin": { "label": "Work", "lat": 19.4, "lng": -99.1 },
        "destination": null,
        "routes": [{ "name": "City", "color": "#2563eb", "via": [{ "lat": 1, "lng": 2 }] }],
        "schedules": [{ "weekdays": ["mon", "tue"], "time": "06:30" }]
      }]
    }
    """

  @Test func decodesTheApiShape() throws {
    let config = try JSONDecoder().decode(Config.self, from: Data(json.utf8))
    let commute = try #require(config.commutes.first)
    #expect(commute.origin == NamedPoint(label: "Work", lat: 19.4, lng: -99.1))
    #expect(commute.destination == nil)
    #expect(commute.routes.first?.via == [LatLng(lat: 1, lng: 2)])
    #expect(commute.schedules.first?.weekdays == [.mon, .tue])
  }

  @Test func roundTrips() throws {
    let config = try JSONDecoder().decode(Config.self, from: Data(json.utf8))
    let data = try JSONEncoder().encode(config)
    #expect(try JSONDecoder().decode(Config.self, from: data) == config)
  }

  @Test func unknownWeekdayFailsToDecode() {
    let bad = json.replacingOccurrences(of: "\"tue\"", with: "\"funday\"")
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(Config.self, from: Data(bad.utf8))
    }
  }
}
