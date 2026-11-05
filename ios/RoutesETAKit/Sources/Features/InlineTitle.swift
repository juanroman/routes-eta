import SwiftUI

extension View {
  /// Inline nav title on iOS; a no-op elsewhere so the package still builds for
  /// `swift test` on the macOS host.
  func inlineNavigationTitle() -> some View {
    #if os(iOS)
      navigationBarTitleDisplayMode(.inline)
    #else
      self
    #endif
  }
}
