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

/// iOS Edit/Done button (reorder mode); empty on the macOS test host, where
/// `EditButton` doesn't exist.
struct ReorderButton: View {
  var body: some View {
    #if os(iOS)
      EditButton()
    #else
      EmptyView()
    #endif
  }
}

extension View {
  /// Full-screen cover on iOS; a sheet on the macOS test host, where
  /// `fullScreenCover` doesn't exist.
  func fullScreenCoverOnIOS<Content: View>(
    isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content
  ) -> some View {
    #if os(iOS)
      fullScreenCover(isPresented: isPresented, content: content)
    #else
      sheet(isPresented: isPresented, content: content)
    #endif
  }
}
