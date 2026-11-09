import StoreKit
import SwiftUI

/// おみせ：買い切りの Pro と、追加パック 2 つ（どれも 1 回買えばずっと使える。おやつは売らない）
struct ProView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var busy: String?
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
                Text("おみせ").font(Theme.title(32)).foregroundStyle(Theme.ink)
                Text("どれも 1 回買えば、ずっと使えます").font(Theme.body(14)).foregroundStyle(Theme.inkSoft)

                item(id: ProductID.pro(bundleID: app.bundleID), owned: app.isPro, title: "タマヘビ Pro", tag: "いちばん人気",
                     friends: Roster.proOnly) {
                    benefit("map.fill", "ワールド 4〜6（36 ステージ）", "ワープの台・うごくバンパー・よるのごちゃまぜ")
                    benefit("lightbulb.fill", "ヒントがいつでも無料", "どのステージでも ★3 のおてほんを見られる")
                    benefit("person.3.fill", "限定のなかま 3 匹（なかよし Lv3 から）", "ギンガ・サクラ・ホムラ")
                    benefit("bag.fill", "おやつがずっと 2 倍", "カプセルを倍回せる。なかよし度が早く上がる")
                    benefit("square.grid.2x2.fill", "台のいろ 3 種", "きょうの台を、みどり・すもも・よるに")
                }
                item(id: app.worldPackID, owned: app.hasWorldPack, title: "ワールドパック", tag: "新しい仕掛け", friends: []) {
                    benefit("arrow.right.circle.fill", "ワールド 7：かそく床の台（12）", "矢印の床で、ぎゅんと加速")
                    benefit("square.split.diagonal.2x2.fill", "ワールド 8：こわれるブロック（12）", "ブロックをこわして道を作る")
                    benefit("checkmark.circle.fill", "ワールド 3 のあとから遊べる", "Pro がなくても遊べます")
                }
                item(id: app.friendPackID, owned: app.hasFriendPack, title: "なかまパック：おやつ三姉妹", tag: "なかま 3 匹", friends: Roster.packOnly) {
                    benefit("person.3.fill", "カスタード・チョコ・マッチャ", "カプセルからは出ない子たち。なかよし Lv3 から")
                    benefit("sparkle", "とくい：かそく床・ブロック・おやつ", "ワールド 7〜8 で活やく。マッチャはおやつ +70%")
                }
                if let m = message { Text(m).font(Theme.body(13)).foregroundStyle(Theme.ink) }
                Button("購入を復元") {
                    Task { busy = "restore"; await app.store.restore(); app.refreshAfterPurchase(); busy = nil
                        message = (app.isPro || app.hasWorldPack || app.hasFriendPack) ? "復元しました" : "復元できる購入が見つかりませんでした" }
                }
                .font(Theme.label(14)).foregroundStyle(Theme.ink).underline()
                Text("ワールド 1〜3（36 ステージ）・きょうの台・カプセル・18 匹のなかまは、買わなくてもずっと遊べます。おやつ（ゲーム内のポイント）は売っていません。")
                    .font(Theme.body(12)).foregroundStyle(Theme.inkSoft).multilineTextAlignment(.center)
            }
            .padding(20)
        }
        .background(Theme.cream)
        .task { if app.store.loadState == .idle { await app.store.load() } }
    }

    private func item<Content: View>(id: String, owned: Bool, title: String, tag: String, friends: [Character],
                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(Theme.title(20)).foregroundStyle(Theme.ink)
                Spacer()
                Text(tag).font(Theme.label(11)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Theme.sun))
            }
            if !friends.isEmpty {
                HStack(spacing: -14) {
                    ForEach(friends) { c in
                        CharacterPortrait(character: c, face: .happy, showBody: false).frame(width: 84, height: 68)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            content()
            buyButton(id: id, owned: owned)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.paper))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.ink, lineWidth: Theme.line))
    }

    @ViewBuilder private func buyButton(id: String, owned: Bool) -> some View {
        if owned {
            Label("持っています", systemImage: "checkmark.seal.fill").font(Theme.label(16)).foregroundStyle(Theme.mintDeep)
                .frame(maxWidth: .infinity)
        } else if let product = app.store.products.first(where: { $0.id == id }) {
            Button {
                Task {
                    busy = id
                    let outcome = await app.store.purchase(product)
                    busy = nil
                    app.refreshAfterPurchase()
                    switch outcome {
                    case .purchased: Feedback.bonus(); message = "ありがとう！使えるようになりました"
                    case .pending: message = "購入の承認を待っています"
                    case .cancelled: message = nil
                    case .failed: message = "購入できませんでした。時間をおいてもう一度お試しください"
                    }
                }
            } label: {
                Text(busy == id ? "…" : "\(product.displayPrice) で買う")
            }
            .buttonStyle(ChunkyButtonStyle(fill: Theme.mint, text: .white, height: 54))
            .disabled(busy != nil)
        } else if app.store.loadState == .loading || app.store.loadState == .idle {
            ProgressView().tint(Theme.ink).frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 6) {
                Text("いまは購入できません").font(Theme.label(14)).foregroundStyle(Theme.ink)
                Button("もう一度読みこむ") { Task { await app.store.load() } }
                    .font(Theme.label(13)).foregroundStyle(Theme.ink).underline()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func benefit(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
                .frame(width: 32, height: 32).background(Circle().fill(Theme.sun.opacity(0.7)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.label(15)).foregroundStyle(Theme.ink)
                Text(detail).font(Theme.body(12)).foregroundStyle(Theme.inkSoft)
            }
        }
    }
}
