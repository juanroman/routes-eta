/// A search hit before it has coordinates. `subtitle` is the address line shown
/// under the name; it is display-only and never saved in the config.
public struct PlaceSuggestion: Hashable, Identifiable, Sendable {
  public let id: String
  public var title: String
  public var subtitle: String

  public init(id: String, title: String, subtitle: String) {
    self.id = id
    self.title = title
    self.subtitle = subtitle
  }
}

/// The two keyword shortcuts, like Maps' "Places". iOS gives apps no access to
/// the system's Home/Work, so the app keeps its own, set once by the user.
public enum SavedPlaceKind: String, Codable, CaseIterable, Hashable, Sendable {
  case home
  case work

  /// Also the label written into a commute, e.g. "Home → Work".
  public var label: String {
    switch self {
    case .home: "Home"
    case .work: "Work"
    }
  }
}

public struct SavedPlace: Codable, Hashable, Sendable {
  public var point: NamedPoint
  /// Address line shown under the shortcut.
  public var detail: String

  public init(point: NamedPoint, detail: String) {
    self.point = point
    self.detail = detail
  }
}

public struct SavedPlaces: Codable, Hashable, Sendable {
  public var home: SavedPlace?
  public var work: SavedPlace?

  public init(home: SavedPlace? = nil, work: SavedPlace? = nil) {
    self.home = home
    self.work = work
  }

  public subscript(kind: SavedPlaceKind) -> SavedPlace? {
    get {
      switch kind {
      case .home: home
      case .work: work
      }
    }
    set {
      switch kind {
      case .home: home = newValue
      case .work: work = newValue
      }
    }
  }
}
