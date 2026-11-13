import Foundation
import Testing
@testable import Tamahebi

/// 1.1 で足した仕掛け：ねばねば床・おとし穴・じゅんばん球・よくはずむかべ
struct GimmickTests {
    private func stage(balls: [StageBall] = [StageBall(center: Vec(x: 30, y: 30), number: 1)],
                       walls: [Wall] = [], muds: [Mud] = [], holes: [Hole] = [], ordered: Bool = false) -> Stage {
        var s = Stage(id: "t", world: 1, index: 0, head: Vec(x: 180, y: 400), body: [Vec(x: 180, y: 480)],
                      balls: balls, walls: walls, goal: Goal(kind: .eatAll), shots: 3, par3: 1, par2: 2)
        s.muds = muds
        s.holes = holes
        s.ordered = ordered
        return s
    }

    @Test func mudSlowsTheHeadDown() {
        var plain = GameEngine(stage: stage())
        var muddy = GameEngine(stage: stage(muds: [Mud(center: Vec(x: 180, y: 300), radius: 60)]))
        plain.shoot(direction: Vec(x: 0, y: -1), power: 0.5)
        _ = plain.runUntilStopped()
        muddy.shoot(direction: Vec(x: 0, y: -1), power: 0.5)
        _ = muddy.runUntilStopped()
        // ねばねば床があると、手前で止まる
        #expect(muddy.head.y > plain.head.y + 40)
        #expect(muddy.head.y > 240)
    }

    @Test func bouncyWallsSendTheHeadBackFaster() {
        var e = GameEngine(stage: stage(walls: [Wall(a: Vec(x: 120, y: 300), b: Vec(x: 240, y: 300), bouncy: true)]))
        e.shoot(direction: Vec(x: 0, y: -1), power: 0.5)
        var before = 0.0, after = 0.0
        for _ in 0..<2000 where e.isMoving {
            let v = e.velocity.length
            if e.advance(by: GameEngine.tick).contains(.wall) { before = v; after = e.velocity.length; break }
        }
        #expect(after > before)
    }

    @Test func fallingIntoAHoleTakesYouBackButKeepsWhatYouAte() {
        let s = stage(balls: [StageBall(center: Vec(x: 180, y: 330), number: 1), StageBall(center: Vec(x: 30, y: 30), number: 2)],
                      holes: [Hole(center: Vec(x: 180, y: 200))])
        var e = GameEngine(stage: s)
        let pathBefore = e.path
        e.shoot(direction: Vec(x: 0, y: -1), power: 0.8)
        let events = e.runUntilStopped()
        #expect(events.contains { if case .fell = $0 { true } else { false } })
        #expect(e.head == Vec(x: 180, y: 400))   // 打つ前の場所
        #expect(e.path == pathBefore)
        #expect(e.eaten == 1)                     // 途中で食べた球はそのまま
        #expect(e.shotsLeft == 2)                 // ショットは使う
        #expect(e.canShoot)
    }

    @Test func thePreviewStopsAtAHole() {
        let e = GameEngine(stage: stage(holes: [Hole(center: Vec(x: 180, y: 200))]))
        let p = e.preview(direction: Vec(x: 0, y: -1), power: 0.8)
        #expect(p.end.distance(to: Vec(x: 180, y: 200)) < 1)
    }

    @Test func orderedBallsMustBeEatenSmallestFirst() {
        // 2 番が手前、1 番が奥。まっすぐ打つと 2 番は通りぬけ、1 番だけ食べる
        let s = stage(balls: [StageBall(center: Vec(x: 180, y: 330), number: 2), StageBall(center: Vec(x: 180, y: 220), number: 1)],
                      ordered: true)
        var e = GameEngine(stage: s)
        #expect(e.nextNumber == 1)
        e.shoot(direction: Vec(x: 0, y: -1), power: 0.5)
        _ = e.runUntilStopped()
        #expect(e.balls.map(\.number) == [2])
        #expect(e.nextNumber == 2)
    }

