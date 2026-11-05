import Domain
import Observation

/// The user's Home/Work shortcuts. Picking one copies its coordinates into a
/// commute, so editing it later never changes commutes that already used it.
@MainActor
@Observable
public final class SavedPlacesStore {
  public private(set) var places = SavedPlaces()
  private let repository: any SavedPlacesRepository

  public init(repository: any SavedPlacesRepository) {
    self.repository = repository
  }

  public func load() async {
    places = (try? await repository.load()) ?? SavedPlaces()
  }

  /// Saves `point` as Home or Work. The label is forced to "Home"/"Work" so a
  /// commute reads "Home → Work" whatever the address was called in search.
  /// Returns the saved shortcut's point, or nil if it couldn't be stored.
  @discardableResult
  public func set(_ kind: SavedPlaceKind, to point: NamedPoint, detail: String) async
    -> NamedPoint?
  {
    var updated = places
    let labeled = NamedPoint(label: kind.label, lat: point.lat, lng: point.lng)
    updated[kind] = SavedPlace(point: labeled, detail: detail)
    do {
      try await repository.save(updated)
      places = updated
      return labeled
    } catch {
      return nil
    }
  }
}
