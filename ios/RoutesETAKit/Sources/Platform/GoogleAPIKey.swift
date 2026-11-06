import Foundation

/// The Google Routes API key, read from a git-ignored `Secrets.plist` that Xcode
/// bundles automatically when it sits in the app's folder (the repo is public, so
/// the key can never be committed). `ios/Secrets.example.plist` is the template.
public enum GoogleAPIKey {
  public static let fileName = "Secrets"
  public static let plistKey = "GOOGLE_ROUTES_API_KEY"
  static let placeholder = "YOUR_KEY_HERE"

  public enum Failure: Error, Equatable, LocalizedError {
    /// No `Secrets.plist` in the app bundle.
    case missingFile
    /// The file exists but doesn't hold a usable key (absent, empty or the template value).
    case missingKey
    case unreadable

    public var errorDescription: String? {
      switch self {
      case .missingFile, .missingKey:
        "Add your Google API key: copy ios/Secrets.example.plist to "
          + "ios/RoutesETA/RoutesETA/Secrets.plist and set GOOGLE_ROUTES_API_KEY."
      case .unreadable:
        "Secrets.plist couldn't be read. Check that it is a valid property list."
      }
    }
  }

  public static func load(from bundle: Bundle = .main) throws -> String {
    guard let url = bundle.url(forResource: fileName, withExtension: "plist") else {
      throw Failure.missingFile
    }
    guard let data = try? Data(contentsOf: url) else { throw Failure.unreadable }
    return try parse(data)
  }

  static func parse(_ data: Data) throws -> String {
    guard
      let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
      let dictionary = plist as? [String: Any]
    else { throw Failure.unreadable }

    let key = (dictionary[plistKey] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let key, !key.isEmpty, key != placeholder else { throw Failure.missingKey }
    return key
  }
}
