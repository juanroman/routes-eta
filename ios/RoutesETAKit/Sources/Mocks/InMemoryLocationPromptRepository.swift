import Domain

public actor InMemoryLocationPromptRepository: LocationPromptRepository {
  private var declined: Bool

  public init(declined: Bool = false) {
    self.declined = declined
  }

  public func wasDeclined() async -> Bool { declined }

  public func markDeclined() async { declined = true }
}
