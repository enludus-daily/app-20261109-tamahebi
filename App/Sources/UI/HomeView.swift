import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Pill {
                    SnackIcon()
                    Text("\(app.progress.snacks)").font(Theme.title(18)).monospacedDigit().foregroundStyle(Theme.ink)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(localized: "おやつ \(L.s(app.progress.snacks))"))
                Spacer()
                Button { app.showPro = true } label: {
                    Pill {
                        Image(systemName: "bag.fill").foregroundStyle(Theme.ink)
                        Text(String(localized: "おみせ")).font(Theme.label(14)).foregroundStyle(Theme.ink)
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
            VStack(spacing: 12) {
                CharacterPortrait(character: app.progress.selectedCharacter, face: .idle)
                    .frame(width: 210, height: 160)
                VStack(spacing: 2) {
                    Text(String(localized: "ころがれ！"))
                        .font(Theme.title(18)).foregroundStyle(Theme.ink)
                    Text(String(localized: "タマヘビ"))
                        .font(Theme.title(44)).foregroundStyle(Color(hex: 0xFF8A7E))
                        .outlined(Theme.ink, width: 2)
                        .shadow(color: Theme.ink, radius: 0, x: 0, y: 4)
                }
                .accessibilityElement(children: .combine)
                Text(String(localized: "スネーク × ビリヤード"))
                    .font(Theme.label(12)).foregroundStyle(Theme.cream)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(Capsule().fill(Theme.ink))
                Button {
                    if let n = app.nextStage { app.playStage(n) } else { app.route = .worlds }
                } label: {
                    VStack(spacing: 0) {
                        Text(app.nextStage.map { String(localized: "ステージ \(L.s($0.id)) へ") } ?? String(localized: "ステージをえらぶ"))
                        Text("★ \(app.totalStageStars)/\(app.book.count * 3)").font(Theme.body(11))
                    }
                }
                .buttonStyle(ChunkyButtonStyle(fill: Theme.mint, text: .white, height: 62))
                HStack(spacing: 10) {
                    Button(String(localized: "きょうの台")) { app.playDaily() }
                        .buttonStyle(ChunkyButtonStyle(fill: app.progress.best(on: app.today) == nil ? Theme.sun : Theme.cream))
                    Button(String(localized: "ステージ一覧")) { app.route = .worlds }
                        .buttonStyle(ChunkyButtonStyle())
                }
                todayLine
                Button(String(localized: "あそびかたをもう一度")) { app.startTutorial() }
                    .font(Theme.label(12)).foregroundStyle(Theme.inkSoft).underline()
                HStack(spacing: 10) {
                    Button { app.route = .collection } label: {
                        Label(String(localized: "なかま \(L.s(app.ownedCount))/\(L.s(Roster.all.count))"), systemImage: "person.2.fill")
                    }
                    .buttonStyle(ChunkyButtonStyle())
                    Button { app.route = .capsule } label: {
                        Label(String(localized: "カプセル"), systemImage: "circle.circle.fill")
                    }
                    .buttonStyle(ChunkyButtonStyle(fill: app.progress.canPull() ? Theme.sun : Theme.cream))
                }
            }
            .frame(maxWidth: 340)
            .card()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .alert(String(localized: "あそびかた、クリア！"), isPresented: Binding(get: { app.showTutorialDone }, set: { app.showTutorialDone = $0 })) {
            Button(String(localized: "ステージへ")) { if let n = app.nextStage { app.playStage(n) } }
            Button(String(localized: "あとで"), role: .cancel) {}
        } message: {
            Text(String(localized: "おやつ \(L.s(AppModel.tutorialGift)) をプレゼント。カプセルでなかまを呼べるよ"))
        }
    }

    private var todayLine: some View {
        HStack(spacing: 14) {
            Label {
                Text(app.progress.best(on: app.today).map { String(localized: "きょうのベスト \(L.s($0))") } ?? String(localized: "きょうの台はまだ"))
            } icon: { Image(systemName: "flag.fill") }
            if app.progress.streak > 0 {
                Label(String(localized: "\(L.s(app.progress.streak))日れんぞく"), systemImage: "flame.fill")
            }
        }
        .font(Theme.body(13))
        .foregroundStyle(Theme.inkSoft)
        .labelStyle(.titleAndIcon)
    }
}
