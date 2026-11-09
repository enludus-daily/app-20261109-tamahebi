import Foundation

// 端末の中だけに残す進み具合（UserDefaults に JSON で保存）。
// おやつ（ゲームの中のポイント）は遊ぶとたまり、カプセルでなかまを呼ぶのに使う。おやつは売らない（消耗型の課金は作らない）。

struct Reward: Equatable, Sendable {
    var fromScore: Int
    var fromStars: Int
    var dailyBonus: Int
    var multiplier: Double
    var total: Int
}

struct PullResult: Equatable, Sendable {
    let character: Character
    let isNew: Bool
    /// かぶったときに返ってくるおやつ
    let refund: Int
}

enum TableTheme: String, Codable, CaseIterable, Sendable {
    case blue, green, plum, night
    var label: String {
        switch self {
        case .blue: "あお"
        case .green: "みどり"
        case .plum: "すもも"
        case .night: "よる"
        }
    }
    var isPro: Bool { self != .blue }
}

struct Progress: Codable, Equatable, Sendable {
    static let capsuleCost = 120
    static let duplicateRefund = 40
    static let startingSnacks = 150
    static let dailyFirstPlayBonus = 50
    static let snacksPerStar = 10

    var snacks = Progress.startingSnacks
    var owned: Set<String> = [Roster.starterID]
    var selected = Roster.starterID
    var bestByDay: [String: Int] = [:]
    var lastDailyDay: String?
    var streak = 0
    var totalEaten = 0
    var gamesPlayed = 0
    var pulls = 0
    var hasSeenPaywall = false
    var table: TableTheme = .blue

    var selectedCharacter: Character { Roster.character(selected) }

    func best(on day: String) -> Int? { bestByDay[day] }

    func canPull() -> Bool { snacks >= Self.capsuleCost }

    func owns(_ c: Character, isPro: Bool) -> Bool {
        c.rarity == .pro ? isPro : owned.contains(c.id)
    }

    // MARK: 遊び終わり

    /// 1 回遊び終わったときに呼ぶ。もらえるおやつを足して、その内訳を返す
    @discardableResult
    mutating func recordGame(score: Int, eaten: Int, isDaily: Bool, day: String, isPro: Bool) -> Reward {
        gamesPlayed += 1
        totalEaten += eaten
        var bonus = 0
        if isDaily {
            if lastDailyDay != day {
                bonus = Self.dailyFirstPlayBonus
                streak = (lastDailyDay == Self.day(before: day)) ? streak + 1 : 1
                lastDailyDay = day
            }
            bestByDay[day] = max(bestByDay[day] ?? 0, score)
        }
        let base = score / 5
        let stars = GameEngine.stars(for: score) * Self.snacksPerStar
        let mult = selectedCharacter.perk.coinMultiplier * (isPro ? 2 : 1)
        let total = Int((Double(base + stars) * mult).rounded()) + bonus
        snacks += total
        return Reward(fromScore: base, fromStars: stars, dailyBonus: bonus, multiplier: mult, total: total)
    }

    // MARK: カプセル

    /// おやつを使ってなかまを 1 匹よぶ。足りなければ nil
    mutating func pull<G: RandomNumberGenerator>(using rng: inout G) -> PullResult? {
        guard canPull() else { return nil }
        snacks -= Self.capsuleCost
        pulls += 1
        let c = Self.draw(using: &rng)
        if owned.contains(c.id) {
            snacks += Self.duplicateRefund
            return PullResult(character: c, isNew: false, refund: Self.duplicateRefund)
        }
        owned.insert(c.id)
        return PullResult(character: c, isNew: true, refund: 0)
    }

    static func draw<G: RandomNumberGenerator>(using rng: inout G) -> Character {
        let roll = Double.random(in: 0..<1, using: &rng)
        var acc = 0.0
        var rarity = Rarity.common
        for r in [Rarity.superRare, .rare, .common] {
            acc += r.pullRate
            if roll < acc { rarity = r; break }
        }
        let pool = Roster.capsulePool.filter { $0.rarity == rarity }
        return pool[Int.random(in: 0..<pool.count, using: &rng)]
    }

    /// 同じ等級の中では同じ確率。画面に出す表のための値
    static func rate(of c: Character) -> Double {
        guard c.rarity != .pro else { return 0 }
        let same = Roster.capsulePool.filter { $0.rarity == c.rarity }.count
        return c.rarity.pullRate / Double(same)
    }

    mutating func select(_ c: Character, isPro: Bool) -> Bool {
        guard owns(c, isPro: isPro) else { return false }
        selected = c.id
        return true
    }

    /// Pro が外れた（返金など）ときは、Pro 限定のなかまと台を元に戻す
    mutating func normalize(isPro: Bool) {
        if !isPro {
            if selectedCharacter.rarity == .pro { selected = Roster.starterID }
            if table.isPro { table = .blue }
        }
    }

    // MARK: 日付

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func day(before key: String) -> String? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        guard let d = cal.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
              let prev = cal.date(byAdding: .day, value: -1, to: d) else { return nil }
        return dayKey(prev, calendar: cal)
    }
}
