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
    /// かぶって、なかよし度が上がったときの新しいレベル（新しい子・Lv5 のときは nil）
    let levelUp: Int?
    /// Lv5 の子がかぶったときに返ってくるおやつ
    let refund: Int
    /// ピックアップの子だった
    var isPickup = false
    /// このレベルで新しく使えるようになったもの
    var unlocked: String? {
        guard let l = levelUp else { return nil }
        switch l {
        case 2: return String(localized: "きせかえ「\(L.s(Costume.pastel.label))」")
        case 3: return String(localized: "とくいが強くなった")
        case 4: return String(localized: "きせかえ「\(L.s(Costume.night.label))」")
        case 5: return String(localized: "なかよし最大！とくいがいちばん強い")
        default: return nil
        }
    }
}

struct StageReward: Equatable, Sendable {
    var stars: Int
    var previousStars: Int
    var snacks: Int
    var isFirstClear: Bool { previousStars == 0 && stars > 0 }
}

enum TableTheme: String, Codable, CaseIterable, Sendable {
    case blue, green, plum, night
    var label: String {
        switch self {
        case .blue: String(localized: "あお")
        case .green: String(localized: "みどり")
        case .plum: String(localized: "すもも")
        case .night: String(localized: "よる")
        }
    }
    var isPro: Bool { self != .blue }
}

struct Progress: Codable, Equatable, Sendable {
    static let capsuleCost = 120
    /// 10 回まとめて（1 回ぶんおまけ）。10 回目は、それまでにレア以上が出ていなければレア以上
    static let tenPullCost = 1080
    /// 天井：スーパーレアが出ないまま、この回数目はピックアップの子
    static let pityLimit = 40
    static let maxLevelRefund = 60
    static let startingSnacks = 150
    static let dailyFirstPlayBonus = 50
    static let snacksPerStar = 10
    static let stageFirstClear = 30
    static let stagePerNewStar = 10
    /// Pro 限定のなかまは、はじめから Lv3
    static let proCharacterLevel = 3
    /// ヒント（そのステージのおてほんの打ち方）。1 日 1 回は無料、Pro はいつも無料
    static let hintCost = 30

    var snacks = Progress.startingSnacks
    var owned: Set<String> = [Roster.starterID]
    var selected = Roster.starterID
    var levels: [String: Int] = [:]
    var costumes: [String: Int] = [:]
    var stageStars: [String: Int] = [:]
    var bestByDay: [String: Int] = [:]
    var lastDailyDay: String?
    var streak = 0
    var totalEaten = 0
    var gamesPlayed = 0
    var pulls = 0
    var hasSeenPaywall = false
    var table: TableTheme = .blue
    /// ヒントを開けたステージ（一度開けたら、そのステージではずっと見られる）
    var hintedStages: Set<String> = []
    var lastFreeHintDay: String?
    var tutorialDone = false
    /// 全画面広告のために数える遊び終わりの回数（チュートリアルはのぞく）
    var adPlays = 0
    /// 天井のために数える、スーパーレアが出ていない回数
    var sinceSuperRare = 0

    init() {}

