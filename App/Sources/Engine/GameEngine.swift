import Foundation

// ゲームの中身（画面から切り離してテストする）。座標は台の内側の 360 × 560 の点。
// スネーク × ビリヤード：頭を打ち出すと、転がった跡がそのまま胴体になる。胴体はクッションとして跳ね返す。
// 遊び方は2つ：きょうの台（球が出つづけ、10 ショットの点を競う）と、ステージ（決まった配置で、おだいを解く）。

struct Vec: Equatable, Codable, Sendable {
    var x: Double
    var y: Double
    static let zero = Vec(x: 0, y: 0)
    var length: Double { (x * x + y * y).squareRoot() }
    func distance(to o: Vec) -> Double { Vec(x: x - o.x, y: y - o.y).length }
    static func + (a: Vec, b: Vec) -> Vec { Vec(x: a.x + b.x, y: a.y + b.y) }
    static func - (a: Vec, b: Vec) -> Vec { Vec(x: a.x - b.x, y: a.y - b.y) }
    static func * (a: Vec, k: Double) -> Vec { Vec(x: a.x * k, y: a.y * k) }
    func dot(_ o: Vec) -> Double { x * o.x + y * o.y }
    var normalized: Vec { let l = length; return l > 0 ? Vec(x: x / l, y: y / l) : .zero }
    static func angle(_ a: Double) -> Vec { Vec(x: cos(a), y: sin(a)) }
}

/// 同じ種なら同じ並びを返す乱数（きょうの台を、だれが遊んでも同じにする）。mulberry32。
struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt32
    init(seed: UInt32) { state = seed }
    mutating func next32() -> UInt32 {
        state = state &+ 0x6D2B79F5
        var t = state
        t = (t ^ (t >> 15)) &* (t | 1)
        t ^= t &+ ((t ^ (t >> 7)) &* (t | 61))
        return t ^ (t >> 14)
    }
    mutating func next() -> UInt64 { UInt64(next32()) << 32 | UInt64(next32()) }
    /// 0 以上 1 未満
    mutating func unit() -> Double { Double(next32()) / 4_294_967_296 }

    /// 文字列から種を作る（FNV-1a）
    static func seed(from text: String) -> UInt32 {
        var h: UInt32 = 2_166_136_261
        for b in text.utf8 { h ^= UInt32(b); h = h &* 16_777_619 }
        return h
    }
}

/// 台とヘビの決まり。キャラクターの「とくい」で一部が変わる。
struct Rules: Equatable, Sendable {
    var width = 360.0
    var height = 560.0
    var headRadius = 12.0
    var bodyRadius = 9.0
    var spacing = 3.0
    var restitution = 0.9
    var friction = 1.6         // 1 秒あたりの指数の減り
    var deceleration = 30.0    // 1 秒あたりの一定の減り（点/秒²）
    var maxSpeed = 1000.0
    var shots = 10
    var startLength = 110.0
    var growPerBall = 34.0
    var eatRadius = 22.0
    var ballCount = 4
    var eightBallChance = 0.12
    var bumperKick = 1.08
    var previewBounces = 3
    var minimumPower = 0.1
    /// こおりの台で、すべりやすさ（摩擦にかける数。小さいほどすべる）
    var iceFactor = 0.4
    /// ワープから出るときの速さの倍率
    var warpBoost = 1.0
    /// ステージでの、のこりショットの足し
    var extraStageShots = 0
    /// ゴースト球が、からだ以外（クッション・バンパー）で跳ねても目をさます
    var ghostWakesOnAnyBounce = false
    /// 8 番球を食べるとショット +1（ステージ）
    var eightGivesShot = false
    /// ステージのはじめの長さの足し
    var extraStartLength = 0.0
    /// 止まっている間、うごくバンパーも待つ（おてほんのときだけ。ふだんはずっと動くので、タイミングを考えて打つ）
    var bumpersWaitWhileResting = false
    /// かそく床で押し出される速さ
    var padSpeed = 760.0
    /// こわれるブロックが 1 回でこわれる
    var breaksInOneHit = false

    static let standard = Rules()
}

enum BallKind: String, Codable, Sendable {
    case normal
    /// からだで跳ね返ったあとでないと食べられない（ショットごとに眠る）
    case ghost
}

