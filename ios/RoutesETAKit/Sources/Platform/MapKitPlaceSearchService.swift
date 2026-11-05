import Domain
import MapKit

/// Calendar-style place search: `MKLocalSearchCompleter` for as-you-type
/// suggestions, `MKLocalSearch` to resolve the chosen one to coordinates.
/// No permission needed. Main-actor bound because the completer and its
/// (non-Sendable) completions are.
@MainActor
public final class MapKitPlaceSearchService: NSObject, PlaceSearchService {
  private let completer = MKLocalSearchCompleter()
  private var completions: [String: MKLocalSearchCompletion] = [:]
  private var pending: CheckedContinuation<[PlaceSuggestion], any Error>?

  public override init() {
    super.init()
    completer.resultTypes = [.address, .pointOfInterest]
    completer.delegate = self
  }

  public func suggestions(for query: String) async throws -> [PlaceSuggestion] {
    let trimmed = query.trimmingCharacters(in: .whitespaces)
    // A newer query supersedes any one still waiting.
    pending?.resume(throwing: CancellationError())
    pending = nil
    guard !trimmed.isEmpty else { return [] }

    return try await withCheckedThrowingContinuation { continuation in
      pending = continuation
      completer.queryFragment = trimmed
    }
  }

  public func resolve(_ suggestion: PlaceSuggestion) async throws -> NamedPoint {
    guard let completion = completions[suggestion.id] else { throw PlaceSearchError.notFound }
    let response = try await MKLocalSearch(request: MKLocalSearch.Request(completion: completion))
      .start()
    guard let item = response.mapItems.first else { throw PlaceSearchError.notFound }
    let coordinate = item.location.coordinate
    return NamedPoint(
      label: suggestion.title, lat: coordinate.latitude, lng: coordinate.longitude)
  }
}

extension MapKitPlaceSearchService: @preconcurrency MKLocalSearchCompleterDelegate {
  public func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
    var suggestions: [PlaceSuggestion] = []
    completions = [:]
    for completion in completer.results {
      // Title + subtitle is unique enough within one result set.
      let id = "\(completion.title)|\(completion.subtitle)"
      completions[id] = completion
      suggestions.append(
        PlaceSuggestion(id: id, title: completion.title, subtitle: completion.subtitle))
    }
    pending?.resume(returning: suggestions)
    pending = nil
  }

  public func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
    pending?.resume(throwing: error)
    pending = nil
  }
}
