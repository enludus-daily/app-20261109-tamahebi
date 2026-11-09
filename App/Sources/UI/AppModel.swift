import SwiftUI

enum PlayMode: Equatable, Sendable {
    case daily(String)   // 日付（YYYY-MM-DD）
    case random(UInt32)
    case stage(Stage)

    var seed: UInt32 {
        switch self {
        case .daily(let day): SeededRandom.seed(from: "tamahebi-" + day)
        case .random(let s): s
        case .stage: 0
        }
    }
    var isDaily: Bool { if case .daily = self { true } else { false } }
    var stage: Stage? { if case .stage(let s) = self { s } else { nil } }
}

enum Route: Equatable {
    case home, game, collection, capsule, worlds
    case stages(Int)
}

/// アプリ全体の状態：進み具合（端末に保存）・課金・ステージ・いまの画面
@MainActor
@Observable
final class AppModel {
    private static let key = "progress.v1"

    var progress: Progress { didSet { save() } }
    var route: Route = .home
    var showPro = false
    var game: GameModel?
    let store: PurchaseStore
    let bundleID: String
    let book: [Stage]

    var isPro: Bool { store.entitlements.isPro }
    var worldPackID: String { ProductID.pack("worlds", bundleID: bundleID) }
    var friendPackID: String { ProductID.pack("friends", bundleID: bundleID) }
    /// ワールド 7〜8（24 ステージ）
    var hasWorldPack: Bool { store.entitlements.has(worldPackID) }
    /// おやつ三姉妹（なかま 3 匹）
    var hasFriendPack: Bool { store.entitlements.has(friendPackID) }

    func owns(_ c: Character) -> Bool { progress.owns(c, isPro: isPro, friendPack: hasFriendPack) }
    var ownedCount: Int { Roster.all.filter(owns).count }
    var today: String { Progress.dayKey(Date()) }