struct Bumper: Equatable, Sendable {
    var base: Vec
    var radius: Double
    /// 動くバンパー：base を中心に axis の向きへ、amplitude だけ、speed（ラジアン/秒）でゆれる
    var axis = Vec(x: 1, y: 0)
    var amplitude = 0.0
    var speed = 0.0
    var phase = 0.0
    var squash = 0.0

    func center(at t: Double) -> Vec {
        amplitude == 0 ? base : base + axis * (sin(t * speed + phase) * amplitude)
    }
}

struct Wall: Equatable, Codable, Sendable {
    var a: Vec
    var b: Vec
    /// こわれるブロック：あと何回当たるとこわれるか（0 はこわれないかべ）
    var hits = 0
    static let thickness = 5.0
    var breakable: Bool { hits > 0 }
}

/// かそく床：上を通ると、矢印の向きに勢いよく押し出す
struct Pad: Equatable, Codable, Sendable {
    var center: Vec
    var angle: Double
    static let radius = 18.0
    var direction: Vec { .angle(angle) }
}

/// 入口と出口の 2 つの穴。どちらから入っても、もう片方から同じ速さで出る
struct Warp: Equatable, Codable, Sendable {
    var a: Vec
    var b: Vec
    static let radius = 15.0
}

struct TableBall: Equatable, Sendable {
    var center: Vec
    var number: Int      // 1〜8。8 番は 30 点
    var kind: BallKind = .normal
    var born: Double
    var phase: Double
    var points: Int { number == 8 ? 30 : 10 }
}

enum GameEvent: Equatable, Sendable {
    case rail(speed: Double)
    case bumper(index: Int)
    case bodyBounce(at: Vec)
    case wall
    case wallBreak(at: Vec)
    case pad(at: Vec)
    case warp(from: Vec, to: Vec)
    case ghostAwake
    case eat(number: Int, combo: Int, points: Int, at: Vec)
    case bonusShot
    case stopped(ateAny: Bool)
    case finished
    case cleared(stars: Int)
    case failed
}

struct ShotPreview: Equatable, Sendable {
    var points: [Vec]
    var end: Vec
    /// 止まるところまで見えているか（反射の回数の上限で切れていない）
    var reachesStop: Bool
}

enum Outcome: Equatable, Sendable {
    case finished          // きょうの台：ショットを使い切った
    case cleared(stars: Int)
    case failed
}

struct GameEngine: Sendable {
    let rules: Rules
    let stage: Stage?
    private var rng: SeededRandom

    private(set) var head: Vec
    private(set) var velocity: Vec = .zero
    private(set) var direction = Vec(x: 0, y: -1)
    /// 胴体の点。先頭が尻尾、最後が頭のすぐ後ろ
    private(set) var path: [Vec] = []
    /// path[i] の手前でワープした（path[i-1] と線でつながない）
    private(set) var jumps: [Bool] = []
    private(set) var pathLength = 0.0
    private(set) var targetLength: Double
    private(set) var shotsLeft: Int
    private(set) var shotsTaken = 0
    private(set) var score = 0
    private(set) var eaten = 0
    private(set) var combo = 0
    private(set) var bestCombo = 0
    private(set) var isMoving = false
    private(set) var outcome: Outcome?
    private(set) var bumpers: [Bumper] = []
    private(set) var walls: [Wall] = []
    private(set) var warps: [Warp] = []
    private(set) var pads: [Pad] = []
    private(set) var balls: [TableBall] = []
    private(set) var time = 0.0
    private(set) var ghostsAwake = false
    private(set) var goalMet = false
    private(set) var ateEight = false
    private var warpLock: Int?
    private var padLock: Int?
    private var bouncedThisShot = false
    private var accumulator = 0.0
    /// 止まっている間の時間（球の出てくる動きなど、見た目だけに使う）
    private(set) var idleTime = 0.0
    /// 見た目の時計（物理の時間 + 止まっている間の時間）
    var clock: Double { time + idleTime }

    var isFinished: Bool { outcome != nil }
    var isIce: Bool { stage?.ice ?? false }

