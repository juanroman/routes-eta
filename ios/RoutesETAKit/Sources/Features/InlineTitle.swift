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

extension View {
  /// The big title style (a sheet's header); a no-op on the macOS test host.
  func largeNavigationTitle() -> some View {
    #if os(iOS)
      navigationBarTitleDisplayMode(.large)
    #else
      self
    #endif
  }

  /// Keeps the title (it still labels the back button of screens pushed on top) but doesn't
  /// draw it, for screens whose sheet already shows it big.
  func hidingNavigationTitle() -> some View {
    #if os(iOS)
      toolbar(removing: .title)
    #else
      self
    #endif
  }
}
