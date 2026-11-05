import Domain
import Foundation

/// A fixed list of Mexico City places filtered by substring; no network.
public struct MockPlaceSearchService: PlaceSearchService {
  public static let places: [NamedPoint] = [
    SampleData.work,
    SampleData.home,
    NamedPoint(label: "Zócalo", lat: 19.4326, lng: -99.1332),
    NamedPoint(label: "Polanco", lat: 19.4333, lng: -99.1950),
    NamedPoint(label: "Santa Fe", lat: 19.3590, lng: -99.2590),
    NamedPoint(label: "Satélite", lat: 19.5100, lng: -99.2340),
    NamedPoint(label: "Aeropuerto AICM", lat: 19.4361, lng: -99.0719),
    NamedPoint(label: "Coyoacán", lat: 19.3467, lng: -99.1617),
  ]

  public init() {}

  public func search(query: String) async throws -> [NamedPoint] {
    let trimmed = query.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return Self.places }
    return Self.places.filter {
      $0.label.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
  }
}