    /// きょうの台・ランダム台
    init(seed: UInt32, rules: Rules = .standard) {
        self.rules = rules
        self.stage = nil
        self.rng = SeededRandom(seed: seed)
        head = Vec(x: rules.width / 2, y: rules.height * 0.75)
        targetLength = rules.startLength
        shotsLeft = rules.shots
        var y = head.y + rules.startLength
        while y >= head.y { appendPoint(Vec(x: head.x, y: y)); y -= rules.spacing }
        placeBumpers()
        for _ in 0..<rules.ballCount { spawnBall() }
    }

    /// ステージ（配置はすべて Stage から。乱数は使わない）
    init(stage: Stage, rules: Rules = .standard) {
        self.rules = rules
        self.stage = stage
        self.rng = SeededRandom(seed: 1)
        head = stage.head
        shotsLeft = stage.shots + rules.extraStageShots
        bumpers = stage.bumpers.map { Bumper(base: $0.center, radius: $0.radius, axis: $0.axis.normalized, amplitude: $0.amplitude, speed: $0.speed, phase: $0.phase) }
        walls = stage.walls
        warps = stage.warps
        pads = stage.pads
        balls = stage.balls.enumerated().map { TableBall(center: $1.center, number: $1.number, kind: $1.kind, born: 0, phase: Double($0) * 1.7) }
        // はじめのからだ：折れ線を spacing ごとに打つ
        let line = stage.body + [stage.head]
        var pts: [Vec] = []
        for i in 1..<max(line.count, 1) {
            let a = line[i - 1], b = line[i]
            let n = max(1, Int((a.distance(to: b) / rules.spacing).rounded()))
            for k in 0..<n { pts.append(a + (b - a) * (Double(k) / Double(n))) }
        }
        pts.append(stage.head)
        var total = 0.0
        for i in 1..<pts.count { total += pts[i].distance(to: pts[i - 1]) }
        targetLength = max(total, 20) + rules.extraStartLength
        if rules.extraStartLength > 0, let first = pts.first, pts.count > 1 {
            // 尻尾の先に、同じ向きで足す
            let dir = (first - pts[1]).normalized
            var extra: [Vec] = []
            var d = rules.spacing
            while d <= rules.extraStartLength {
                let p = first + dir * d
                if p.x < 2 || p.y < 2 || p.x > rules.width - 2 || p.y > rules.height - 2 { break }
                extra.insert(p, at: 0)
                d += rules.spacing
            }
            pts = extra + pts
        }
        for p in pts { appendPoint(p) }
    }

    var canShoot: Bool { !isMoving && !isFinished && shotsLeft > 0 }

    static func stars(for score: Int) -> Int {
        switch score {
        case 260...: 3
        case 150...: 2
        case 70...: 1
        default: 0
        }
    }

    // MARK: 打つ

    /// direction は向き（長さは問わない）、power は 0〜1。弱すぎるときは打たずに false
    @discardableResult
    mutating func shoot(direction d: Vec, power: Double) -> Bool {
        guard canShoot, d.length > 0 else { return false }
        let p = min(max(power, 0), 1)
        guard p >= rules.minimumPower else { return false }
        let n = d.normalized
        velocity = n * (p * rules.maxSpeed)
        direction = n
        isMoving = true
        shotsLeft -= 1
        shotsTaken += 1
        combo = 0
        ghostsAwake = false
        bouncedThisShot = false
        return true
    }

    @discardableResult
    mutating func shoot(_ shot: Shot) -> Bool { shoot(direction: .angle(shot.angle), power: shot.power) }

    /// 止まるまで進める（テスト・ステージの検査用）
    mutating func runUntilStopped(maxSeconds: Double = 12) -> [GameEvent] {
        var all: [GameEvent] = []
        var t = 0.0
        while isMoving, t < maxSeconds {
            all += advance(by: Self.tick)
            t += Self.tick
        }
        return all
    }

    func preview(direction d: Vec, power: Double) -> ShotPreview {
        guard d.length > 0 else { return ShotPreview(points: [], end: head, reachesStop: true) }
        let p = min(max(power, 0), 1)
        var ball = Mover(position: head, velocity: d.normalized * (p * rules.maxSpeed), warpLock: warpLock, padLock: padLock)
        var field = makeField()
        var pts: [Vec] = []
        var bounces = 0
        let limit = neckIndex
        for i in 0..<1500 {
            let r = Self.step(&ball, dt: 1.0 / 150, rules: rules, field: &field, body: path, bodyLimit: limit)
            field.time += 1.0 / 150
            if i % 4 == 0 || r.warped != nil { pts.append(ball.position) }
            if let h = r.hit, h != .warp, h != .pad { bounces += 1; if bounces >= rules.previewBounces { break } }
            if r.stopped { break }
        }
        return ShotPreview(points: pts, end: ball.position, reachesStop: bounces < rules.previewBounces)
    }

