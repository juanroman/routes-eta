import Testing

@testable import Features

@Test func featuresModuleLoads() {
  #expect(FeaturesInfo.domain == "Domain")
}
