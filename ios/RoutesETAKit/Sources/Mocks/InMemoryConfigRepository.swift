import Domain

/// Holds the config in memory for the app's lifetime (lost on relaunch).
public actor InMemoryConfigRepository: ConfigRepository {
  private var config: Config

  public init(initial: Config = SampleData.config) {
    config = initial
  }

  public func load() async throws -> Config { config }

  public func save(_ config: Config) async throws {
    let issues = config.validate()
    guard issues.isEmpty else { throw ConfigRepositoryError.invalid(issues) }
    self.config = config
  }
}
