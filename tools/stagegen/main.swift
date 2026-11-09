import Foundation

// ステージを作り、解けることを確かめて App/Resources/stages.json に書く。
// 使い方（Swift 6 の入った Linux / Mac）: tools/stagegen/run.sh
// 1. ワールドごとの決まり（仕掛け・球の数）で配置を乱数で作る
// 2. 同じ物理で、打ち方を総当たりのビームサーチで探す（向き 48 × 強さ 6）
// 3. 解けたものだけ残す。各ショットは、向き ±1° と強さ ±3% にずらしても同じ数を食べること（人が打てる余裕）
// 4. 見つかったショット数を星 3 の基準にする

struct Gen {
    var rng: SeededRandom
    let rules = Rules.standard

    mutating func r(_ a: Double, _ b: Double) -> Double { a + rng.unit() * (b - a) }
    mutating func i(_ a: Int, _ b: Int) -> Int { a + Int(rng.unit() * Double(b - a + 1)) }
    mutating func chance(_ p: Double) -> Bool { rng.unit() < p }

    mutating func candidate(world w: Int, index k: Int) -> Stage {
        let d = Double(k) / 11
        var s = Stage(id: "\(w)-\(k + 1)", world: w, index: k, head: .zero, body: [], balls: [], goal: Goal(kind: .eatAll), shots: 0, par3: 0, par2: 0)
        // 頭とからだ
        s.head = Vec(x: r(70, 290), y: r(300, 500))
        let bodyLen = w == 2 ? r(150, 230) : r(80, 140)
        let a0 = r(0, 2 * .pi)
        let bend = (w == 2 || chance(0.4)) ? r(-1.6, 1.6) : 0
        var pts = [s.head]
        var dir = a0
        var left = bodyLen
        let segs = bend == 0 ? 1 : 2
        for _ in 0..<segs {
            let len = left / Double(segs == 2 && pts.count == 1 ? 2 : 1)
            let p = pts.last! + Vec.angle(dir) * len
            pts.append(Vec(x: min(max(p.x, 16), rules.width - 16), y: min(max(p.y, 16), rules.height - 16)))
            left -= len
            dir += bend
        }
        s.body = Array(pts.dropFirst().reversed())

        // 仕掛け
        var nBump = 0, nWall = 0, nWarp = 0, nMoving = 0, nGhost = 0
        var nBall = 2
        switch w {
        case 1: nBump = Int((d * 3).rounded()); nBall = 1 + Int((d * 4).rounded())
        case 2: nBump = i(0, 1 + Int(d * 2)); nBall = 2 + Int((d * 3).rounded()); nGhost = 1 + Int((d * 2).rounded())
        case 3: s.ice = true; nWall = 1 + Int((d * 2).rounded()); nBump = i(0, Int(d * 2)); nBall = 2 + Int((d * 3).rounded())
        case 4: nWarp = k < 6 ? 1 : i(1, 2); nBump = i(0, 2); nWall = i(0, 1); nBall = 2 + Int((d * 3).rounded()); nGhost = k > 7 ? 1 : 0
        case 5: nMoving = 2 + Int((d * 2).rounded()); nBall = 2 + Int((d * 3).rounded()); nWall = k > 6 ? 1 : 0
        default:
            s.ice = chance(0.4); nWarp = i(0, 1); nMoving = i(0, 2); nBump = i(0, 1); nWall = i(0, 2)
            nGhost = i(0, 2); nBall = 3 + Int((d * 3).rounded())
        }
        func clear(_ p: Vec, _ m: Double, _ s: Stage) -> Bool {
            if p.distance(to: s.head) < m + 40 { return false }
            if (s.body).contains(where: { $0.distance(to: p) < m + 20 }) { return false }
            if s.bumpers.contains(where: { $0.center.distance(to: p) < $0.radius + m + $0.amplitude + 14 }) { return false }
            if s.balls.contains(where: { $0.center.distance(to: p) < m + 34 }) { return false }
            if s.warps.contains(where: { $0.a.distance(to: p) < m + 30 || $0.b.distance(to: p) < m + 30 }) { return false }
            for wall in s.walls {
                let ab = wall.b - wall.a
                let t = min(max((p - wall.a).dot(ab) / ab.dot(ab), 0), 1)
                if (wall.a + ab * t).distance(to: p) < m + 18 { return false }
            }
            return true
        }
        func spot(_ m: Double, _ s: Stage) -> Vec? {
            for _ in 0..<200 {
                let p = Vec(x: r(m + 14, rules.width - m - 14), y: r(m + 14, rules.height - m - 14))
                if clear(p, m, s) { return p }
            }
            return nil
        }
        for _ in 0..<nWall {
            for _ in 0..<50 {
                let c = Vec(x: r(60, 300), y: r(60, 480))
                let len = r(60, 140), ang = r(0, .pi)
                let wall = Wall(a: c - Vec.angle(ang) * (len / 2), b: c + Vec.angle(ang) * (len / 2))
                if [wall.a, wall.b, c].allSatisfy({ clear($0, 16, s) }) { s.walls.append(wall); break }
            }
        }
        for _ in 0..<nWarp {
            for _ in 0..<30 {
                guard let a = spot(Warp.radius, s) else { continue }
                var t = s; t.warps.append(Warp(a: a, b: a))
                if let b = spot(Warp.radius, t), b.distance(to: a) > 180 { s.warps.append(Warp(a: a, b: b)); break }
            }
        }
        for _ in 0..<nBump {
            let rad = r(14, 22)
            if let p = spot(rad, s) { s.bumpers.append(StageBumper(center: p, radius: rad)) }
        }
        for _ in 0..<nMoving {
            let rad = r(14, 20), amp = r(30, 70)
            if let p = spot(rad + amp, s) {
                s.bumpers.append(StageBumper(center: p, radius: rad, axis: Vec.angle(r(0, .pi)), amplitude: amp, speed: r(1.2, 2.6), phase: r(0, 6)))
            }
        }
        let eightGoal = (w == 1 && (k == 6 || k == 10)) || (w == 6 && (k == 3 || k == 7))
        for n in 0..<nBall {
            if let p = spot(10, s) {
                let ghost = n < nGhost
                s.balls.append(StageBall(center: p, number: ghost ? 1 + (n % 7) : 1 + ((n + k) % 7), kind: ghost ? .ghost : .normal))
            }
        }
        if eightGoal, let p = spot(10, s) {
            s.balls.append(StageBall(center: p, number: 8))
            s.goal = Goal(kind: .eatEight)
        }
        return s
    }
}

