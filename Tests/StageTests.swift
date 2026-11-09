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

    @Test func thereAreSixWorldsOfTwelve() throws {
        let book = try Self.book()
        #expect(book.count == 72)
        for w in 1...6 { #expect(book.filter { $0.world == w }.count == 12) }
        #expect(Set(book.map(\.id)).count == 72)
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
    }
}
