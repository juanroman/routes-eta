import Domain
import Foundation

/// Keeps drawn routes on the device as one JSON file, so lines appear instantly
/// (even right after launch, even offline) and Google is only asked about routes
/// that are new or were edited.
///
/// - Unlike the config, an unreadable or corrupt file is treated as **empty**: this is
///   only a cache, so the worst case is asking Google again, and a bad file must never
///   keep the app from drawing routes. The next successful write replaces it.
/// - Writes are atomic and best effort: a failed write is ignored (it is just a miss later).
/// - Bounded: when full, the entry used least recently is dropped. Every route edit makes a
///   new key, so without a bound the file would grow with each via point you move.
/// - Lines are stored in Google's encoded-polyline form, about a fifth of the size of the
///   coordinates, and lossless for lines that came from Google.
public actor FileRouteLineCache: RouteLineCache {
  private struct Entry: Codable {
    var key: RouteLineKey
    var distanceMeters: Int
    var polyline: String
  }

  private struct FileContents: Codable {
    /// Least recently used first.
    var entries: [Entry]
  }

  private let url: URL
  private let capacity: Int
  private var entries: [Entry]?

  public init(url: URL, capacity: Int = 200) {
    self.url = url
    self.capacity = max(capacity, 1)
  }

  /// `Application Support/RoutesETA/route-lines.json`, next to `config.json`.
  public static func defaultURL() throws -> URL {
    try FileManager.default
      .url(
        for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
      )
      .appending(path: "RoutesETA", directoryHint: .isDirectory)
      .appending(path: "route-lines.json", directoryHint: .notDirectory)
  }

  public func line(for key: RouteLineKey) async -> RoutePreview? {
    var loaded = loadedEntries()
    guard let index = loaded.firstIndex(where: { $0.key == key }) else { return nil }
    guard let polyline = try? PolylineCodec.decode(loaded[index].polyline) else {
      // Can't be read back, so it is no use to anyone; forget it.
      loaded.remove(at: index)
      entries = loaded
      return nil
    }
    // A hit makes it the most recently used. Only remembered in memory: reading
    // shouldn't cost a disk write, and the order is saved with the next store.
    let entry = loaded.remove(at: index)
    loaded.append(entry)
    entries = loaded
    return RoutePreview(distanceMeters: entry.distanceMeters, polyline: polyline)
  }

  public func store(_ preview: RoutePreview, for key: RouteLineKey) async {
    var loaded = loadedEntries()
    loaded.removeAll { $0.key == key }
    loaded.append(
      Entry(
        key: key, distanceMeters: preview.distanceMeters,
        polyline: PolylineCodec.encode(preview.polyline)))
    if loaded.count > capacity { loaded.removeFirst(loaded.count - capacity) }
    entries = loaded
    write(loaded)
  }

  private func loadedEntries() -> [Entry] {
    if let entries { return entries }
    let loaded =
      (try? JSONDecoder().decode(FileContents.self, from: Data(contentsOf: url)))?.entries ?? []
    entries = loaded
    return loaded
  }

  private func write(_ entries: [Entry]) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    do {
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      try encoder.encode(FileContents(entries: entries)).write(to: url, options: .atomic)
    } catch {
      // Best effort, see the type's documentation.
    }
  }
}