struct Solver {
    let rules = Rules.standard
    static let angles = (0..<48).map { Double($0) * 2 * .pi / 48 }
    static let powers = [0.3, 0.45, 0.6, 0.75, 0.9, 1.0]

    func progress(_ e: GameEngine) -> Double {
        var p = Double(e.eaten) * 1000
        if e.ateEight { p += 5000 }
        if case .cleared = e.outcome { p += 100_000 }
        // 次に近い球までの近さ
        let targets = e.balls.filter { e.stage?.goal.kind != .eatEight || $0.number == 8 }
        if let near = targets.map({ $0.center.distance(to: e.head) }).min() { p -= near }
        return p
    }

    func play(_ e: GameEngine, _ s: Shot) -> GameEngine {
        var x = e
        x.shoot(s)
        _ = x.runUntilStopped()
        return x
    }

    func robust(_ e: GameEngine, _ s: Shot, nominal: GameEngine) -> Bool {
        for (da, k) in [(1.0, 1.0), (-1.0, 1.0), (0.0, 0.97), (0.0, 1.03)] {
            let t = play(e, Shot(angle: s.angle + da * .pi / 180, power: min(1, s.power * k)))
            if t.eaten < nominal.eaten { return false }
            if case .cleared = nominal.outcome, t.outcome != nominal.outcome, !(isCleared(t)) { return false }
        }
        return true
    }
    func isCleared(_ e: GameEngine) -> Bool { if case .cleared = e.outcome { true } else { false } }

