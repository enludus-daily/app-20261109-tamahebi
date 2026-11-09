import SwiftUI

struct ResultCard: View {
    @Environment(AppModel.self) private var app
    let game: GameModel
    let reward: Reward
    @State private var shownStars = 0
    @State private var copied = false

    private var stars: Int { GameEngine.stars(for: game.engine.score) }
    private var face: Face { [.sad, .happy, .happy, .full][stars] }
    private var line: String { ["まだおなかすいてる…", "けっこう食べた！", "おなかいっぱい！", "もう動けない〜！"][stars] }

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
            Text("\(game.engine.score)")
                .font(Theme.title(52)).monospacedDigit()
                .foregroundStyle(Theme.ink)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 3) {
                row("たべた球", "\(game.engine.eaten)こ")
                row("いちばんの連続", "\(game.engine.bestCombo)れんぞく")
                if game.mode.isDaily { row("きょうのベスト", "\(app.progress.best(on: dayKey) ?? game.engine.score)") }
            }
            .font(Theme.body(13))
            snackLine
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

    private var dayKey: String { if case .daily(let d) = game.mode { d } else { "" } }

    private func row(_ k: String, _ v: String) -> some View {
        GridRow {
            Text(k).foregroundStyle(Theme.inkSoft)
            Text(v).font(Theme.label(13)).monospacedDigit().gridColumnAlignment(.trailing).foregroundStyle(Theme.ink)
        }
    }

    private var snackLine: some View {
        HStack(spacing: 6) {
            SnackIcon(size: 18)
            Text("おやつ +\(reward.total)").font(Theme.label(15)).foregroundStyle(Theme.ink)
            if reward.dailyBonus > 0 {
                Text("きょうの1回目 +\(reward.dailyBonus)").font(Theme.body(11)).foregroundStyle(Theme.inkSoft)
            }
            if reward.multiplier > 1 {
                Text("×\(reward.multiplier, format: .number.precision(.fractionLength(0...1)))").font(Theme.body(11)).foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Capsule().fill(Theme.sun.opacity(0.45)))
        .accessibilityElement(children: .combine)
    }

    private func copy() {
        let s = stars
        let title = game.mode.isDaily ? dayKey : "ランダム台"
        UIPasteboard.general.string = "ころがれ！タマヘビ \(title)\n\(String(repeating: "★", count: s))\(String(repeating: "☆", count: 3 - s)) \(game.engine.score)てん（\(game.engine.eaten)こ / 最大\(game.engine.bestCombo)れんぞく）"
        copied = true
        Feedback.tap()
    }
}
