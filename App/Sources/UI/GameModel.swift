import SwiftUI

/// 1 回の遊び。GameEngine を時間で進め、出来事を振動・表情・飛び出す文字にする
@MainActor
@Observable
final class GameModel {
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
    private(set) var reward: Reward?
    private(set) var shake = 0.0
    var onFinish: ((GameModel) -> Void)?

    static let maxPull: CGFloat = 120

    init(mode: PlayMode, character: Character, table: TableTheme) {
        self.mode = mode
        self.character = character
        self.table = table
        engine = GameEngine(seed: mode.seed, rules: character.rules)
    }

    var isAiming: Bool { aimStart != nil }

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

    // MARK: 操作

    func beginAim(at p: CGPoint) {
        guard engine.canShoot, reward == nil else { return }
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
    }

    func endAim() {
        defer { aimStart = nil; aimNow = nil }
        guard let a = aim else { return }
        if engine.shoot(direction: a.direction, power: a.power) {
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
        shake = max(0, shake - dt)
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

    private func handle(_ e: GameEvent) {
        switch e {
        case .rail(let speed):
            Feedback.rail(speed: speed)
        case .bumper:
            Feedback.bumper()
            setFace(.bonk, for: 0.35)
        case .bodyBounce(let at):
            Feedback.body()
            sparks.append(Spark(at: CGPoint(x: at.x, y: at.y), velocity: .zero, color: .white, born: clock, ring: true))
            setFace(.bonk, for: 0.35)
        case .eat(let number, let combo, let points, let at):
            Feedback.eat(combo: combo)
            setFace(.happy, for: 0.7)
            let c = CGPoint(x: at.x, y: at.y)
            pops.append(Pop(text: (combo > 1 ? "×\(combo) " : "") + "+\(points)", at: c,
                            color: number == 8 ? Theme.sun : .white, born: clock, big: false))
            for k in 0..<12 {
                let a = Double(k) / 12 * 2 * .pi
                sparks.append(Spark(at: c, velocity: CGVector(dx: cos(a) * 150, dy: sin(a) * 150), color: Theme.ball(number), born: clock, ring: false))
            }
        case .bonusShot:
            Feedback.bonus()
            pops.append(Pop(text: "ボーナスショット +1", at: CGPoint(x: engine.rules.width / 2, y: engine.rules.height * 0.42),
                            color: Theme.sun, born: clock, big: true))
        case .stopped(let ateAny):
            if !ateAny { setFace(.oops, for: 0.9); Feedback.miss() }
        case .finished:
            Feedback.finished()
            onFinish?(self)
        }
    }

    func setReward(_ r: Reward) { reward = r }

    // MARK: 撮影用

    func demoAim() {
        let h = CGPoint(x: engine.head.x, y: engine.head.y)
        aimStart = CGPoint(x: h.x, y: h.y - 40)
        aimNow = CGPoint(x: h.x + 30, y: h.y + 40)
    }

    func autoplayToEnd(app: AppModel) {
        var turn = 0
        while !engine.isFinished, turn < 40 {
            turn += 1
            let target = engine.balls.first.map { CGPoint(x: $0.center.x, y: $0.center.y) } ?? CGPoint(x: 180, y: 100)
            let d = Vec(x: target.x - engine.head.x, y: target.y - engine.head.y)
            engine.shoot(direction: d, power: 0.55)
            for _ in 0..<3000 where engine.isMoving { _ = engine.advance(by: 1.0 / 120) }
        }
        setReward(app.finish(self))
    }
}
