import SwiftUI

struct ResultCard: View {
    @Environment(AppModel.self) private var app
    let game: GameModel
    let summary: GameModel.Summary
    @State private var shownStars = 0
    @State private var copied = false

    private var stage: Stage? { game.mode.stage }
    private var cleared: Bool { if case .cleared = game.engine.outcome { true } else { false } }

    private var stars: Int {
        switch game.engine.outcome {
        case .cleared(let n): n
        case .failed: 0
        default: GameEngine.stars(for: game.engine.score)
        }
    }
    private var face: Face {
        if stage != nil { return cleared ? (stars == 3 ? .full : .happy) : .sad }
        return [.sad, .happy, .happy, .full][stars]
    }
    private var line: String {
        if stage != nil {
            if !cleared { return "あとちょっと…もう一回！" }
            return ["", "クリア！", "いい感じ！", "かんぺき！"][stars]
        }
        return ["まだおなかすいてる…", "けっこう食べた！", "おなかいっぱい！", "もう動けない〜！"][stars]
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(line)
                .font(Theme.label(14))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 14).fill(.white))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.ink, lineWidth: Theme.line))
            CharacterPortrait(character: game.character, face: face)
                .frame(width: 150, height: 110)
            starRow
            if let s = stage {
                Text(cleared ? "\(s.id) クリア" : "\(s.id) しっぱい")
                    .font(Theme.title(30)).foregroundStyle(Theme.ink)
                if cleared {
                    Text("\(game.engine.shotsTaken) 打でクリア（★3 は \(s.par3) 打・★2 は \(s.par2) 打まで）")
                        .font(Theme.body(12)).foregroundStyle(Theme.inkSoft)
                } else {
                    Text(hint(for: s)).font(Theme.body(13)).foregroundStyle(Theme.ink).multilineTextAlignment(.center)
                }
            } else {
                Text("\(game.engine.score)")
                    .font(Theme.title(52)).monospacedDigit()
                    .foregroundStyle(Theme.ink)
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 3) {
                    row("たべた球", "\(game.engine.eaten)こ")
                    row("いちばんの連続", "\(game.engine.bestCombo)れんぞく")
                    if game.mode.isDaily { row("きょうのベスト", "\(app.progress.best(on: dayKey) ?? game.engine.score)") }
                }
                .font(Theme.body(13))
            }
            snackLine
            buttons
        }
        .frame(maxWidth: 320)
        .card()
        .task {
            for i in 0..<stars {
                try? await Task.sleep(for: .milliseconds(250 + i * 180))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { shownStars = i + 1 }
                Feedback.tap()
            }
        }
    }

    private var starRow: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: "star.fill")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(i < shownStars ? Theme.sun : Theme.disabled)
                    .overlay(Image(systemName: "star").font(.system(size: 30, weight: .black)).foregroundStyle(Theme.ink))
                    .scaleEffect(i < shownStars ? 1 : 0.85)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("星 \(stars) こ")
    }

    @ViewBuilder private var buttons: some View {
        if let s = stage {
            HStack(spacing: 10) {
                Button(cleared ? "もう一回" : "やりなおす") { app.replay() }
                    .buttonStyle(ChunkyButtonStyle(fill: cleared ? Theme.cream : Theme.mint, text: cleared ? Theme.ink : .white))
                if cleared, let next = app.stage(after: s) {
                    if app.isUnlocked(next) {
                        Button("つぎへ") { app.playStage(next) }
                            .buttonStyle(ChunkyButtonStyle(fill: Theme.mint, text: .white))
                    } else {
                        Button("Pro でつづき") { app.showPro = true }
                            .buttonStyle(ChunkyButtonStyle(fill: Theme.sun))
                    }
                }
            }
            if app.progress.canPull() {
                Button("カプセルを回す（おやつ \(app.progress.snacks)）") { app.route = .capsule }
                    .font(Theme.label(13)).foregroundStyle(Theme.ink).underline()
            }
        } else {
            HStack(spacing: 10) {
                Button("もう一回") { app.replay() }
                    .buttonStyle(ChunkyButtonStyle(fill: Theme.mint, text: .white))
                if app.progress.canPull() {
                    Button("なかまをよぶ") { app.route = .capsule }
                        .buttonStyle(ChunkyButtonStyle())
                } else {
                    Button(copied ? "コピーした" : "結果をコピー") { copy() }
                        .buttonStyle(ChunkyButtonStyle())
                }
            }
        }
    }

    private func hint(for s: Stage) -> String {
        if s.balls.contains(where: { $0.kind == .ghost }) && game.engine.balls.contains(where: { $0.kind == .ghost }) {
            return "ゴースト球は、からだで跳ね返ったあとに食べられるよ。モモが仲よし"
        }
        if s.ice { return "こおりはすべる。弱めに引いてみよう。ミントはすべりにくい" }
        if !s.warps.isEmpty { return "穴の出口の向きをよそく線で見てみよう。ソーダは出口で加速する" }
        if s.bumpers.contains(where: { $0.amplitude > 0 }) { return "バンパーが動いている。よそく線がとおる時に打とう" }
        return "よそく線を見ながら、2 こまとめて食べるとショットが増えるよ"
    }

    private var dayKey: String { if case .daily(let d) = game.mode { d } else { "" } }

    private func row(_ k: String, _ v: String) -> some View {
        GridRow {
            Text(k).foregroundStyle(Theme.inkSoft)
            Text(v).font(Theme.label(13)).monospacedDigit().gridColumnAlignment(.trailing).foregroundStyle(Theme.ink)
        }
    }

    @ViewBuilder private var snackLine: some View {
        let (total, note): (Int, String?) = {
            switch summary {
            case .daily(let r): return (r.total, r.dailyBonus > 0 ? "きょうの1回目 +\(r.dailyBonus)" : nil)
            case .stage(let r): return (r.snacks, r.isFirstClear ? "はじめてのクリア" : (r.snacks > 0 ? "星がふえた" : nil))
            }
        }()
        if total > 0 {
            HStack(spacing: 6) {
                SnackIcon(size: 18)
                Text("おやつ +\(total)").font(Theme.label(15)).foregroundStyle(Theme.ink)
                if let note { Text(note).font(Theme.body(11)).foregroundStyle(Theme.inkSoft) }
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Capsule().fill(Theme.sun.opacity(0.45)))
            .accessibilityElement(children: .combine)
        }
    }

    private func copy() {
        let s = stars
        let title = game.mode.isDaily ? dayKey : "ランダム台"
        UIPasteboard.general.string = "ころがれ！タマヘビ \(title)\n\(String(repeating: "★", count: s))\(String(repeating: "☆", count: 3 - s)) \(game.engine.score)てん（\(game.engine.eaten)こ / 最大\(game.engine.bestCombo)れんぞく）"
        copied = true
        Feedback.tap()
    }
}
