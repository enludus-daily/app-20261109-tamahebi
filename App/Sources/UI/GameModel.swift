import SwiftUI

/// 1 回の遊び。GameEngine を時間で進め、出来事を振動・表情・飛び出す文字にする
@MainActor
@Observable
final class GameModel {
    enum Summary: Equatable {
        case daily(Reward)
        case stage(StageReward)
    }
    struct Pop: Identifiable {
        let id = UUID()
        let text: String
        let at: CGPoint
        let color: Color
        let born: Double
        let big: Bool
    }
    struct Spark: Identifiable {
        let id = UUID()
        var at: CGPoint
        var velocity: CGVector
        let color: Color
        let born: Double
        let ring: Bool
    }

    let mode: PlayMode
    let character: Character
    let table: TableTheme
    /// おてほんモード：ステージの解き方を 1 打ずつ見せる（とくいはお休みにして、作ったときと同じ動きにする）
    let hintMode: Bool
    /// おてほんと違う打ち方をした
    private(set) var offPath = false
    private(set) var engine: GameEngine
    private(set) var aimStart: CGPoint?
    private(set) var aimNow: CGPoint?
    private(set) var pops: [Pop] = []
    private(set) var sparks: [Spark] = []
    private(set) var face: Face = .idle
    private var faceUntil = 0.0
    private(set) var clock = 0.0
    private var lastDate: Date?
    private var lastPowerStep = 0
    private(set) var summary: Summary?
    var onFinish: ((GameModel) -> Void)?

    static let maxPull: CGFloat = 120

    /// デモの再生中（指の丸を描く。人の操作は受けない）
    let isDemo: Bool

    init(mode: PlayMode, character: Character, rules: Rules, table: TableTheme, hintMode: Bool = false, demo: Bool = false) {
        self.isDemo = demo
        self.mode = mode
        self.character = character
        self.table = table
        self.hintMode = hintMode
        if let s = mode.stage {
            engine = GameEngine(stage: s, rules: rules)
        } else {
            engine = GameEngine(seed: mode.seed, rules: rules)
        }
    }

    var isAiming: Bool { aimStart != nil }

    /// いま見せるおてほんの 1 打
    var hintShot: Shot? {
        guard hintMode, !offPath, engine.canShoot, let s = mode.stage, engine.shotsTaken < s.solution.count else { return nil }
        return s.solution[engine.shotsTaken]
    }

    var hintPreview: ShotPreview? {
        hintShot.map { engine.preview(direction: .angle($0.angle), power: $0.power) }
    }

    /// 引いている向きと強さが、おてほんに近い（離すと、おてほんどおりに打つ）。指で合わせやすいよう、幅は広め
    var aimMatchesHint: Bool {
        guard let h = hintShot, let a = aim else { return false }
        return a.direction.dot(.angle(h.angle)) > cos(12 * .pi / 180) && abs(a.power - h.power) < 0.15
    }

    /// 引いている間に見せる「ここまで引く」位置（台の座標。指を置いたところからの位置）
    var hintTarget: CGPoint? {
        guard let h = hintShot, let s = aimStart else { return nil }
        let d = Vec.angle(h.angle)
        return CGPoint(x: s.x - d.x * h.power * Self.maxPull, y: s.y - d.y * h.power * Self.maxPull)
    }

    private var wasMatching = false

    /// おてほんの 1 打を、そのまま打つ（ボタン）
    func shootHint() {
        guard let h = hintShot, summary == nil else { return }
        if engine.shoot(h) {
            Feedback.shot(power: h.power)
            setFace(.zoom, for: 0.2)
        }
    }

    /// 引いた量から、向きと強さ（0〜1）
    var aim: (direction: Vec, power: Double)? {
        guard let s = aimStart, let n = aimNow else { return nil }
        let dx = s.x - n.x, dy = s.y - n.y
        let d = hypot(dx, dy)
        guard d >= 1 else { return nil }
        return (Vec(x: dx / d, y: dy / d), min(Double(d / Self.maxPull), 1))
    }

    var preview: ShotPreview? {
        guard let a = aim, a.power >= engine.rules.minimumPower else { return nil }
        return engine.preview(direction: a.direction, power: a.power)
    }

