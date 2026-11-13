import Testing

@testable import Domain

struct RecentCommutesTests {
  @Test func theFirstViewStartsTheHistory() {
    #expect(RecentCommutes.touch("A", in: []) == ["A"])
  }

  @Test func theLatestViewGoesFirst() {
    #expect(RecentCommutes.touch("C", in: ["B", "A"]) == ["C", "B", "A"])
  }

  @Test func viewingAgainPromotesWithoutDuplicating() {
    #expect(RecentCommutes.touch("A", in: ["C", "B", "A"]) == ["A", "C", "B"])
    #expect(RecentCommutes.touch("C", in: ["C", "B", "A"]) == ["C", "B", "A"])
  }

  @Test func theOldestAgesOutAtTheLimit() {
    let names = (1...3).map { "Commute \($0)" }
    #expect(
      RecentCommutes.touch("New", in: names, limit: 3) == ["New", "Commute 1", "Commute 2"])
  }

  @Test func theDefaultLimitIsTen() {
    #expect(RecentCommutes.limit == 10)
    var names: [String] = []
    for index in 1...15 { names = RecentCommutes.touch("Commute \(index)", in: names) }
    #expect(names.count == 10)
    #expect(names.first == "Commute 15")
    #expect(names.last == "Commute 6")
  }

  @Test func aBlankNameIsIgnored() {
    #expect(RecentCommutes.touch("", in: ["A"]) == ["A"])
  }
}
