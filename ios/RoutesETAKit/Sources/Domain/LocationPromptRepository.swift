/// Remembers that the user said "Not now" to the explanation shown before the system's location
/// prompt, so it is not shown again at every launch. (If they refuse in the system prompt itself,
/// `LocationAuthorization.denied` already records that.)
public protocol LocationPromptRepository: Sendable {
  func wasDeclined() async -> Bool
  func markDeclined() async
}