    // MARK: 時間を進める

    /// 物理は 1/240 秒の決まった刻みで進める（画面の速さが違っても、ステージを作ったときと同じ動きになる）。
    /// うごくバンパーはふだんずっと動く。おてほんのときだけ、止まっている間は待つ（作ったときと同じ動きにする）
    static let tick = 1.0 / 240

    mutating func advance(by dt: Double) -> [GameEvent] {
        guard dt > 0 else { return [] }
        for i in bumpers.indices { bumpers[i].squash = max(0, bumpers[i].squash - dt * 5) }
        guard isMoving else {
            accumulator = 0
            if rules.bumpersWaitWhileResting || stage == nil { idleTime += dt } else { time += dt }
            return []
        }
        var events: [GameEvent] = []
        accumulator += dt
        while accumulator >= Self.tick - 1e-9, isMoving {
            accumulator -= Self.tick
            physicsStep(Self.tick, events: &events)
        }
        return events
    }

    private var neckIndex: Int {
        path.count - 1 - (Int(((rules.headRadius + rules.bodyRadius + 8) / rules.spacing).rounded(.up)) + 2)
    }

    private func makeField() -> Field {
        Field(bumpers: bumpers, walls: walls, warps: warps, pads: pads, time: time, ice: isIce)
    }

    private mutating func physicsStep(_ dt: Double, events: inout [GameEvent]) {
        var ball = Mover(position: head, velocity: velocity, warpLock: warpLock, padLock: padLock)
        var field = makeField()
        let r = Self.step(&ball, dt: dt, rules: rules, field: &field, body: path, bodyLimit: neckIndex)
        time += dt
        bumpers = field.bumpers
        walls = field.walls
        head = ball.position
        velocity = ball.velocity
        warpLock = ball.warpLock
        padLock = ball.padLock
        if let at = r.broke { events.append(.wallBreak(at: at)) }
        if let at = r.padded { events.append(.pad(at: at)) }
        switch r.hit {
        case .rail: events.append(.rail(speed: r.speed)); bouncedThisShot = true
        case .bumper(let i): events.append(.bumper(index: i)); bouncedThisShot = true
        case .wall: events.append(.wall); bouncedThisShot = true
        case .pad: break
        case .body(let i):
            events.append(.bodyBounce(at: path[i]))
            if !ghostsAwake, balls.contains(where: { $0.kind == .ghost }) { ghostsAwake = true; events.append(.ghostAwake) }
            ghostsAwake = true
        case .warp, nil: break
        }
        if rules.ghostWakesOnAnyBounce, bouncedThisShot, !ghostsAwake {
            ghostsAwake = true
            if balls.contains(where: { $0.kind == .ghost }) { events.append(.ghostAwake) }
        }
        if let w = r.warped {
            events.append(.warp(from: w.from, to: w.to))
            appendPoint(head, jump: true)
        }
        let speed = velocity.length
        if speed > 1 { direction = velocity * (1 / speed) }
        if let last = path.last, head.distance(to: last) >= rules.spacing { appendPoint(head) }

        for i in balls.indices.reversed() where balls[i].center.distance(to: head) < rules.eatRadius {
            if balls[i].kind == .ghost, !ghostsAwake { continue }
            let ball = balls.remove(at: i)
            combo += 1
            eaten += 1
            bestCombo = max(bestCombo, combo)
            let pts = ball.points * combo
            score += pts
            targetLength += rules.growPerBall
            if ball.number == 8 { ateEight = true }
            events.append(.eat(number: ball.number, combo: combo, points: pts, at: ball.center))
            if combo == 2 { shotsLeft += 1; events.append(.bonusShot) }
            if ball.number == 8, rules.eightGivesShot, stage != nil { shotsLeft += 1; events.append(.bonusShot) }
            if stage == nil { spawnBall() }
            checkGoal()
        }

        if r.stopped {
            isMoving = false
            events.append(.stopped(ateAny: combo > 0))
            combo = 0
            ghostsAwake = false
            if let stage {
                if goalMet {
                    let s = stage.stars(shotsUsed: shotsTaken)
                    outcome = .cleared(stars: s)
                    events.append(.cleared(stars: s))
                } else if shotsLeft <= 0 {
                    outcome = .failed
                    events.append(.failed)
                }
            } else if shotsLeft <= 0 {
                outcome = .finished
                events.append(.finished)
            }
        }
    }