    init(defaults: UserDefaults = .standard) {
        bundleID = Bundle.main.bundleIdentifier ?? "com.enludus.daily.006"
        let pro = ProductID.pro(bundleID: bundleID)
        store = PurchaseStore(productIDs: [pro, ProductID.pack("worlds", bundleID: bundleID), ProductID.pack("friends", bundleID: bundleID)],
                              proProductIDs: [pro])
        if let data = defaults.data(forKey: Self.key), let p = try? JSONDecoder().decode(Progress.self, from: data) {
            progress = p
        } else {
            progress = Progress()
        }
        if let url = Bundle.main.url(forResource: "stages", withExtension: "json"),
           let data = try? Data(contentsOf: url), let b = try? StageBook.decode(data) {
            book = b
        } else {
            book = []
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(progress) { UserDefaults.standard.set(data, forKey: Self.key) }
    }

    func onLaunch() async {
        await store.load()
        progress.normalize(isPro: isPro, friendPack: hasFriendPack)
    }

    // MARK: ステージ

    func stages(in world: Int) -> [Stage] { book.filter { $0.world == world } }

    func isUnlocked(_ s: Stage) -> Bool { progress.isUnlocked(s, in: book, isPro: isPro, worldPack: hasWorldPack) }

    /// お金で開くワールドで、まだ買っていない
    func isLockedBehindPurchase(_ w: World) -> Bool { (w.isPro && !isPro) || (w.isPack && !hasWorldPack) }

    /// 次に遊ぶステージ（まだ解いていない最初の、遊べるステージ）
    var nextStage: Stage? {
        book.first { progress.stars(of: $0.id) == 0 && isUnlocked($0) }
    }

    func stage(after s: Stage) -> Stage? {
        guard let i = book.firstIndex(where: { $0.id == s.id }), i + 1 < book.count else { return nil }
        return book[i + 1]
    }

    var totalStageStars: Int { book.reduce(0) { $0 + progress.stars(of: $1.id) } }

    // MARK: 遊ぶ

    func play(_ mode: PlayMode, hint: Bool = false) {
        let (look, rules) = progress.playable(progress.selectedCharacter)
        var hintRules = Rules.standard
        hintRules.bumpersWaitWhileResting = true
        game = GameModel(mode: mode, character: look, rules: hint ? hintRules : rules, table: progress.table, hintMode: hint)
        route = .game
    }

    // MARK: ヒント

    func hintPrice(for s: Stage) -> Progress.HintPrice { progress.hintPrice(for: s.id, day: today, isPro: isPro) }

    /// ヒントを開けて、おてほんモードで最初から
    @discardableResult
    func playWithHint(_ s: Stage) -> Bool {
        guard progress.unlockHint(for: s.id, day: today, isPro: isPro) else { return false }
        play(.stage(s), hint: true)
        return true
    }

    func playDaily() { play(.daily(today)) }
    func playRandom() { play(.random(UInt32.random(in: 0...UInt32.max))) }
    func playStage(_ s: Stage) {
        guard isUnlocked(s) else { showPro = isLockedBehindPurchase(StageBook.world(s.world)); return }
        play(.stage(s))
    }

    func replay() {
        guard let g = game else { return playDaily() }
        if case .random = g.mode { playRandom() } else { play(g.mode, hint: g.hintMode) }
    }

    func leaveGame() {
        if let s = game?.mode.stage { route = .stages(s.world) } else { route = .home }
    }

    /// 遊び終わりに GameModel から呼ばれる
    func finish(_ g: GameModel) -> GameModel.Summary {
        if let s = g.mode.stage {
            let stars: Int = { if case .cleared(let n) = g.engine.outcome { n } else { 0 } }()
            let r = progress.recordStage(s.id, stars: stars, eaten: g.engine.eaten, isPro: isPro)
            return .stage(r)
        }
        let day: String = { if case .daily(let d) = g.mode { d } else { today } }()
        return .daily(progress.recordGame(score: g.engine.score, eaten: g.engine.eaten, isDaily: g.mode.isDaily, day: day, isPro: isPro))
    }

    /// 価値を感じた直後に 1 回だけ Pro を見せる：無料のステージ（ワールド 3）を最後まで解いたとき、か、遊び終わり 5 回目
    func maybeShowProAfterGame(_ g: GameModel) {
        guard !isPro, !progress.hasSeenPaywall else { return }
        let finishedFree = g.mode.stage?.id == "3-12" && progress.stars(of: "3-12") > 0
        guard finishedFree || progress.gamesPlayed >= 5 else { return }
        progress.hasSeenPaywall = true
        showPro = true
    }

    // MARK: なかま

    func select(_ c: Character) {
        _ = progress.select(c, isPro: isPro, friendPack: hasFriendPack)
    }

    func wear(_ k: Costume, on c: Character) {
        _ = progress.wear(k, on: c)
    }

    func pull() -> PullResult? {
        var rng = SystemRandomNumberGenerator()
        return progress.pull(using: &rng)
    }

    func refreshAfterPurchase() {
        progress.normalize(isPro: isPro, friendPack: hasFriendPack)
    }

    // MARK: 撮影用（CI のスクリーンショット。起動引数 -screenshotScene <名前>）

    func applyScreenshotScene(_ scene: String) {
        func sample() {
            progress.owned = ["tama", "mint", "soda", "momo", "kurosuke", "wataame", "kirari"]
            progress.levels = ["tama": 3, "mint": 2, "kurosuke": 4, "momo": 1, "soda": 1, "wataame": 1, "kirari": 2]
            for s in book.prefix(9) { progress.stageStars[s.id] = [3, 3, 2, 3, 1, 3, 2, 3, 2][book.firstIndex(of: s)! % 9] }
        }
        switch scene {
        case "game":
            sample()
            if let s = book.first(where: { $0.id == "2-4" }) { play(.stage(s)) }
            game?.demoAim()
        case "hint":
            sample()
            if let s = book.first(where: { $0.id == "2-8" }) { play(.stage(s), hint: true) }
        case "daily":
            play(.daily("2026-11-09"))
            game?.demoAim()
        case "result":
            sample()
            if let s = book.first(where: { $0.id == "1-10" }) { play(.stage(s)); game?.autoplaySolution(app: self) }
        case "worlds":
            sample()
            route = .worlds
        case "stages":
            sample()
            route = .stages(1)
        case "collection":
            sample()
            route = .collection
        case "capsule":
            sample()
            progress.snacks = 480
            route = .capsule
        case "pro", "shop":
            showPro = true
        default:
            sample()
            progress.streak = 3
            progress.bestByDay[today] = 184
        }
    }
}
