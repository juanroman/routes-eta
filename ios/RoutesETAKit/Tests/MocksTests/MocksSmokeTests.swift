import Testing

@testable import Mocks

@Test func mocksModuleLoads() {
  #expect(MocksInfo.domain == "Domain")
}
