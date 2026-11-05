import Domain
import Features
import Mocks
import SwiftUI

@main
struct RoutesETAApp: App {
  // Phase 1-3 run entirely on in-memory mocks; real API clients replace these
  // here (the only place that knows the concrete types) in a later phase.
  @State private var store = ConfigStore(repository: InMemoryConfigRepository())
  @State private var router = AppRouter()

  var body: some Scene {
    WindowGroup {
      RootView(store: store, router: router, placeSearch: MockPlaceSearchService())
    }
  }
}
