import Foundation

// ゲームの中身（画面から切り離してテストする）。座標は台の内側の 360 × 560 の点。
// スネーク × ビリヤード：頭を打ち出すと、転がった跡がそのまま胴体になる。胴体はクッションとして跳ね返す。

struct Vec: Equatable, Sendable {
    var x: Double
    var y: Double
    static let zero = Vec(x: 0, y: 0)
    var length: Double { (x * x + y * y).squareRoot() }
    func distance(to o: Vec) -> Double { Vec(x: x - o.x, y: y - o.y).length }
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

    static let standard = Rules()
}

struct Bumper: Equatable, Sendable {
    var center: Vec
    var radius: Double
    var squash = 0.0
}

struct TableBall: Equatable, Sendable {
    var center: Vec
    var number: Int      // 1〜8。8 番は 30 点
    var born: Double
    var phase: Double
    var points: Int { number == 8 ? 30 : 10 }
}

enum GameEvent: Equatable, Sendable {
    case rail(speed: Double)
    case bumper(index: Int)
    case bodyBounce(at: Vec)
    case eat(number: Int, combo: Int, points: Int, at: Vec)
    case bonusShot
    case stopped(ateAny: Bool)
    case finished
}

struct ShotPreview: Equatable, Sendable {
    var points: [Vec]
    var end: Vec
    /// 止まるところまで見えているか（反射の回数の上限で切れていない）
    var reachesStop: Bool
}

struct GameEngine: Sendable {
    let rules: Rules
    private var rng: SeededRandom

    private(set) var head: Vec
    private(set) var velocity: Vec = .zero
    private(set) var direction = Vec(x: 0, y: -1)
    /// 胴体の点。先頭が尻尾、最後が頭のすぐ後ろ
    private(set) var path: [Vec] = []
    private(set) var pathLength = 0.0
    private(set) var targetLength: Double
    private(set) var shotsLeft: Int
    private(set) var shotsTaken = 0
    private(set) var score = 0
    private(set) var eaten = 0
    private(set) var combo = 0
    private(set) var bestCombo = 0
    private(set) var isMoving = false
    private(set) var isFinished = false
    private(set) var bumpers: [Bumper] = []
    private(set) var balls: [TableBall] = []
    private(set) var time = 0.0

    init(seed: UInt32, rules: Rules = .standard) {
        self.rules = rules
        self.rng = SeededRandom(seed: seed)
        head = Vec(x: rules.width / 2, y: rules.height * 0.75)
        targetLength = rules.startLength
        shotsLeft = rules.shots
        var y = head.y + rules.startLength
        while y >= head.y { appendPoint(Vec(x: head.x, y: y)); y -= rules.spacing }
        placeBumpers()
        for _ in 0..<rules.ballCount { spawnBall() }
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
        let n = Vec(x: d.x / d.length, y: d.y / d.length)
        velocity = Vec(x: n.x * p * rules.maxSpeed, y: n.y * p * rules.maxSpeed)
        direction = n
        isMoving = true
        shotsLeft -= 1
        shotsTaken += 1
        combo = 0
        return true
    }

    func preview(direction d: Vec, power: Double) -> ShotPreview {
        guard d.length > 0 else { return ShotPreview(points: [], end: head, reachesStop: true) }
        let p = min(max(power, 0), 1)
        var ball = Mover(position: head, velocity: Vec(x: d.x / d.length * p * rules.maxSpeed, y: d.y / d.length * p * rules.maxSpeed))
        var bs = bumpers
        var pts: [Vec] = []
        var bounces = 0
        let limit = neckIndex
        for i in 0..<1500 {
            let r = Self.step(&ball, dt: 1.0 / 150, rules: rules, bumpers: &bs, body: path, bodyLimit: limit)
            if i % 4 == 0 { pts.append(ball.position) }
            if r.hit != nil { bounces += 1; if bounces >= rules.previewBounces { break } }
            if r.stopped { break }
        }
        return ShotPreview(points: pts, end: ball.position, reachesStop: bounces < rules.previewBounces)
    }

    // MARK: 時間を進める

    mutating func advance(by dt: Double) -> [GameEvent] {
        guard dt > 0 else { return [] }
        time += dt
        for i in bumpers.indices { bumpers[i].squash = max(0, bumpers[i].squash - dt * 5) }
        guard isMoving else { return [] }
        var events: [GameEvent] = []
        let n = max(1, Int((dt * 240).rounded(.up)))
        for _ in 0..<n where isMoving {
            physicsStep(dt / Double(n), events: &events)
        }
        return events
    }

    private var neckIndex: Int {
        path.count - 1 - (Int(((rules.headRadius + rules.bodyRadius + 8) / rules.spacing).rounded(.up)) + 2)
    }

