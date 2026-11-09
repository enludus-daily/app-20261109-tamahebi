import Foundation
import Testing
@testable import Tamahebi

struct ProgressTests {
    @Test func startsWithTamaAndEnoughForOneCapsule() {
        let p = Progress()
        #expect(p.owned == ["tama"])
        #expect(p.selected == "tama")
        #expect(p.canPull())
    }

    @Test func firstDailyGameGivesTheBonusOnce() {
        var p = Progress()
        let first = p.recordGame(score: 100, eaten: 6, isDaily: true, day: "2026-11-09", isPro: false)
        #expect(first.dailyBonus == Progress.dailyFirstPlayBonus)
        #expect(first.total == 100 / 5 + 10 + Progress.dailyFirstPlayBonus)
        let second = p.recordGame(score: 100, eaten: 6, isDaily: true, day: "2026-11-09", isPro: false)
        #expect(second.dailyBonus == 0)
        #expect(p.best(on: "2026-11-09") == 100)
    }

    @Test func streakCountsConsecutiveDays() {
        var p = Progress()
        p.recordGame(score: 10, eaten: 1, isDaily: true, day: "2026-11-30", isPro: false)
        p.recordGame(score: 10, eaten: 1, isDaily: true, day: "2026-12-01", isPro: false)
        #expect(p.streak == 2)
        p.recordGame(score: 10, eaten: 1, isDaily: true, day: "2026-12-03", isPro: false)
        #expect(p.streak == 1)
    }

    @Test func proDoublesSnacks() {
        var a = Progress(), b = Progress()
        let free = a.recordGame(score: 150, eaten: 8, isDaily: false, day: "d", isPro: false)
        let pro = b.recordGame(score: 150, eaten: 8, isDaily: false, day: "d", isPro: true)
        #expect(pro.total == free.total * 2)
    }

    @Test func pullSpendsSnacksAndAddsAFriend() throws {
        var p = Progress()
        var rng = SeededRandom(seed: 1)
        let r = p.pull(using: &rng)
        try #require(r != nil)
        #expect(p.snacks == Progress.startingSnacks - Progress.capsuleCost + (r!.isNew ? 0 : Progress.duplicateRefund))
        #expect(p.owned.contains(r!.character.id))
        #expect(r!.character.rarity != .pro)
    }

    @Test func cannotPullWithoutSnacks() {
        var p = Progress()
        p.snacks = Progress.capsuleCost - 1
        var rng = SeededRandom(seed: 1)
        #expect(p.pull(using: &rng) == nil)
        #expect(p.snacks == Progress.capsuleCost - 1)
    }

    @Test func duplicatesRefundSnacks() {
        var p = Progress()
        p.owned = Set(Roster.capsulePool.map(\.id))
        p.snacks = 1000
        var rng = SeededRandom(seed: 2)
        let r = p.pull(using: &rng)!
        #expect(!r.isNew)
        #expect(p.snacks == 1000 - Progress.capsuleCost + Progress.duplicateRefund)
    }

    @Test func ratesAddUpToOne() {
        let sum = Roster.capsulePool.map(Progress.rate(of:)).reduce(0, +)
        #expect(abs(sum - 1) < 1e-9)
    }

    @Test func drawFollowsTheRatesRoughly() {
        var rng = SeededRandom(seed: 99)
        var counts: [Rarity: Int] = [:]
        for _ in 0..<20_000 { counts[Progress.draw(using: &rng).rarity, default: 0] += 1 }
        #expect(abs(Double(counts[.common] ?? 0) / 20_000 - 0.70) < 0.02)
        #expect(abs(Double(counts[.superRare] ?? 0) / 20_000 - 0.05) < 0.01)
        #expect(counts[.pro] == nil)
    }

    @Test func proFriendsNeedPro() {
        var p = Progress()
        let ginga = Roster.character("ginga")
        let without = p.select(ginga, isPro: false)
        #expect(!without)
        let with = p.select(ginga, isPro: true)
        #expect(with)
        p.table = .night
        p.normalize(isPro: false)
        #expect(p.selected == Roster.starterID)
        #expect(p.table == .blue)
    }

    @Test func savesAndLoads() throws {
        var p = Progress()
        p.snacks = 321
        p.owned.insert("mint")
        let data = try JSONEncoder().encode(p)
        #expect(try JSONDecoder().decode(Progress.self, from: data) == p)
    }

    @Test func dayBeforeCrossesMonthAndYear() {
        #expect(Progress.day(before: "2027-01-01") == "2026-12-31")
        #expect(Progress.day(before: "2026-03-01") == "2026-02-28")
    }
}
