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
    let ads: RewardedAds
    let bundleID: String
    let book: [Stage]
    /// チュートリアル（ワールド 0。T-1〜T-3）
    let tutorial: [Stage]
    /// 常に出すバナーの広告ユニット。Pro・チュートリアル中・広告が使えないときは nil
    var bannerUnitID: String? {
        guard !isPro, !isInTutorial, progress.tutorialDone else { return nil }
        return ads.bannerUnitID
    }

    /// 次に結果から進むとき、全画面広告をはさむ（AdSchedule で決める。Pro は出さない）
    private(set) var interstitialDue = false
    /// チュートリアルを終えた直後のお知らせ
    var showTutorialDone = false

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

    /// 起動引数 -demo：YouTube の録画用に、見どころを人の操作なしで再生する（保存データは読み書きしない）
    let isDemo = ProcessInfo.processInfo.arguments.contains("-demo")
    /// デモで遊ぶステージ（からだで跳ね返る・2 こ続けてボーナスショットが 2 回・3 打で星 3）
    static let demoStageID = "1-22"

    init(defaults: UserDefaults = .standard) {
        bundleID = Bundle.main.bundleIdentifier ?? "com.enludus.daily.006"
        let pro = ProductID.pro(bundleID: bundleID)
        // テスト・CI の撮影では広告を出さない
        let quiet = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || defaults.string(forKey: "screenshotScene") != nil
            || ProcessInfo.processInfo.arguments.contains("-demo")
        ads = quiet ? NoAds() : AdMobRewarded()
        store = PurchaseStore(productIDs: [pro, ProductID.pack("worlds", bundleID: bundleID), ProductID.pack("friends", bundleID: bundleID)],
                              proProductIDs: [pro])
        if ProcessInfo.processInfo.arguments.contains("-demo") {
            // 見本のデータ（保存しない）
            var p = Progress()
            p.tutorialDone = true
            p.owned = ["tama", "mint", "soda", "momo", "kurosuke", "wataame", "kirari"]
            progress = p
        } else if let data = defaults.data(forKey: Self.key), let p = try? JSONDecoder().decode(Progress.self, from: data) {
            progress = p
        } else {
            progress = Progress()
        }
        if let url = Bundle.main.url(forResource: "stages", withExtension: "json"),
           let data = try? Data(contentsOf: url), let b = try? StageBook.decode(data) {
            book = b.filter { $0.world > 0 }
            tutorial = b.filter { $0.world == 0 }
        } else {
            book = []
            tutorial = []
        }
    }

    private func save() {
        guard !isDemo else { return }
        if let data = try? JSONEncoder().encode(progress) { UserDefaults.standard.set(data, forKey: Self.key) }
    }

    func onLaunch() async {
        if isDemo {
            startDemo()
            return
        }
        if !progress.tutorialDone, route == .home, game == nil, UserDefaults.standard.string(forKey: "screenshotScene") == nil {
            startTutorial()
        }
        await store.load()
        // 広告の同意とトラッキングの許可は、チュートリアルを終えてからたずねる（はじめの操作の上に出さない）
        if progress.tutorialDone { Task { await ads.prepare() } }
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

    // MARK: リワード広告

    /// 動画を見て、そのステージのヒントを開ける
    @discardableResult
    func watchAdForHint(_ s: Stage) async -> Bool {
        guard await ads.show() else { return false }
        progress.hintedStages.insert(s.id)
        play(.stage(s), hint: true)
        return true
    }

    /// 動画を見て、さっきもらったおやつをもう一度もらう（2 倍）
    func watchAdForDouble(_ amount: Int) async -> Bool {
        guard amount > 0, await ads.show() else { return false }
        progress.snacks += amount
        return true
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

    // MARK: デモ（-demo）

    func startDemo() {
        guard let s = book.first(where: { $0.id == Self.demoStageID }) else { return }
        var rules = Rules.standard
        rules.bumpersWaitWhileResting = true
        let g = GameModel(mode: .stage(s), character: Roster.character(Roster.starterID), rules: rules, table: .blue, demo: true)
        game = g
        route = .game
        Task { await g.runDemo() }
    }

    // MARK: チュートリアル

    func startTutorial() {
        guard let first = tutorial.first else { progress.tutorialDone = true; return }
        play(.stage(first), hint: true)
    }

    var isInTutorial: Bool { game?.mode.stage?.world == 0 }

    /// チュートリアルの 1 つを解いたあと：次へ、最後なら終わり
    func advanceTutorial(after s: Stage) {
        if let i = tutorial.firstIndex(where: { $0.id == s.id }), i + 1 < tutorial.count {
            play(.stage(tutorial[i + 1]), hint: true)
        } else {
            finishTutorial()
        }
    }

    static let tutorialGift = 100

    func finishTutorial() {
        if !progress.tutorialDone {
            Task { await ads.prepare() }
            progress.tutorialDone = true
            progress.snacks += Self.tutorialGift
            showTutorialDone = true
        }
        game = nil
        route = .home
    }

    // MARK: 全画面広告（3 回遊ぶごと）

    /// 結果のボタンから次へ進むとき。最初の 10 回は出さず、11 回目からは 5 回ごとに全画面広告をはさむ（Pro は出さない）
    func continueFromResult(_ next: @escaping @MainActor () -> Void) {
        guard !isPro, interstitialDue else { next(); return }
        interstitialDue = false
        Task {
            await ads.showInterstitial()
            next()
        }
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
        if g.mode.stage?.world != 0 {
            progress.adPlays += 1
            interstitialDue = AdSchedule.shouldShowInterstitial(afterPlay: progress.adPlays)
        }
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
        return progress.pull(using: &rng, day: today)
    }

    func pullTen() -> [PullResult]? {
        var rng = SystemRandomNumberGenerator()
        return progress.pullTen(using: &rng, day: today)
    }

    /// 今週のピックアップの子
    var pickup: Character { Progress.pickup(day: today) }

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
        case "tutorial":
            if let t = tutorial.first { play(.stage(t), hint: true) }
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
