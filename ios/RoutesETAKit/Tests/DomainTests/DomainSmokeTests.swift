import Testing

@testable import Domain

@Test func domainModuleLoads() {
  #expect(DomainInfo.name == "Domain")
}
