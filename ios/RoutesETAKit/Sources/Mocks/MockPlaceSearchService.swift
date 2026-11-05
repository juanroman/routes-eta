import Domain
import Foundation

/// A fixed list of Mexico City places filtered by substring; no network.
/// Deliberately has no "Home"/"Work" entries: those are keyword shortcuts
/// (`SavedPlaces`), not search results.
public struct MockPlaceSearchService: PlaceSearchService {
  public static let address = "Mexico City, CDMX"

  public static let places: [NamedPoint] = [
    NamedPoint(label: "Zócalo", lat: 19.4326, lng: -99.1332),
    NamedPoint(label: "Polanco", lat: 19.4333, lng: -99.1950),
    NamedPoint(label: "Santa Fe", lat: 19.3590, lng: -99.2590),
    NamedPoint(label: "Satélite", lat: 19.5100, lng: -99.2340),
    NamedPoint(label: "Aeropuerto AICM", lat: 19.4361, lng: -99.0719),
    NamedPoint(label: "Coyoacán", lat: 19.3467, lng: -99.1617),
    NamedPoint(label: "Chapultepec", lat: 19.4204, lng: -99.1819),
  ]

  public init() {}

  public func suggestions(for query: String) async throws -> [PlaceSuggestion] {
    let trimmed = query.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return [] }
    return Self.places
      .filter {
        $0.label.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
      }
      .map { PlaceSuggestion(id: $0.label, title: $0.label, subtitle: Self.address) }
  }

  public func resolve(_ suggestion: PlaceSuggestion) async throws -> NamedPoint {
    guard let place = Self.places.first(where: { $0.label == suggestion.id }) else {
      throw PlaceSearchError.notFound
    }
    return place
  }
}