    private mutating func checkGoal() {
        guard let stage, !goalMet else { return }
        switch stage.goal.kind {
        case .eatAll: goalMet = balls.isEmpty
        case .eatEight: goalMet = ateEight
        case .score: goalMet = score >= stage.goal.target
        }
    }

    private mutating func appendPoint(_ p: Vec, jump: Bool = false) {
        if let last = path.last, !jump { pathLength += p.distance(to: last) }
        path.append(p)
        jumps.append(jump)
        while pathLength > targetLength, path.count > 2 {
            if !jumps[1] { pathLength -= path[1].distance(to: path[0]) }
            path.removeFirst()
            jumps.removeFirst()
            jumps[0] = false
        }
    }

    // MARK: 配置（きょうの台）

    private mutating func placeBumpers() {
        let count = 3 + Int(rng.unit() * 2)
        var tries = 0
        while bumpers.count < count, tries < 500 {
            tries += 1
            let r = 14 + rng.unit() * 8
            let c = Vec(x: 50 + rng.unit() * (rules.width - 100), y: 60 + rng.unit() * (rules.height * 0.58))
            if c.distance(to: head) < 120 { continue }
            if bumpers.contains(where: { $0.base.distance(to: c) < $0.radius + r + 60 }) { continue }
            bumpers.append(Bumper(base: c, radius: r))
        }
    }

    private mutating func spawnBall() {
        for _ in 0..<300 {
            let c = Vec(x: 26 + rng.unit() * (rules.width - 52), y: 26 + rng.unit() * (rules.height - 52))
            if bumpers.contains(where: { $0.base.distance(to: c) < $0.radius + 26 }) { continue }
            if c.distance(to: head) < 70 { continue }
            if balls.contains(where: { $0.center.distance(to: c) < 56 }) { continue }
            if path.contains(where: { $0.distance(to: c) < 24 }) { continue }
            let eight = rng.unit() < rules.eightBallChance
            let number = eight ? 8 : 1 + Int(rng.unit() * 7)
            balls.append(TableBall(center: c, number: number, born: time + idleTime, phase: rng.unit() * 6))
            return
        }
    }

    // MARK: 物理（プレビューと共通）

    struct Mover { var position: Vec; var velocity: Vec; var warpLock: Int?; var padLock: Int? = nil }
    struct Field { var bumpers: [Bumper]; var walls: [Wall]; var warps: [Warp]; var pads: [Pad] = []; var time: Double; var ice: Bool }
    enum Hit: Equatable { case rail, bumper(Int), body(Int), wall, warp, pad }
    struct StepResult {
        var hit: Hit?; var stopped: Bool; var speed: Double; var warped: (from: Vec, to: Vec)?
        var broke: Vec? = nil; var padded: Vec? = nil
    }

