import Domain
import Foundation

/// A commute plus a stable identity for the UI. Commute names are the config's
/// identity but can be renamed, so navigation and lists key off this `id`.
public struct CommuteEntry: Identifiable, Hashable, Sendable {
  public let id: UUID
  public var commute: Commute

  public init(id: UUID = UUID(), commute: Commute) {
    self.id = id
    self.commute = commute
  }
}
