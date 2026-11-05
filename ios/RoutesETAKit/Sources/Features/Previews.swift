#if DEBUG
  import Mocks
  import SwiftUI

  @MainActor
  private func previewRoot() -> some View {
    RootView(
      store: ConfigStore(repository: InMemoryConfigRepository()),
      router: AppRouter())
  }

  #Preview("Commutes") { previewRoot() }
#endif
