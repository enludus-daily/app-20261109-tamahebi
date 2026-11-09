import Foundation
import Testing
@testable import Tamahebi

struct EngineTests {
    @Test func sameSeedGivesTheSameTable() {
        let a = GameEngine(seed: 42), b = GameEngine(seed: 42)
        #expect(a.balls == b.balls)
        #expect(a.bumpers == b.bumpers)
        #expect(GameEngine(seed: 43).balls != a.balls)
    }

    @Test func startsWithTenShotsAndFourBalls() {
        let e = GameEngine(seed: 1)
        #expect(e.shotsLeft == 10)
        #expect(e.balls.count == 4)
        #expect(e.canShoot)
        #expect(e.bumpers.count >= 3)
    }

    @Test func tooWeakAShotDoesNotCount() {
        var e = GameEngine(seed: 1)
        let shot = e.shoot(direction: Vec(x: 0, y: -1), power: 0.05)
        #expect(!shot)
        #expect(e.shotsLeft == 10)
    }

    @Test func aShotRollsAndStops() {
        var e = GameEngine(seed: 1)
        let shot = e.shoot(direction: Vec(x: 0.3, y: -1), power: 0.8)
        #expect(shot)
        #expect(e.shotsLeft == 9)
        #expect(!e.canShoot)
        var stopped = false
        for _ in 0..<2000 where !stopped {
            stopped = e.advance(by: 1.0 / 60).contains { if case .stopped = $0 { true } else { false } }
        }
        #expect(stopped)
        #expect(e.canShoot)
    }

    @Test func theHeadStaysOnTheTable() {
        var e = GameEngine(seed: 7)
        e.shoot(direction: Vec(x: 1, y: 0.2), power: 1)
        for _ in 0..<600 { _ = e.advance(by: 1.0 / 60) }
        #expect(e.head.x >= e.rules.headRadius - 0.001 && e.head.x <= e.rules.width - e.rules.headRadius + 0.001)
        #expect(e.head.y >= e.rules.headRadius - 0.001 && e.head.y <= e.rules.height - e.rules.headRadius + 0.001)
    }

    @Test func theBodyNeverGetsLongerThanItsLength() {
        var e = GameEngine(seed: 3)
        e.shoot(direction: Vec(x: -0.4, y: -1), power: 1)
        for _ in 0..<600 { _ = e.advance(by: 1.0 / 60) }
        #expect(e.pathLength <= e.targetLength + e.rules.spacing * 2)
    }

    @Test func theBodyBouncesTheHeadBack() {
        // まっすぐ下（自分の胴体のほう）に打つと、胴体で跳ね返る
        var e = GameEngine(seed: 5)
        e.shoot(direction: Vec(x: 0, y: 1), power: 0.6)
        var bounced = false
        for _ in 0..<300 {
            if e.advance(by: 1.0 / 120).contains(where: { if case .bodyBounce = $0 { true } else { false } }) { bounced = true; break }
        }
        #expect(bounced)
    }

    @Test func playingOutAllShotsFinishesTheGame() {
        var e = GameEngine(seed: 11)
        var finished = false
        var turns = 0
        while !finished, turns < 40 {
            turns += 1
            let angle = Double(turns) * 1.3
            e.shoot(direction: Vec(x: cos(angle), y: sin(angle)), power: 0.7)
            for _ in 0..<2000 {
                let ev = e.advance(by: 1.0 / 60)
                if ev.contains(.finished) { finished = true }
                if !e.isMoving { break }
            }
        }
        #expect(finished)
        #expect(e.isFinished)
        #expect(!e.canShoot)
        #expect(e.shotsTaken >= 10)
    }

    @Test func previewMatchesWhereTheShotStops() {
        var e = GameEngine(seed: 9)
        let d = Vec(x: 0.2, y: -1), power = 0.35
        let p = e.preview(direction: d, power: power)
        e.shoot(direction: d, power: power)
        for _ in 0..<3000 where e.isMoving { _ = e.advance(by: 1.0 / 150) }
        if p.reachesStop, e.eaten == 0 {
            #expect(p.end.distance(to: e.head) < 6)
        }
    }

    @Test(arguments: [(0, 0), (69, 0), (70, 1), (150, 2), (259, 2), (260, 3)])
    func stars(score: Int, expected: Int) {
        #expect(GameEngine.stars(for: score) == expected)
    }

    @Test func perksChangeTheRules() {
        #expect(Roster.character("hakka").rules.previewBounces == Rules.standard.previewBounces + 1)
        #expect(Roster.character("wataame").rules.growPerBall > Rules.standard.growPerBall)
        #expect(Roster.character("kurosuke").rules.eightBallChance > Rules.standard.eightBallChance)
        #expect(Roster.character("tama").rules == Rules.standard)
    }
}
