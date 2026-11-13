import Domain

public actor InMemoryRecentCommutesRepository: RecentCommutesRepository {
  private var names: [String]

  public init(initial: [String] = []) {
    names = initial
  }

  public func load() async throws -> [String] { names }

  public func save(_ names: [String]) async throws { self.names = names }
}