    private mutating func physicsStep(_ dt: Double, events: inout [GameEvent]) {
        var ball = Mover(position: head, velocity: velocity)
        let r = Self.step(&ball, dt: dt, rules: rules, bumpers: &bumpers, body: path, bodyLimit: neckIndex)
        head = ball.position
        velocity = ball.velocity
        switch r.hit {
        case .rail: events.append(.rail(speed: r.speed))
        case .bumper(let i): events.append(.bumper(index: i))
        case .body(let i): events.append(.bodyBounce(at: path[i]))
        case nil: break
        }
        let speed = velocity.length
        if speed > 1 { direction = Vec(x: velocity.x / speed, y: velocity.y / speed) }
        if let last = path.last, head.distance(to: last) >= rules.spacing { appendPoint(head) }

        for i in balls.indices.reversed() where balls[i].center.distance(to: head) < rules.eatRadius {
            let ball = balls.remove(at: i)
            combo += 1
            eaten += 1
            bestCombo = max(bestCombo, combo)
            let pts = ball.points * combo
            score += pts
            targetLength += rules.growPerBall
            events.append(.eat(number: ball.number, combo: combo, points: pts, at: ball.center))
            if combo == 2 { shotsLeft += 1; events.append(.bonusShot) }
            spawnBall()
        }

        if r.stopped {
            isMoving = false
            events.append(.stopped(ateAny: combo > 0))
            combo = 0
            if shotsLeft <= 0 { isFinished = true; events.append(.finished) }
        }
    }

    private mutating func appendPoint(_ p: Vec) {
        if let last = path.last { pathLength += p.distance(to: last) }
        path.append(p)
        while pathLength > targetLength, path.count > 2 {
            pathLength -= path[1].distance(to: path[0])
            path.removeFirst()
        }
    }

    // MARK: 配置

    private mutating func placeBumpers() {
        let count = 3 + Int(rng.unit() * 2)
        var tries = 0
        while bumpers.count < count, tries < 500 {
            tries += 1
            let r = 14 + rng.unit() * 8
            let c = Vec(x: 50 + rng.unit() * (rules.width - 100), y: 60 + rng.unit() * (rules.height * 0.58))
            if c.distance(to: head) < 120 { continue }
            if bumpers.contains(where: { $0.center.distance(to: c) < $0.radius + r + 60 }) { continue }
            bumpers.append(Bumper(center: c, radius: r))
        }
    }

    private mutating func spawnBall() {
        for _ in 0..<300 {
            let c = Vec(x: 26 + rng.unit() * (rules.width - 52), y: 26 + rng.unit() * (rules.height - 52))
            if bumpers.contains(where: { $0.center.distance(to: c) < $0.radius + 26 }) { continue }
            if c.distance(to: head) < 70 { continue }
            if balls.contains(where: { $0.center.distance(to: c) < 56 }) { continue }
            if path.contains(where: { $0.distance(to: c) < 24 }) { continue }
            let eight = rng.unit() < rules.eightBallChance
            let number = eight ? 8 : 1 + Int(rng.unit() * 7)
            balls.append(TableBall(center: c, number: number, born: time, phase: rng.unit() * 6))
            return
        }
    }

    // MARK: 物理（プレビューと共通）

    struct Mover { var position: Vec; var velocity: Vec }
    enum Hit: Equatable { case rail, bumper(Int), body(Int) }
    struct StepResult { var hit: Hit?; var stopped: Bool; var speed: Double }

    static func step(_ b: inout Mover, dt: Double, rules: Rules, bumpers: inout [Bumper], body: [Vec], bodyLimit: Int) -> StepResult {
        let r = rules.headRadius
        b.position.x += b.velocity.x * dt
        b.position.y += b.velocity.y * dt
        var hit: Hit?
        if b.position.x < r { b.position.x = r; b.velocity.x = -b.velocity.x * rules.restitution; hit = .rail }
        if b.position.x > rules.width - r { b.position.x = rules.width - r; b.velocity.x = -b.velocity.x * rules.restitution; hit = .rail }
        if b.position.y < r { b.position.y = r; b.velocity.y = -b.velocity.y * rules.restitution; hit = .rail }
        if b.position.y > rules.height - r { b.position.y = rules.height - r; b.velocity.y = -b.velocity.y * rules.restitution; hit = .rail }

        for i in bumpers.indices {
            let p = bumpers[i]
            let dx = b.position.x - p.center.x, dy = b.position.y - p.center.y
            let d = (dx * dx + dy * dy).squareRoot()
            if d < r + p.radius, d > 0 {
                let nx = dx / d, ny = dy / d
                let vn = b.velocity.x * nx + b.velocity.y * ny
                if vn < 0 {
                    b.velocity.x = (b.velocity.x - 2 * vn * nx) * rules.bumperKick
                    b.velocity.y = (b.velocity.y - 2 * vn * ny) * rules.bumperKick
                    bumpers[i].squash = 1
                    hit = .bumper(i)
                }
                b.position = Vec(x: p.center.x + nx * (r + p.radius), y: p.center.y + ny * (r + p.radius))
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
                    let d = d2.squareRoot(), nx = dx / d, ny = dy / d
                    let vn = b.velocity.x * nx + b.velocity.y * ny
                    b.position = Vec(x: q.x + nx * m, y: q.y + ny * m)
                    if vn < 0 {
                        b.velocity.x -= (1 + rules.restitution) * vn * nx
                        b.velocity.y -= (1 + rules.restitution) * vn * ny
                        hit = .body(i)
                    }
                    break
                }
                i -= 1
            }
        }

        var speed = b.velocity.length
        if speed > rules.maxSpeed {
            b.velocity = Vec(x: b.velocity.x * rules.maxSpeed / speed, y: b.velocity.y * rules.maxSpeed / speed)
            speed = rules.maxSpeed
        }
        let next = speed * exp(-rules.friction * dt) - rules.deceleration * dt
        if next < 6 {
            b.velocity = .zero
            return StepResult(hit: hit, stopped: true, speed: speed)
        }
        b.velocity = Vec(x: b.velocity.x * next / speed, y: b.velocity.y * next / speed)
        return StepResult(hit: hit, stopped: false, speed: speed)
    }
}