    func solve(_ stage: Stage, maxDepth: Int, beam width: Int = 12) -> [Shot]? {
        var beam: [(GameEngine, [Shot])] = [(GameEngine(stage: stage, rules: rules), [])]
        for _ in 0..<maxDepth {
            var next: [(GameEngine, [Shot], Double)] = []
            for (e, shots) in beam {
                for a in Self.angles {
                    for p in Self.powers {
                        let s = Shot(angle: a, power: p)
                        let t = play(e, s)
                        if t.eaten > e.eaten || isCleared(t) {
                            guard robust(e, s, nominal: t) else { continue }
                        }
                        if isCleared(t) { return shots + [s] }
                        next.append((t, shots + [s], progress(t)))
                    }
                }
            }
            next.sort { $0.2 > $1.2 }
            var chosen: [(GameEngine, [Shot])] = []
            for c in next {
                if chosen.contains(where: { $0.0.head.distance(to: c.0.head) < 25 && $0.0.eaten == c.0.eaten }) { continue }
                chosen.append((c.0, c.1))
                if chosen.count >= width { break }
            }
            beam = chosen
            if beam.isEmpty { return nil }
        }
        return nil
    }
}

let hints: [String: String] = [
    "1-1": "台のどこでもひっぱって、はなすと転がる。球を食べよう",
    "1-3": "黄色いバンパーに当たると、よくはずむ",
    "1-7": "8 番球を食べればクリア。ほかの球は食べなくてもいい",
    "2-1": "すけている球はゴースト球。からだで跳ね返ったあとだけ食べられる",
    "3-1": "こおりの台はよくすべる。弱めに打とう。かべでも跳ね返る",
    "4-1": "穴に入ると、もう片方の穴から同じ向きで出てくる",
    "5-1": "バンパーが動いている。よそく線は、いま打ったときの線",
    "6-1": "ぜんぶの仕掛けが出てくる。なかまのとくいも使おう",
]

let solver = Solver()
var out: [Stage] = []
let onlyWorld = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1]) : nil
for w in 1...6 {
    if let o = onlyWorld, o != w { continue }
    for k in 0..<12 {
        var tries = 0
        var done = false
        while !done && tries < 60 {
            tries += 1
            var g = Gen(rng: SeededRandom(seed: SeededRandom.seed(from: "tamahebi-stage-\(w)-\(k)-\(tries)")))
            var s = g.candidate(world: w, index: k)
            guard !s.balls.isEmpty else { continue }
            // ワールドの仕掛けが入っていない台は作り直す
            if w == 2 && !s.balls.contains(where: { $0.kind == .ghost }) { continue }
            if w == 3 && s.walls.isEmpty { continue }
            if w == 4 && s.warps.isEmpty { continue }
            if w == 5 && s.bumpers.filter({ $0.amplitude > 0 }).count < 2 { continue }
            let target = s.goal.kind == .eatEight ? 1 : s.balls.count
            let maxDepth = min(7, target + 2)
            s.shots = maxDepth
            s.par3 = maxDepth; s.par2 = maxDepth
            let t0 = Date()
            guard let sol = solver.solve(s, maxDepth: maxDepth) else { continue }
            // 最初のころはやさしく、あとは解き方を考えさせる（1 ショット 1 球より少ない手で解ける台を優先しない）
            // 人は 1 ショット 1 球くらいで進むので、ショットは「球の数 + ゆとり」と「見つけた手 + 2」の多いほう
            let slack = w <= 3 ? 1 : 0
            s.solution = sol
            s.par3 = sol.count
            s.shots = max(sol.count + 2, target + slack)
            s.par2 = max(sol.count + 1, (sol.count + s.shots + 1) / 2)
            s.hint = hints[s.id]
            out.append(s)
            done = true
            FileHandle.standardError.write("\(s.id) balls=\(s.balls.count) solved=\(sol.count) tries=\(tries) \(String(format: "%.1f", Date().timeIntervalSince(t0)))s\n".data(using: .utf8)!)
        }
        if !done { FileHandle.standardError.write("\(w)-\(k + 1) FAILED\n".data(using: .utf8)!) }
    }
}
let enc = JSONEncoder()
enc.outputFormatting = [.sortedKeys]
FileHandle.standardOutput.write(try enc.encode(out))