    var currentFace: Face {
        if clock < faceUntil { return face }
        if isAiming { return .aim }
        if engine.isMoving { return engine.velocity.length > 350 ? .zoom : .roll }
        return .idle
    }

    /// おだいの進み具合（ステージ）
    var goalText: String? {
        guard let s = mode.stage else { return nil }
        switch s.goal.kind {
        case .eatAll: return String(localized: "のこり \(L.s(engine.balls.count)) こ")
        case .eatEight: return engine.ateEight ? String(localized: "8 番 OK！") : String(localized: "8 番球をねらえ")
        case .score: return "\(engine.score) / \(s.goal.target)"
        }
    }

    // MARK: 操作

    func beginAim(at p: CGPoint) {
        guard !isDemo, engine.canShoot, summary == nil else { return }
        aimStart = p
        aimNow = p
        lastPowerStep = 0
        Feedback.prepare()
    }

    func moveAim(to p: CGPoint) {
        guard aimStart != nil else { return }
        aimNow = p
        let step = Int((aim?.power ?? 0) * 5)
        if step != lastPowerStep { lastPowerStep = step; Feedback.aimTick() }
        let match = aimMatchesHint
        if match && !wasMatching { Feedback.bumper() }
        wasMatching = match
    }

    func endAim() {
        defer { aimStart = nil; aimNow = nil }
        guard let a = aim else { return }
        if let h = hintShot, aimMatchesHint {
            if engine.shoot(h) {
                Feedback.shot(power: h.power)
                setFace(.zoom, for: 0.2)
            }
            return
        }
        if engine.shoot(direction: a.direction, power: a.power) {
            if hintMode { offPath = true }
            Feedback.shot(power: a.power)
            setFace(.zoom, for: 0.2)
        }
    }

    func cancelAim() { aimStart = nil; aimNow = nil }

    // MARK: 時間

    func tick(_ date: Date) {
        let dt = lastDate.map { min(0.05, max(0, date.timeIntervalSince($0))) } ?? 0
        lastDate = date
        step(dt)
    }

    private func step(_ dt: Double) {
        clock += dt
        for e in engine.advance(by: dt) { handle(e) }
        for i in sparks.indices where !sparks[i].ring {
            sparks[i].at.x += sparks[i].velocity.dx * dt
            sparks[i].at.y += sparks[i].velocity.dy * dt
            sparks[i].velocity.dx *= 0.9
            sparks[i].velocity.dy *= 0.9
        }
        sparks.removeAll { clock - $0.born > 0.5 }
        pops.removeAll { clock - $0.born > 1.2 }
    }

    private func setFace(_ f: Face, for seconds: Double) {
        face = f
        faceUntil = clock + seconds
    }

    private func pop(_ text: String, at p: CGPoint, color: Color = .white, big: Bool = false) {
        pops.append(Pop(text: text, at: p, color: color, born: clock, big: big))
    }

    private var center: CGPoint { CGPoint(x: engine.rules.width / 2, y: engine.rules.height * 0.42) }

