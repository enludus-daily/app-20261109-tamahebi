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
        #expect(p.snacks == Progress.startingSnacks - Progress.capsuleCost)
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

    @Test func duplicatesRaiseFriendship() throws {
        var p = Progress()
        p.owned = Set(Roster.capsulePool.map(\.id))
        p.snacks = 1000
        var rng = SeededRandom(seed: 2)
        let pulled = p.pull(using: &rng)
        let r = try #require(pulled)
        #expect(!r.isNew)
        #expect(r.levelUp == 2)
        #expect(r.unlocked != nil)
        #expect(p.level(of: r.character) == 2)
        #expect(p.snacks == 1000 - Progress.capsuleCost)
    }

    @Test func maxLevelDuplicatesRefundSnacks() throws {
        var p = Progress()
        p.owned = Set(Roster.capsulePool.map(\.id))
        for c in Roster.capsulePool { p.levels[c.id] = Roster.maxLevel }
        p.snacks = 1000
        var rng = SeededRandom(seed: 2)
        let pulled = p.pull(using: &rng)
        let r = try #require(pulled)
        #expect(r.levelUp == nil)
        #expect(p.snacks == 1000 - Progress.capsuleCost + Progress.maxLevelRefund)
    }

    @Test func costumesNeedFriendship() {
        var p = Progress()
        let tama = Roster.character("tama")
        let early = p.wear(.pastel, on: tama)
        #expect(!early)
        p.levels["tama"] = 2
        let ok = p.wear(.pastel, on: tama)
        #expect(ok)
        #expect(p.costume(of: tama) == .pastel)
        #expect(p.playable(tama).look.body != tama.body)
        let night = p.wear(.night, on: tama)
        #expect(!night)
    }

    @Test func proFriendsStartStrong() {
        let p = Progress()
        #expect(p.level(of: Roster.character("ginga")) == Progress.proCharacterLevel)
        #expect(p.level(of: Roster.character("mint")) == 0)
    }

    @Test func stageRewardsOnlyNewStars() {
        var p = Progress()
        let first = p.recordStage("1-1", stars: 1, eaten: 1, isPro: false)
        #expect(first.isFirstClear)
        #expect(first.snacks == Progress.stageFirstClear + Progress.stagePerNewStar)
        let again = p.recordStage("1-1", stars: 1, eaten: 1, isPro: false)
        #expect(again.snacks == 0)
        let better = p.recordStage("1-1", stars: 3, eaten: 1, isPro: false)
        #expect(better.snacks == 2 * Progress.stagePerNewStar)
        #expect(p.stars(of: "1-1") == 3)
        _ = p.recordStage("1-1", stars: 2, eaten: 1, isPro: false)
        #expect(p.stars(of: "1-1") == 3)
    }

    @Test func oldSavesStillLoad() throws {
        let old = #"{"snacks":321,"owned":["tama","mint"],"selected":"mint","bestByDay":{},"streak":2,"totalEaten":5,"gamesPlayed":3,"pulls":1,"hasSeenPaywall":false,"table":"blue"}"#
        let p = try JSONDecoder().decode(Progress.self, from: Data(old.utf8))
        #expect(p.snacks == 321)
        #expect(p.selected == "mint")
        #expect(p.level(of: Roster.character("mint")) == 1)
        #expect(p.stageStars.isEmpty)
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

struct HintTests {
    @Test func firstHintOfTheDayIsFree() {
        var p = Progress()
        #expect(p.hintPrice(for: "2-8", day: "2026-11-10", isPro: false) == .freeToday)
        let ok = p.unlockHint(for: "2-8", day: "2026-11-10", isPro: false)
        #expect(ok)
        #expect(p.snacks == Progress.startingSnacks)
        #expect(p.hintPrice(for: "2-8", day: "2026-11-10", isPro: false) == .owned)
        #expect(p.hintPrice(for: "2-9", day: "2026-11-10", isPro: false) == .snacks(Progress.hintCost))
        #expect(p.hintPrice(for: "2-9", day: "2026-11-11", isPro: false) == .freeToday)
    }

    @Test func laterHintsCostSnacks() {
        var p = Progress()
        _ = p.unlockHint(for: "1-1", day: "d", isPro: false)
        let ok = p.unlockHint(for: "1-2", day: "d", isPro: false)
        #expect(ok)
        #expect(p.snacks == Progress.startingSnacks - Progress.hintCost)
        p.snacks = 5
        let poor = p.unlockHint(for: "1-3", day: "d", isPro: false)
        #expect(!poor)
        #expect(!p.hintedStages.contains("1-3"))
    }

    @Test func proHintsAreFree() {
        var p = Progress()
        _ = p.unlockHint(for: "1-1", day: "d", isPro: false)
        let ok = p.unlockHint(for: "1-2", day: "d", isPro: true)
        #expect(ok)
        #expect(p.snacks == Progress.startingSnacks)
    }
}
