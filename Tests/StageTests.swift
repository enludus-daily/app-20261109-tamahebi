import Foundation
import Testing
@testable import Tamahebi

struct StageTests {
    static func book() throws -> [Stage] {
        let url = try #require(Bundle.main.url(forResource: "stages", withExtension: "json") ?? StageTests.fallbackURL)
        return try StageBook.decode(Data(contentsOf: url))
    }
    /// アプリの外（Linux のパッケージ）で動かすとき
    static var fallbackURL: URL? {
        ProcessInfo.processInfo.environment["STAGES_JSON"].map { URL(fileURLWithPath: $0) }
    }

    @Test func thereAreEightWorldsOfTwelve() throws {
        let book = try Self.book()
        #expect(book.count == 96)
        for w in 1...8 { #expect(book.filter { $0.world == w }.count == 12) }
        #expect(Set(book.map(\.id)).count == 96)
    }

    @Test func everyStageHasRoomAndPar() throws {
        for s in try Self.book() {
            #expect(s.par3 >= 1 && s.par3 < s.par2 && s.par2 <= s.shots, "\(s.id)")
            #expect(!s.balls.isEmpty, "\(s.id)")
            #expect(s.solution.count == s.par3, "\(s.id)")
        }
    }

    @Test func eachWorldShowsItsGimmick() throws {
        let book = try Self.book()
        #expect(book.filter { $0.world == 2 }.allSatisfy { $0.balls.contains { $0.kind == .ghost } })
        #expect(book.filter { $0.world == 3 }.allSatisfy { $0.ice && !$0.walls.isEmpty })
        #expect(book.filter { $0.world == 4 }.allSatisfy { !$0.warps.isEmpty })
        #expect(book.filter { $0.world == 5 }.allSatisfy { $0.bumpers.contains { $0.amplitude > 0 } })
        #expect(book.filter { $0.world == 7 }.allSatisfy { !$0.pads.isEmpty })
        #expect(book.filter { $0.world == 8 }.allSatisfy { $0.walls.contains { $0.breakable } })
    }

    /// 生成のときに見つけた打ち方を再生すると、どのステージも解ける
    @Test func storedSolutionsClearEveryStage() throws {
        var failed: [String] = []
        for s in try Self.book() {
            var e = GameEngine(stage: s)
            for shot in s.solution where !e.isFinished {
                e.shoot(shot)
                _ = e.runUntilStopped()
            }
            if case .cleared(let stars) = e.outcome, stars == 3 { continue }
            failed.append(s.id)
        }
        #expect(failed.isEmpty, "解けなかった: \(failed)")
    }

    @Test func ghostsNeedABodyBounce() {
        // 頭のすぐ上にゴースト球。まっすぐ当てても食べられない
        let s = Stage(id: "t", world: 2, index: 0, head: Vec(x: 180, y: 400), body: [Vec(x: 180, y: 500)],
                      balls: [StageBall(center: Vec(x: 180, y: 300), number: 1, kind: .ghost)],
                      goal: Goal(kind: .eatAll), shots: 3, par3: 1, par2: 2)
        var e = GameEngine(stage: s)
        e.shoot(direction: Vec(x: 0, y: -1), power: 0.3)
        _ = e.runUntilStopped()
        #expect(e.eaten == 0)
    }

    @Test func warpsMoveTheHead() {
        let s = Stage(id: "t", world: 4, index: 0, head: Vec(x: 180, y: 400), body: [Vec(x: 180, y: 480)],
                      balls: [StageBall(center: Vec(x: 60, y: 60), number: 1)],
                      warps: [Warp(a: Vec(x: 180, y: 300), b: Vec(x: 300, y: 100))],
                      goal: Goal(kind: .eatAll), shots: 3, par3: 1, par2: 2)
        var e = GameEngine(stage: s)
        e.shoot(direction: Vec(x: 0, y: -1), power: 0.4)
        let events = e.runUntilStopped()
        #expect(events.contains { if case .warp = $0 { true } else { false } })
        #expect(e.head.x > 240)  // 出口（x 300）の側にいる
    }

    @Test func failingUsesUpTheShots() {
        let s = Stage(id: "t", world: 1, index: 0, head: Vec(x: 180, y: 400), body: [Vec(x: 180, y: 480)],
                      balls: [StageBall(center: Vec(x: 30, y: 30), number: 1)],
                      goal: Goal(kind: .eatAll), shots: 1, par3: 1, par2: 1)
        var e = GameEngine(stage: s)
        e.shoot(direction: Vec(x: 1, y: 0), power: 0.2)
        _ = e.runUntilStopped()
        #expect(e.outcome == .failed)
    }

    @Test func unlockingFollowsTheOrder() throws {
        let book = try Self.book()
        var p = Progress()
        #expect(p.isUnlocked(book[0], in: book, isPro: false))
        #expect(!p.isUnlocked(book[1], in: book, isPro: false))
        p.stageStars[book[0].id] = 1
        #expect(p.isUnlocked(book[1], in: book, isPro: false))
        let firstPro = try #require(book.first { $0.world == 4 })
        for s in book where s.world < 4 { p.stageStars[s.id] = 1 }
        #expect(!p.isUnlocked(firstPro, in: book, isPro: false))
        #expect(p.isUnlocked(firstPro, in: book, isPro: true))
        // ワールドパックは Pro がなくても、ワールド 3 のあとから
        let firstPack = try #require(book.first { $0.id == "7-1" })
        #expect(!p.isUnlocked(firstPack, in: book, isPro: false))
        #expect(p.isUnlocked(firstPack, in: book, isPro: false, worldPack: true))
        let eight = try #require(book.first { $0.id == "8-1" })
        #expect(!p.isUnlocked(eight, in: book, isPro: false, worldPack: true))
    }

    @Test func padsLaunchTheHead() {
        let s = Stage(id: "t", world: 7, index: 0, head: Vec(x: 180, y: 400), body: [Vec(x: 180, y: 480)],
                      balls: [StageBall(center: Vec(x: 40, y: 40), number: 1)],
                      pads: [Pad(center: Vec(x: 180, y: 330), angle: 0)],
                      goal: Goal(kind: .eatAll), shots: 3, par3: 1, par2: 2)
        var e = GameEngine(stage: s)
        e.shoot(direction: Vec(x: 0, y: -1), power: 0.3)
        let events = e.runUntilStopped()
        #expect(events.contains { if case .pad = $0 { true } else { false } })
        #expect(e.head.x > 300)  // 右へ押し出された
    }

    @Test func blocksBreak() {
        let s = Stage(id: "t", world: 8, index: 0, head: Vec(x: 180, y: 400), body: [Vec(x: 180, y: 480)],
                      balls: [StageBall(center: Vec(x: 180, y: 200), number: 1)],
                      walls: [Wall(a: Vec(x: 140, y: 300), b: Vec(x: 220, y: 300), hits: 1)],
                      goal: Goal(kind: .eatAll), shots: 3, par3: 1, par2: 2)
        var e = GameEngine(stage: s)
        e.shoot(direction: Vec(x: 0, y: -1), power: 0.5)
        let events = e.runUntilStopped()
        #expect(events.contains { if case .wallBreak = $0 { true } else { false } })
        #expect(e.walls.isEmpty)
    }

    @Test func hardBlocksNeedTwoHitsUnlessBreaker() {
        let s = Stage(id: "t", world: 8, index: 0, head: Vec(x: 180, y: 400), body: [Vec(x: 180, y: 480)],
                      balls: [StageBall(center: Vec(x: 40, y: 40), number: 1)],
                      walls: [Wall(a: Vec(x: 140, y: 300), b: Vec(x: 220, y: 300), hits: 2)],
                      goal: Goal(kind: .eatAll), shots: 3, par3: 1, par2: 2)
        var normal = GameEngine(stage: s)
        normal.shoot(direction: Vec(x: 0, y: -1), power: 0.3)
        // 1 回目に当たったところで止めて見る（跳ね返って、からだでもう一度当たることがあるため）
        for _ in 0..<2000 where normal.isMoving {
            if normal.advance(by: GameEngine.tick).contains(.wall) { break }
        }
        #expect(normal.walls.first?.hits == 1)
        var strong = GameEngine(stage: s, rules: Roster.character("ishimaru").rules(level: 3))
        strong.shoot(direction: Vec(x: 0, y: -1), power: 0.3)
        _ = strong.runUntilStopped()
        #expect(strong.walls.isEmpty)
    }

    @Test func bumpersKeepMovingUnlessHinting() throws {
        let book = try Self.book()
        let s = try #require(book.first { $0.world == 5 })
        var normal = GameEngine(stage: s)
        _ = normal.advance(by: 1.5)
        #expect(normal.time > 1)
        var r = Rules.standard
        r.bumpersWaitWhileResting = true
        var hint = GameEngine(stage: s, rules: r)
        _ = hint.advance(by: 1.5)
        #expect(hint.time == 0)
    }
}
