import StoreKit
import SwiftUI

/// Pro（買い切り）。限定のなかま 3 匹・おやつ 2 倍・台のいろ 3 種
struct ProView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 15, weight: .black)).foregroundStyle(Theme.ink)
                            .frame(width: 36, height: 36).background(Circle().fill(Theme.paper))
                            .overlay(Circle().stroke(Theme.ink, lineWidth: 2))
                    }
                    .accessibilityLabel("とじる")
                }
                Text("タマヘビ Pro").font(Theme.title(32)).foregroundStyle(Theme.ink)
                Text(app.isPro ? "ありがとう！ぜんぶ使えます" : "1 回買えば、ずっと使えます")
                    .font(Theme.body(14)).foregroundStyle(Theme.inkSoft)
                HStack(spacing: -16) {
                    ForEach(Roster.proOnly) { c in
                        CharacterPortrait(character: c, face: .happy, showBody: false).frame(width: 110, height: 90)
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    benefit("map.fill", "ワールド 4〜6（36 ステージ）", "ワープの台・うごくバンパー・よるのごちゃまぜ。ぜんぶ解けることを確かめた手づくりの台")
                    benefit("person.3.fill", "限定のなかま 3 匹（なかよし Lv3 から）", "ギンガ・サクラ・ホムラ。とくいがはじめから強い")
                    benefit("bag.fill", "おやつがずっと 2 倍", "カプセルを倍回せる。なかよし度が早く上がる")
                    benefit("square.grid.2x2.fill", "台のいろ 3 種", "きょうの台を、みどり・すもも・よるに")
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 20).fill(Theme.paper))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.ink, lineWidth: Theme.line))
                purchaseArea
                if let m = message { Text(m).font(Theme.body(13)).foregroundStyle(Theme.ink) }
                Button("購入を復元") {
                    Task { busy = true; await app.store.restore(); app.refreshAfterPurchase(); busy = false
                        message = app.isPro ? "復元しました" : "復元できる購入が見つかりませんでした" }
                }
                .font(Theme.label(14)).foregroundStyle(Theme.ink).underline()
                Text("ワールド 1〜3（36 ステージ）・きょうの台・カプセルは、Pro がなくてもずっと遊べます。広告はありません。")
                    .font(Theme.body(12)).foregroundStyle(Theme.inkSoft).multilineTextAlignment(.center)
            }
            .padding(20)
        }
        .background(Theme.cream)
        .task { if app.store.loadState == .idle { await app.store.load() } }
    }

    @ViewBuilder private var purchaseArea: some View {
        if app.isPro {
            Label("Pro を使っています", systemImage: "checkmark.seal.fill").font(Theme.label(17)).foregroundStyle(Theme.mintDeep)
        } else if let product = app.store.products.first {
            Button {
                Task {
                    busy = true
                    let outcome = await app.store.purchase(product)
                    busy = false
                    app.refreshAfterPurchase()
                    switch outcome {
                    case .purchased: Feedback.bonus(); message = "ようこそ Pro へ！"
                    case .pending: message = "購入の承認を待っています"
                    case .cancelled: message = nil
                    case .failed: message = "購入できませんでした。時間をおいてもう一度お試しください"
                    }
                }
            } label: {
                Text(busy ? "…" : "\(product.displayPrice) で Pro にする")
            }
            .buttonStyle(ChunkyButtonStyle(fill: Theme.mint, text: .white, height: 58))
            .disabled(busy)
        } else if app.store.loadState == .loading || app.store.loadState == .idle {
            ProgressView().tint(Theme.ink)
        } else {
            VStack(spacing: 6) {
                Text("いまは購入できません").font(Theme.label(15)).foregroundStyle(Theme.ink)
                Text("通信をたしかめて、もう一度ひらいてください").font(Theme.body(12)).foregroundStyle(Theme.inkSoft)
                Button("もう一度読みこむ") { Task { await app.store.load() } }
                    .buttonStyle(ChunkyButtonStyle())
            }
        }
    }

    private func benefit(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.ink)
                .frame(width: 36, height: 36).background(Circle().fill(Theme.sun))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.label(16)).foregroundStyle(Theme.ink)
                Text(detail).font(Theme.body(13)).foregroundStyle(Theme.inkSoft)
            }
        }
    }
}
