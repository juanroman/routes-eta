import Domain
import Foundation

/// Keeps the config on the device as one JSON file (same shape as the API's
/// config, so nothing is lost if it is ever exchanged with `api/`).
///
/// - A missing file is a fresh install: an empty config.
/// - A file that exists but can't be read or decoded is an error, never silently
///   treated as empty, so a bad file can't be overwritten without anyone noticing.
/// - Writes are atomic, so a crash mid-save leaves the previous file intact.
public struct FileConfigRepository: ConfigRepository {
  private let url: URL

  public init(url: URL) {
    self.url = url
  }

  /// `Application Support/RoutesETA/config.json`
  public static func defaultURL() throws -> URL {
    try FileManager.default
      .url(
        for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
      )
      .appending(path: "RoutesETA", directoryHint: .isDirectory)
      .appending(path: "config.json", directoryHint: .notDirectory)
  }

  public func load() async throws -> Config {
    guard FileManager.default.fileExists(atPath: url.path) else { return Config() }
    return try JSONDecoder().decode(Config.self, from: Data(contentsOf: url))
  }

  public func save(_ config: Config) async throws {
    let issues = config.validate()
    guard issues.isEmpty else { throw ConfigRepositoryError.invalid(issues) }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try encoder.encode(config).write(to: url, options: .atomic)
  }
}
