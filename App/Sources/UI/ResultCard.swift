import SwiftUI

struct ResultCard: View {
    @Environment(AppModel.self) private var app
    let game: GameModel
    let summary: GameModel.Summary
    @State private var shownStars = 0
    @State private var copied = false
    @State private var doubled = false

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
            if !cleared { return String(localized: "あとちょっと…もう一回！") }
            return ["", String(localized: "クリア！"), String(localized: "いい感じ！"), String(localized: "かんぺき！")][stars]
        }
        return [String(localized: "まだおなかすいてる…"), String(localized: "けっこう食べた！"), String(localized: "おなかいっぱい！"), String(localized: "もう動けない〜！")][stars]
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
                Text(cleared ? String(localized: "\(L.s(s.id)) クリア") : String(localized: "\(L.s(s.id)) しっぱい"))
                    .font(Theme.title(30)).foregroundStyle(Theme.ink)
                if cleared {
                    Text(String(localized: "\(L.s(game.engine.shotsTaken)) 打でクリア（★3 は \(L.s(s.par3)) 打・★2 は \(L.s(s.par2)) 打まで）"))
                        .font(Theme.body(12)).foregroundStyle(Theme.inkSoft)
                } else {
                    Text(hint(for: s)).font(Theme.body(13)).foregroundStyle(Theme.ink).multilineTextAlignment(.center)
                }
            } else {
                Text("\(game.engine.score)")
                    .font(Theme.title(52)).monospacedDigit()
                    .foregroundStyle(Theme.ink)
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 3) {
                    row(String(localized: "たべた球"), "\(game.engine.eaten)")
                    row(String(localized: "いちばんの連続"), String(localized: "\(L.s(game.engine.bestCombo))れんぞく"))
                    if game.mode.isDaily { row(String(localized: "きょうのベスト"), "\(app.progress.best(on: dayKey) ?? game.engine.score)") }
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
        .accessibilityLabel(String(localized: "星 \(L.s(stars)) こ"))
    }

    @ViewBuilder private var buttons: some View {
        if let s = stage {
            HStack(spacing: 10) {
                Button(cleared ? String(localized: "もう一回") : String(localized: "やりなおす")) { app.continueFromResult { app.replay() } }
                    .buttonStyle(ChunkyButtonStyle(fill: cleared ? Theme.cream : Theme.mint, text: cleared ? Theme.ink : .white))
                if cleared, let next = app.stage(after: s) {
                    if app.isUnlocked(next) {
                        Button(String(localized: "つぎへ")) { app.continueFromResult { app.playStage(next) } }
                            .buttonStyle(ChunkyButtonStyle(fill: Theme.mint, text: .white))
                    } else {
                        Button(StageBook.world(next.world).isPack ? String(localized: "パックでつづき") : String(localized: "Pro でつづき")) { app.showPro = true }
                            .buttonStyle(ChunkyButtonStyle(fill: Theme.sun))
                    }
                }
            }
            if app.progress.canPull() {
                Button(String(localized: "カプセルを回す（おやつ \(L.s(app.progress.snacks))）")) { app.continueFromResult { app.route = .capsule } }
                    .font(Theme.label(13)).foregroundStyle(Theme.ink).underline()
            }
        } else {
            HStack(spacing: 10) {
                Button(String(localized: "もう一回")) { app.continueFromResult { app.replay() } }
                    .buttonStyle(ChunkyButtonStyle(fill: Theme.mint, text: .white))
                if app.progress.canPull() {
                    Button(String(localized: "なかまをよぶ")) { app.continueFromResult { app.route = .capsule } }
                        .buttonStyle(ChunkyButtonStyle())
                } else {
                    Button(copied ? String(localized: "コピーした") : String(localized: "結果をコピー")) { copy() }
                        .buttonStyle(ChunkyButtonStyle())
                }
            }
        }
    }

    private func hint(for s: Stage) -> String {
        if s.balls.contains(where: { $0.kind == .ghost }) && game.engine.balls.contains(where: { $0.kind == .ghost }) {
            return String(localized: "ゴースト球は、からだで跳ね返ったあとに食べられるよ。モモが仲よし")
        }
        if s.ice { return String(localized: "こおりはすべる。弱めに引いてみよう。ミントはすべりにくい") }
        if !s.warps.isEmpty { return String(localized: "穴の出口の向きをよそく線で見てみよう。ソーダは出口で加速する") }
        if s.bumpers.contains(where: { $0.amplitude > 0 }) { return String(localized: "バンパーが動いている。よそく線がとおる時に打とう") }
        if !s.pads.isEmpty { return String(localized: "かそく床の矢印の先を、よそく線で見てみよう。ユズはもっと速く飛ぶ") }
        if s.walls.contains(where: { $0.breakable }) { return String(localized: "ピンクのブロックは当てるとこわれる。イシマルはかたいブロックに強い") }
        return String(localized: "よそく線を見ながら、2 こまとめて食べるとショットが増えるよ")
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
            case .daily(let r): return (r.total, r.dailyBonus > 0 ? String(localized: "きょうの1回目 +\(L.s(r.dailyBonus))") : nil)
            case .stage(let r): return (r.snacks, r.isFirstClear ? String(localized: "はじめてのクリア") : (r.snacks > 0 ? String(localized: "星がふえた") : nil))
            }
        }()
        if total > 0 {
            HStack(spacing: 6) {
                SnackIcon(size: 18)
                Text(String(localized: "おやつ +\(L.s(doubled ? total * 2 : total))")).font(Theme.label(15)).foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                if let note { Text(doubled ? String(localized: "2 倍！") : note).font(Theme.body(11)).foregroundStyle(Theme.inkSoft) }
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Capsule().fill(Theme.sun.opacity(0.45)))
            .accessibilityElement(children: .combine)
            if !doubled, app.ads.isReady {
                Button {
                    Task {
                        if await app.watchAdForDouble(total) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { doubled = true }
                            Feedback.bonus()
                        }
                    }
                } label: {
                    Label(String(localized: "動画を見ておやつ 2 倍"), systemImage: "play.rectangle.fill")
                }
                .font(Theme.label(13)).foregroundStyle(Theme.ink)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(Theme.cream))
                .overlay(Capsule().stroke(Theme.ink, lineWidth: 2))
            }
        }
    }

    private func copy() {
        let s = stars
        let title = game.mode.isDaily ? dayKey : String(localized: "ランダム台")
        let starText = String(repeating: "★", count: s) + String(repeating: "☆", count: 3 - s)
        UIPasteboard.general.string = String(localized: "ころがれ！タマヘビ \(L.s(title))\n\(L.s(starText)) \(L.s(game.engine.score))てん（\(L.s(game.engine.eaten))こ / 最大\(L.s(game.engine.bestCombo))れんぞく）")
        copied = true
        Feedback.tap()
    }
}