    static func step(_ b: inout Mover, dt: Double, rules: Rules, field: inout Field, body: [Vec], bodyLimit: Int) -> StepResult {
        let r = rules.headRadius
        b.position = b.position + b.velocity * dt
        var hit: Hit?
        var warped: (from: Vec, to: Vec)?
        var broke: Vec?
        var padded: Vec?
        if b.position.x < r { b.position.x = r; b.velocity.x = -b.velocity.x * rules.restitution; hit = .rail }
        if b.position.x > rules.width - r { b.position.x = rules.width - r; b.velocity.x = -b.velocity.x * rules.restitution; hit = .rail }
        if b.position.y < r { b.position.y = r; b.velocity.y = -b.velocity.y * rules.restitution; hit = .rail }
        if b.position.y > rules.height - r { b.position.y = rules.height - r; b.velocity.y = -b.velocity.y * rules.restitution; hit = .rail }

        for i in field.bumpers.indices {
            let p = field.bumpers[i]
            let c = p.center(at: field.time)
            let dv = b.position - c
            let d = dv.length
            if d < r + p.radius, d > 0 {
                let n = dv * (1 / d)
                let vn = b.velocity.dot(n)
                if vn < 0 {
                    b.velocity = (b.velocity - n * (2 * vn)) * rules.bumperKick
                    field.bumpers[i].squash = 1
                    hit = .bumper(i)
                }
                b.position = c + n * (r + p.radius)
            }
        }

        var broken: Int?
        for (wi, w) in field.walls.enumerated() {
            let ab = w.b - w.a
            let len2 = ab.dot(ab)
            guard len2 > 0 else { continue }
            let t = min(max((b.position - w.a).dot(ab) / len2, 0), 1)
            let closest = w.a + ab * t
            let dv = b.position - closest
            let d = dv.length
            let m = r + Wall.thickness
            if d < m, d > 0 {
                let n = dv * (1 / d)
                let vn = b.velocity.dot(n)
                if vn < 0 {
                    b.velocity = b.velocity - n * ((1 + rules.restitution) * vn)
                    hit = .wall
                    if w.breakable {
                        let left = rules.breaksInOneHit ? 0 : w.hits - 1
                        if left <= 0 { broken = wi } else { field.walls[wi].hits = left }
                    }
                }
                b.position = closest + n * m
            }
        }
        if let wi = broken {
            let w = field.walls.remove(at: wi)
            broke = (w.a + w.b) * 0.5
        }

        // かそく床：入った瞬間に、矢印の向きへ押し出す。出るまでは 1 回だけ
        if let lock = b.padLock, lock < field.pads.count, b.position.distance(to: field.pads[lock].center) > Pad.radius + r { b.padLock = nil }
        if b.padLock == nil {
            for (i, pad) in field.pads.enumerated() where b.position.distance(to: pad.center) < Pad.radius {
                let sp = max(b.velocity.length, rules.padSpeed)
                b.velocity = pad.direction * min(sp, rules.maxSpeed)
                b.padLock = i
                padded = pad.center
                if hit == nil { hit = .pad }
                break
            }
        }

        // ワープ：入った穴と反対の穴から出る。出た穴から離れるまで、もう一度は入らない
        if let lock = b.warpLock {
            let hole = lock % 2 == 0 ? field.warps[lock / 2].a : field.warps[lock / 2].b
            if b.position.distance(to: hole) > Warp.radius + r { b.warpLock = nil }
        }
        if b.warpLock == nil {
            for (i, w) in field.warps.enumerated() {
                if b.position.distance(to: w.a) < Warp.radius {
                    warped = (w.a, w.b); b.position = w.b; b.warpLock = i * 2 + 1; hit = .warp
                } else if b.position.distance(to: w.b) < Warp.radius {
                    warped = (w.b, w.a); b.position = w.a; b.warpLock = i * 2; hit = .warp
                }
                if warped != nil { b.velocity = b.velocity * rules.warpBoost; break }
            }
        }

        if bodyLimit >= 0 {
            let m = r + rules.bodyRadius - 2, m2 = m * m
            var i = min(bodyLimit, body.count - 1)
            while i >= 0 {
                let q = body[i]
                let dx = b.position.x - q.x, dy = b.position.y - q.y
                let d2 = dx * dx + dy * dy
                if d2 < m2, d2 > 0.01 {
                    let d = d2.squareRoot(), n = Vec(x: dx / d, y: dy / d)
                    let vn = b.velocity.dot(n)
                    b.position = q + n * m
                    if vn < 0 {
                        b.velocity = b.velocity - n * ((1 + rules.restitution) * vn)
                        hit = .body(i)
                    }
                    break
                }
                i -= 1
            }
        }

        var speed = b.velocity.length
        if speed > rules.maxSpeed {
            b.velocity = b.velocity * (rules.maxSpeed / speed)
            speed = rules.maxSpeed
        }
        let k = field.ice ? rules.iceFactor : 1
        let next = speed * exp(-rules.friction * k * dt) - rules.deceleration * k * dt
        if next < 6 {
            b.velocity = .zero
            return StepResult(hit: hit, stopped: true, speed: speed, warped: warped, broke: broke, padded: padded)
        }
        b.velocity = b.velocity * (next / speed)
        return StepResult(hit: hit, stopped: false, speed: speed, warped: warped, broke: broke, padded: padded)
    }
}