    // 古い版の保存（キーが足りない）も読めるようにする
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Progress()
        snacks = try c.decodeIfPresent(Int.self, forKey: .snacks) ?? d.snacks
        owned = try c.decodeIfPresent(Set<String>.self, forKey: .owned) ?? d.owned
        selected = try c.decodeIfPresent(String.self, forKey: .selected) ?? d.selected
        levels = try c.decodeIfPresent([String: Int].self, forKey: .levels) ?? [:]
        costumes = try c.decodeIfPresent([String: Int].self, forKey: .costumes) ?? [:]
        stageStars = try c.decodeIfPresent([String: Int].self, forKey: .stageStars) ?? [:]
        bestByDay = try c.decodeIfPresent([String: Int].self, forKey: .bestByDay) ?? [:]
        lastDailyDay = try c.decodeIfPresent(String.self, forKey: .lastDailyDay)
        streak = try c.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        totalEaten = try c.decodeIfPresent(Int.self, forKey: .totalEaten) ?? 0
        gamesPlayed = try c.decodeIfPresent(Int.self, forKey: .gamesPlayed) ?? 0
        pulls = try c.decodeIfPresent(Int.self, forKey: .pulls) ?? 0
        hasSeenPaywall = try c.decodeIfPresent(Bool.self, forKey: .hasSeenPaywall) ?? false
        table = try c.decodeIfPresent(TableTheme.self, forKey: .table) ?? .blue
        hintedStages = try c.decodeIfPresent(Set<String>.self, forKey: .hintedStages) ?? []
        lastFreeHintDay = try c.decodeIfPresent(String.self, forKey: .lastFreeHintDay)
        tutorialDone = try c.decodeIfPresent(Bool.self, forKey: .tutorialDone) ?? false
        adPlays = try c.decodeIfPresent(Int.self, forKey: .adPlays) ?? 0
        sinceSuperRare = try c.decodeIfPresent(Int.self, forKey: .sinceSuperRare) ?? 0
    }

    // MARK: iCloud とのあわせ

    /// 遊んだ量（どちらの記録が新しいかの目安）
    var activity: Int { gamesPlayed + pulls }

    /// 2 台（または入れ直す前と後）の記録を合わせる。なくしたくないもの（星・なかま・なかよし度・ベスト）は多いほう、
    /// 使うと減るもの（おやつ・天井の回数）や選んでいるものは、たくさん遊んだほうの記録にそろえる
    static func merged(_ a: Progress, _ b: Progress) -> Progress {
        var base = a.activity >= b.activity ? a : b
        let other = a.activity >= b.activity ? b : a
        base.owned.formUnion(other.owned)
        base.levels.merge(other.levels) { max($0, $1) }
        base.costumes.merge(other.costumes) { mine, _ in mine }
        base.stageStars.merge(other.stageStars) { max($0, $1) }
        base.bestByDay.merge(other.bestByDay) { max($0, $1) }
        base.lastDailyDay = [base.lastDailyDay, other.lastDailyDay].compactMap { $0 }.max()
        base.totalEaten = max(base.totalEaten, other.totalEaten)
        base.gamesPlayed = max(base.gamesPlayed, other.gamesPlayed)
        base.pulls = max(base.pulls, other.pulls)
        base.hasSeenPaywall = base.hasSeenPaywall || other.hasSeenPaywall
        base.hintedStages.formUnion(other.hintedStages)
        base.lastFreeHintDay = [base.lastFreeHintDay, other.lastFreeHintDay].compactMap { $0 }.max()
        base.tutorialDone = base.tutorialDone || other.tutorialDone
        base.adPlays = max(base.adPlays, other.adPlays)
        return base
    }

    // MARK: ヒント

    enum HintPrice: Equatable, Sendable { case owned, pro, freeToday, snacks(Int), tooFewSnacks(Int) }

    func hintPrice(for stageID: String, day: String, isPro: Bool) -> HintPrice {
        if hintedStages.contains(stageID) { return .owned }
        if isPro { return .pro }
        if lastFreeHintDay != day { return .freeToday }
        return snacks >= Self.hintCost ? .snacks(Self.hintCost) : .tooFewSnacks(Self.hintCost)
    }

    /// ヒントを開ける。おやつが足りないときは false
    mutating func unlockHint(for stageID: String, day: String, isPro: Bool) -> Bool {
        switch hintPrice(for: stageID, day: day, isPro: isPro) {
        case .owned: return true
        case .pro: break
        case .freeToday: lastFreeHintDay = day
        case .snacks(let n): snacks -= n
        case .tooFewSnacks: return false
        }
        hintedStages.insert(stageID)
        return true
    }

    var selectedCharacter: Character { Roster.character(selected) }

    func best(on day: String) -> Int? { bestByDay[day] }

    func canPull() -> Bool { snacks >= Self.capsuleCost }

    func owns(_ c: Character, isPro: Bool, friendPack: Bool = false) -> Bool {
        switch c.rarity {
        case .pro: isPro
        case .pack: friendPack
        default: owned.contains(c.id)
        }
    }

    // MARK: なかよし度・きせかえ

    func level(of c: Character) -> Int {
        (c.rarity == .pro || c.rarity == .pack) ? max(Self.proCharacterLevel, levels[c.id] ?? 0) : (owned.contains(c.id) ? max(1, levels[c.id] ?? 1) : 0)
    }

    func costume(of c: Character) -> Costume {
        let k = Costume(rawValue: costumes[c.id] ?? 0) ?? .original
        return k.requiredLevel <= level(of: c) ? k : .original
    }

    /// 遊ぶときの見た目（きせかえ込み）とルール（なかよし度込み）
    func playable(_ c: Character) -> (look: Character, rules: Rules) {
        (c.wearing(costume(of: c)), c.rules(level: max(1, level(of: c))))
    }

    mutating func wear(_ k: Costume, on c: Character) -> Bool {
        guard k.requiredLevel <= level(of: c) else { return false }
        costumes[c.id] = k.rawValue
        return true
    }

    // MARK: 遊び終わり（きょうの台・ランダム台）

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
        let mult = snackMultiplier(isPro: isPro)
        let total = Int((Double(base + stars) * mult).rounded()) + bonus
        snacks += total
        return Reward(fromScore: base, fromStars: stars, dailyBonus: bonus, multiplier: mult, total: total)
    }

    func snackMultiplier(isPro: Bool) -> Double {
        let c = selectedCharacter
        return c.perk.coinMultiplier(level: level(of: c)) * (isPro ? 2 : 1)
    }

    // MARK: ステージ

    func stars(of stageID: String) -> Int { stageStars[stageID] ?? 0 }

    /// ステージを解いたとき。はじめてのクリアと、増えた星の分だけおやつ
    @discardableResult
    mutating func recordStage(_ stageID: String, stars: Int, eaten: Int, isPro: Bool) -> StageReward {
        gamesPlayed += 1
        totalEaten += eaten
        let prev = self.stars(of: stageID)
        var base = 0
        if prev == 0 && stars > 0 { base += Self.stageFirstClear }
        base += max(0, stars - prev) * Self.stagePerNewStar
        let total = Int((Double(base) * snackMultiplier(isPro: isPro)).rounded())
        snacks += total
        if stars > prev { stageStars[stageID] = stars }
        return StageReward(stars: stars, previousStars: prev, snacks: total)
    }

    /// ステージを遊べるか：1 つ前のステージを解いている（各ワールドの 1 番目は、前のワールドの最後を解いている）。Pro のワールドは Pro が要る
    /// ワールド 7〜8（ワールドパック）は、パックがあればワールド 1〜3 を解いたあとから遊べる（Pro のワールドを飛ばせる）
    /// ワールドの中は順番に。ワールドの 1 番目は、前のワールドの 12 番目（はじめの章）を解いていれば開く
    /// （どのワールドも 120 ステージあるので、前を全部解かなくても次の仕掛けに進める）
    static func gateStage(forWorld w: Int) -> String? {
        switch w {
        case 1: nil
        case 2...6: "\(w - 1)-12"
        case 7: "3-12"
        case 8: "7-12"
        default: nil
        }
    }

    func isUnlocked(_ stage: Stage, in book: [Stage], isPro: Bool, worldPack: Bool = false) -> Bool {
        let w = StageBook.world(stage.world)
        if w.isPro && !isPro { return false }
        if w.isPack && !worldPack { return false }
        if stage.index == 0 {
            guard let gate = Self.gateStage(forWorld: stage.world) else { return true }
            return self.stars(of: gate) > 0
        }
        guard let prev = book.first(where: { $0.world == stage.world && $0.index == stage.index - 1 }) else { return false }
        return self.stars(of: prev.id) > 0
    }

    func totalStars(world: Int, in book: [Stage]) -> Int {
        book.filter { $0.world == world }.reduce(0) { $0 + stars(of: $1.id) }
    }

    // MARK: カプセル

    /// おやつを使ってなかまを 1 匹よぶ。足りなければ nil
    mutating func pull<G: RandomNumberGenerator>(using rng: inout G, day: String = "") -> PullResult? {
        guard canPull() else { return nil }
        snacks -= Self.capsuleCost
        return drawOne(using: &rng, day: day, floor: .common)
    }

    func canPullTen() -> Bool { snacks >= Self.tenPullCost }

    /// 10 回まとめてよぶ。足りなければ nil
    mutating func pullTen<G: RandomNumberGenerator>(using rng: inout G, day: String = "") -> [PullResult]? {
        guard canPullTen() else { return nil }
        snacks -= Self.tenPullCost
        var out: [PullResult] = []
        for i in 0..<10 {
            let gotRare = out.contains { $0.character.rarity != .common }
            out.append(drawOne(using: &rng, day: day, floor: i == 9 && !gotRare ? .rare : .common))
        }
        return out
    }

    /// 天井まであと何回（この回数目でピックアップの子が出る）
    var pullsUntilPity: Int { max(1, Self.pityLimit - sinceSuperRare) }

    private mutating func drawOne<G: RandomNumberGenerator>(using rng: inout G, day: String, floor: Rarity) -> PullResult {
        pulls += 1
        let pick = Self.pickup(day: day)
        let c = sinceSuperRare + 1 >= Self.pityLimit ? pick : Self.draw(using: &rng, pickup: pick, floor: floor)
        sinceSuperRare = c.rarity == .superRare ? 0 : sinceSuperRare + 1
        let isPickup = c.id == pick.id
        guard owned.contains(c.id) else {
            owned.insert(c.id)
            levels[c.id] = 1
            return PullResult(character: c, isNew: true, levelUp: nil, refund: 0, isPickup: isPickup)
        }
        let lv = level(of: c)
        if lv < Roster.maxLevel {
            levels[c.id] = lv + 1
            return PullResult(character: c, isNew: false, levelUp: lv + 1, refund: 0, isPickup: isPickup)
        }
        snacks += Self.maxLevelRefund
        return PullResult(character: c, isNew: false, levelUp: nil, refund: Self.maxLevelRefund, isPickup: isPickup)
    }

    // MARK: ピックアップ（週がわり。月曜にかわる）

    /// 1970-01-01（木曜）からの日数
    static func dayNumber(_ day: String) -> Int {
        let p = day.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return 0 }
        // 年月日から日数（グレゴリオ暦。タイムゾーンに左右されない）
        let y = p[1] <= 2 ? p[0] - 1 : p[0]
        let m = p[1] <= 2 ? p[1] + 12 : p[1]
        let days = 365 * y + y / 4 - y / 100 + y / 400 + (153 * (m - 3) + 2) / 5 + p[2] - 1
        return days - 719_468
    }
    static func pickupWeek(day: String) -> Int { (dayNumber(day) + 3) / 7 }
    /// ピックアップがかわるまでの日数（1〜7）
    static func pickupDaysLeft(day: String) -> Int { 7 - (dayNumber(day) + 3) % 7 }
    static var superRares: [Character] { Roster.capsulePool.filter { $0.rarity == .superRare } }
    static func pickup(day: String) -> Character {
        let list = superRares
        let w = pickupWeek(day: day)
        return list[((w % list.count) + list.count) % list.count]
    }
    /// スーパーレアの合計のうち、ピックアップの子の分
    static let pickupShare = 0.5

    /// floor：その回で出る等級の下限（10 回目の確定は .rare。ふつうの分はレアにまわる）
    static func rarityRates(floor: Rarity = .common) -> [(Rarity, Double)] {
        let sr = Rarity.superRare.pullRate
        if floor == .rare { return [(.superRare, sr), (.rare, 1 - sr)] }
        return [(.superRare, sr), (.rare, Rarity.rare.pullRate), (.common, Rarity.common.pullRate)]
    }

    static func draw<G: RandomNumberGenerator>(using rng: inout G, pickup: Character, floor: Rarity = .common) -> Character {
        let roll = Double.random(in: 0..<1, using: &rng)
        var acc = 0.0
        var chosen: Character?
        for c in Roster.capsulePool {
            acc += rate(of: c, pickup: pickup, floor: floor)
            if roll < acc { chosen = c; break }
        }
        return chosen ?? pickup
    }

    /// 1 匹ごとの確率（画面の表と抽選が同じ値を使う）
    static func rate(of c: Character, pickup: Character, floor: Rarity = .common) -> Double {
        guard let total = rarityRates(floor: floor).first(where: { $0.0 == c.rarity })?.1 else { return 0 }
        let same = Roster.capsulePool.filter { $0.rarity == c.rarity }
        if c.rarity == .superRare {
            if c.id == pickup.id { return total * pickupShare }
            return total * (1 - pickupShare) / Double(same.count - 1)
        }
        return total / Double(same.count)
    }

    static func rate(of c: Character, day: String = "") -> Double { rate(of: c, pickup: pickup(day: day)) }

    mutating func select(_ c: Character, isPro: Bool, friendPack: Bool = false) -> Bool {
        guard owns(c, isPro: isPro, friendPack: friendPack) else { return false }
        selected = c.id
        return true
    }

    /// Pro が外れた（返金など）ときは、Pro 限定のなかまと台を元に戻す
    mutating func normalize(isPro: Bool, friendPack: Bool = false) {
        if !owns(selectedCharacter, isPro: isPro, friendPack: friendPack) { selected = Roster.starterID }
        if !isPro, table.isPro { table = .blue }
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
