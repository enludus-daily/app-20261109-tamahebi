import SwiftUI

enum PlayMode: Equatable, Sendable {
    case daily(String)   // 日付（YYYY-MM-DD）
    case random(UInt32)

    var seed: UInt32 {
        switch self {
        case .daily(let day): SeededRandom.seed(from: "tamahebi-" + day)
        case .random(let s): s
        }
    }
    var isDaily: Bool { if case .daily = self { true } else { false } }
}

enum Route: Equatable {
    case home, game, collection, capsule
}

/// アプリ全体の状態：進み具合（端末に保存）・課金・いまの画面
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

    var isPro: Bool { store.entitlements.isPro }
    var today: String { Progress.dayKey(Date()) }

    init(defaults: UserDefaults = .standard) {
        bundleID = Bundle.main.bundleIdentifier ?? "com.enludus.daily.006"
        let pro = ProductID.pro(bundleID: bundleID)
        store = PurchaseStore(productIDs: [pro], proProductIDs: [pro])
        if let data = defaults.data(forKey: Self.key), let p = try? JSONDecoder().decode(Progress.self, from: data) {
            progress = p
        } else {
            progress = Progress()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(progress) { UserDefaults.standard.set(data, forKey: Self.key) }
    }

    func onLaunch() async {
        await store.load()
        progress.normalize(isPro: isPro)
    }

    // MARK: 遊ぶ

    func play(_ mode: PlayMode) {
        game = GameModel(mode: mode, character: progress.selectedCharacter, table: progress.table)
        route = .game
    }

    func playDaily() { play(.daily(today)) }
    func playRandom() { play(.random(UInt32.random(in: 0...UInt32.max))) }

    func replay() {
        guard let g = game else { return playDaily() }
        if case .random = g.mode { playRandom() } else { play(g.mode) }
    }

    /// 遊び終わりに GameModel から呼ばれる
    func finish(_ g: GameModel) -> Reward {
        let day: String = { if case .daily(let d) = g.mode { d } else { today } }()
        let reward = progress.recordGame(score: g.engine.score, eaten: g.engine.eaten, isDaily: g.mode.isDaily, day: day, isPro: isPro)
        return reward
    }

    /// 価値を感じた直後（2 回目に遊び終えたとき）に 1 回だけ Pro を見せる
    func maybeShowProAfterGame() {
        guard !isPro, !progress.hasSeenPaywall, progress.gamesPlayed >= 2 else { return }
        progress.hasSeenPaywall = true
        showPro = true
    }

    // MARK: なかま

    func select(_ c: Character) {
        _ = progress.select(c, isPro: isPro)
    }

    func pull() -> PullResult? {
        var rng = SystemRandomNumberGenerator()
        return progress.pull(using: &rng)
    }

    func refreshAfterPurchase() {
        progress.normalize(isPro: isPro)
    }

    // MARK: 撮影用（CI のスクリーンショット。起動引数 -screenshotScene <名前>）

    func applyScreenshotScene(_ scene: String) {
        switch scene {
        case "game":
            play(.daily("2026-11-09"))
            game?.demoAim()
        case "result":
            progress.gamesPlayed = 0
            play(.daily("2026-11-09"))
            game?.autoplayToEnd(app: self)
        case "collection":
            progress.owned = ["tama", "mint", "soda", "kurosuke", "wataame", "kirari"]
            route = .collection
        case "capsule":
            progress.snacks = 480
            route = .capsule
        case "pro":
            showPro = true
        default:
            progress.streak = 3
            progress.bestByDay[today] = 184
        }
    }
}