    @Test func withoutOrderAnyBallCanBeEaten() {
        let s = stage(balls: [StageBall(center: Vec(x: 180, y: 330), number: 2), StageBall(center: Vec(x: 180, y: 220), number: 1)])
        var e = GameEngine(stage: s)
        #expect(e.nextNumber == nil)
        e.shoot(direction: Vec(x: 0, y: -1), power: 0.5)
        _ = e.runUntilStopped()
        #expect(e.balls.isEmpty)
    }
}

/// エリア（12 ステージずつ）の決まりが stages.json で守られているか
struct AreaTests {
    @Test func everyWorldIsSplitIntoAreasOfTwelve() throws {
        let book = try StageTests.book()
        for w in 1...8 {
            let areas = AreaBook.areas(world: w)
            #expect(areas.count * Area.size == book.filter { $0.world == w }.count, "ワールド \(w)")
            #expect(areas.map(\.number) == Array(1...areas.count))
        }
    }

    @Test func eachStageHasTheGimmicksOfItsArea() throws {
        var missing: [String] = []
        for s in try StageTests.book() {
            let area = try #require(AreaBook.area(world: s.world, index: s.index))
            for g in area.gimmicks(atIndex: s.index) {
                let ok: Bool = switch g {
                case .bumper: s.bumpers.contains { $0.amplitude == 0 }
                case .wall: s.walls.contains { !$0.bouncy && !$0.breakable }
                case .eight: s.goal.kind == .eatEight
                case .mud: !s.muds.isEmpty
                case .bouncy: s.walls.contains { $0.bouncy }
                case .hole: !s.holes.isEmpty
                case .ordered: s.ordered
                case .ghost: s.balls.contains { $0.kind == .ghost }
                case .ice: s.ice
                case .warp: !s.warps.isEmpty
                case .moving: s.bumpers.contains { $0.amplitude > 0 }
                case .pad: !s.pads.isEmpty
                case .block: s.walls.contains { $0.breakable }
                }
                if !ok { missing.append("\(s.id) \(g.rawValue)") }
            }
        }
        #expect(missing.isEmpty, "\(missing)")
    }

    @Test func freePlayersMeetSomethingNewOften() throws {
        // 無料のワールドでは、どのエリアも前のエリアと仕掛けの組み合わせが違う。新しい仕掛けは 8 つ以上
        let free = AreaBook.all.filter { $0.world <= 3 }
        #expect(free.count == 30)
        for (a, b) in zip(free, free.dropFirst()) where a.world == b.world {
            #expect(a.gimmicks != b.gimmicks || a.trial != b.trial, "\(b.world)-\(b.number)")
        }
        #expect(Set(free.compactMap(\.new)).count >= 8)
        // お金で開くワールドの仕掛けを、無料で少しだけためせる
        #expect(Set(free.compactMap(\.trial)) == [.warp, .moving, .pad, .block])
    }

    @Test func paidGimmicksOnlyAppearAsTrialsInFreeWorlds() throws {
        for s in try StageTests.book() where s.world <= 3 {
            let area = try #require(AreaBook.area(world: s.world, index: s.index))
            let paid = !s.warps.isEmpty || s.bumpers.contains { $0.amplitude > 0 } || !s.pads.isEmpty || s.walls.contains { $0.breakable }
            #expect(paid == area.isTrial(index: s.index), "\(s.id)")
        }
    }

    @Test func newGimmicksAreExplainedWhereTheyStart() throws {
        let book = try StageTests.book()
        for area in AreaBook.all {
            guard let g = area.new ?? area.trial else { continue }
            let first = area.new != nil ? area.firstIndex : area.firstIndex + Area.trialFrom
            let s = try #require(book.first { $0.world == area.world && $0.index == first })
            #expect(s.hint == g.introHint || s.id == "1-1", "\(s.id)")
        }
    }

    @Test func orderedStagesNumberTheirBallsFromOne() throws {
        for s in try StageTests.book() where s.ordered {
            #expect(s.balls.map(\.number).sorted() == Array(1...s.balls.count), "\(s.id)")
        }
    }
}