    private func handle(_ e: GameEvent) {
        switch e {
        case .rail(let speed):
            Feedback.rail(speed: speed)
        case .wall:
            Feedback.rail(speed: 600)
        case .wallBreak(let at):
            Feedback.bumper()
            let c = CGPoint(x: at.x, y: at.y)
            for k in 0..<10 {
                let a = Double(k) / 10 * 2 * .pi
                sparks.append(Spark(at: c, velocity: CGVector(dx: cos(a) * 120, dy: sin(a) * 120), color: Color(hex: 0xF7A9C4), born: clock, ring: false))
            }
            pop(String(localized: "パキッ"), at: c, color: Color(hex: 0xF7A9C4))
        case .pad(let at):
            Feedback.shot(power: 0.7)
            sparks.append(Spark(at: CGPoint(x: at.x, y: at.y), velocity: .zero, color: .white, born: clock, ring: true))
        case .bumper:
            Feedback.bumper()
            setFace(.bonk, for: 0.35)
        case .bodyBounce(let at):
            Feedback.body()
            sparks.append(Spark(at: CGPoint(x: at.x, y: at.y), velocity: .zero, color: .white, born: clock, ring: true))
            setFace(.bonk, for: 0.35)
        case .warp(let from, let to):
            Feedback.body()
            for p in [from, to] {
                sparks.append(Spark(at: CGPoint(x: p.x, y: p.y), velocity: .zero, color: .white, born: clock, ring: true))
            }
        case .fell(let at):
            Feedback.miss()
            setFace(.oops, for: 0.9)
            sparks.append(Spark(at: CGPoint(x: at.x, y: at.y), velocity: .zero, color: .white, born: clock, ring: true))
            pop(String(localized: "おちた！もどる"), at: CGPoint(x: at.x, y: at.y - 24), color: Color(hex: 0xC9A27E))
        case .ghostAwake:
            Feedback.bonus()
            pop(String(localized: "ゴースト球がおきた！"), at: CGPoint(x: engine.head.x, y: engine.head.y - 26), color: Color(hex: 0xC3B1EE))
        case .eat(let number, let combo, let points, let at):
            Feedback.eat(combo: combo)
            setFace(.happy, for: 0.7)
            let c = CGPoint(x: at.x, y: at.y)
            pop((combo > 1 ? "×\(combo) " : "") + "+\(points)", at: c, color: number == 8 ? Theme.sun : .white)
            for k in 0..<12 {
                let a = Double(k) / 12 * 2 * .pi
                sparks.append(Spark(at: c, velocity: CGVector(dx: cos(a) * 150, dy: sin(a) * 150), color: Theme.ball(number), born: clock, ring: false))
            }
        case .bonusShot:
            Feedback.bonus()
            pop(String(localized: "ボーナスショット +1"), at: center, color: Theme.sun, big: true)
        case .stopped(let ateAny):
            if !ateAny, !engine.isFinished { setFace(.oops, for: 0.9); Feedback.miss() }
        case .cleared:
            Feedback.finished()
            setFace(.full, for: 3)
            pop(String(localized: "クリア！"), at: center, color: Theme.sun, big: true)
            onFinish?(self)
        case .failed:
            Feedback.miss()
            setFace(.sad, for: 3)
            onFinish?(self)
        case .finished:
            Feedback.finished()
            onFinish?(self)
        }
    }

    func setSummary(_ s: Summary) { summary = s }

    // MARK: 撮影用

    /// デモ：ステージの ★3 の打ち方を、指で引くように見せてから打つ（15〜20 秒）
    func runDemo() async {
        guard let s = mode.stage else { return }
        try? await Task.sleep(for: .milliseconds(1400))
        for shot in s.solution {
            guard engine.canShoot else { break }
            let h = CGPoint(x: engine.head.x, y: engine.head.y)
            let d = Vec.angle(shot.angle)
            // 頭の少し横から指を置き、打つ向きと反対へ引く
            let start = CGPoint(x: min(max(h.x + 40, 40), engine.rules.width - 40), y: min(max(h.y + 30, 60), engine.rules.height - 60))
            let end = CGPoint(x: start.x - d.x * shot.power * Self.maxPull, y: start.y - d.y * shot.power * Self.maxPull)
            aimStart = start
            aimNow = start
            for i in 1...24 {
                let t = Double(i) / 24
                let e = 1 - pow(1 - t, 3)
                aimNow = CGPoint(x: start.x + (end.x - start.x) * e, y: start.y + (end.y - start.y) * e)
                try? await Task.sleep(for: .milliseconds(32))
            }
            try? await Task.sleep(for: .milliseconds(350))
            aimStart = nil
            aimNow = nil
            if engine.shoot(shot) {
                Feedback.shot(power: shot.power)
                setFace(.zoom, for: 0.2)
            }
            while engine.isMoving { try? await Task.sleep(for: .milliseconds(50)) }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }

    func demoAim() {
        let h = CGPoint(x: engine.head.x, y: engine.head.y)
        aimStart = CGPoint(x: h.x, y: h.y - 40)
        aimNow = CGPoint(x: h.x + 30, y: h.y + 40)
    }

    func autoplaySolution(app: AppModel) {
        guard let s = mode.stage else { return }
        for shot in s.solution where !engine.isFinished {
            engine.shoot(shot)
            _ = engine.runUntilStopped()
        }
        setSummary(app.finish(self))
    }
}
