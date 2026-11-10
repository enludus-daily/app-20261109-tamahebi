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
                    .accessibilityLabel(String(localized: "とじる"))
                }
                Text(String(localized: "おみせ")).font(Theme.title(32)).foregroundStyle(Theme.ink)
                Text(String(localized: "どれも 1 回買えば、ずっと使えます")).font(Theme.body(14)).foregroundStyle(Theme.inkSoft)

                item(id: ProductID.pro(bundleID: app.bundleID), owned: app.isPro, title: String(localized: "タマヘビ Pro"), tag: String(localized: "いちばん人気"),
                     friends: Roster.proOnly) {
                    benefit("map.fill", String(localized: "ワールド 4〜6（\(L.s(count(4...6))) ステージ）"), String(localized: "ワープの台・うごくバンパー・よるのごちゃまぜ"))
                    benefit("nosign", String(localized: "広告が出ない"), String(localized: "バナーと、遊んだあとの全画面広告がなくなる（見たいときの動画は選べる）"))
                    benefit("lightbulb.fill", String(localized: "ヒントがいつでも無料"), String(localized: "どのステージでも ★3 のおてほんを見られる"))
                    benefit("person.3.fill", String(localized: "限定のなかま 3 匹（なかよし Lv3 から）"), String(localized: "ギンガ・サクラ・ホムラ"))
                    benefit("bag.fill", String(localized: "おやつがずっと 2 倍"), String(localized: "カプセルを倍回せる。なかよし度が早く上がる"))
                    benefit("square.grid.2x2.fill", String(localized: "台のいろ 3 種"), String(localized: "きょうの台を、みどり・すもも・よるに"))
                }
                item(id: app.worldPackID, owned: app.hasWorldPack, title: String(localized: "ワールドパック"), tag: String(localized: "新しい仕掛け"), friends: []) {
                    benefit("arrow.right.circle.fill", String(localized: "ワールド 7：かそく床の台（\(L.s(count(7...7)))）"), String(localized: "矢印の床で、ぎゅんと加速"))
                    benefit("square.split.diagonal.2x2.fill", String(localized: "ワールド 8：こわれるブロック（\(L.s(count(8...8)))）"), String(localized: "ブロックをこわして道を作る"))
                    benefit("checkmark.circle.fill", String(localized: "ワールド 3 のあとから遊べる"), String(localized: "Pro がなくても遊べます"))
                }
                item(id: app.friendPackID, owned: app.hasFriendPack, title: String(localized: "なかまパック：おやつ三姉妹"), tag: String(localized: "なかま 3 匹"), friends: Roster.packOnly) {
                    benefit("person.3.fill", String(localized: "カスタード・チョコ・マッチャ"), String(localized: "カプセルからは出ない子たち。なかよし Lv3 から"))
                    benefit("sparkle", String(localized: "とくい：かそく床・ブロック・おやつ"), String(localized: "ワールド 7〜8 で活やく。マッチャはおやつ +\(L.pct(70))"))
                }
                if let m = message { Text(m).font(Theme.body(13)).foregroundStyle(Theme.ink) }
                Button(String(localized: "購入を復元")) {
                    Task { busy = "restore"; await app.store.restore(); app.refreshAfterPurchase(); busy = nil
                        message = (app.isPro || app.hasWorldPack || app.hasFriendPack) ? String(localized: "復元しました") : String(localized: "復元できる購入が見つかりませんでした") }
                }
                .font(Theme.label(14)).foregroundStyle(Theme.ink).underline()
                if AdMobRewarded.needsPrivacyOptions {
                    Button(String(localized: "広告のプライバシー設定")) { Task { await AdMobRewarded.showPrivacyOptions() } }
                        .font(Theme.label(13)).foregroundStyle(Theme.ink).underline()
                }
                Text(String(localized: "ワールド 1〜3（\(L.s(count(1...3))) ステージ）・きょうの台・カプセル・\(L.s(Roster.capsulePool.count)) 匹のなかまは、買わなくてもずっと遊べます。広告は、画面の下のバナーと、遊んだあとにときどき出る全画面広告（どちらも Pro で消える）と、ヒントやおやつ 2 倍のために自分で選んで見る動画です。おやつ（ゲーム内のポイント）は売っていません。"))
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
            Label(String(localized: "持っています"), systemImage: "checkmark.seal.fill").font(Theme.label(16)).foregroundStyle(Theme.mintDeep)
                .frame(maxWidth: .infinity)
        } else if let product = app.store.products.first(where: { $0.id == id }) {
            Button {
                Task {
                    busy = id
                    let outcome = await app.store.purchase(product)
                    busy = nil
                    app.refreshAfterPurchase()
                    switch outcome {
                    case .purchased: Feedback.bonus(); message = String(localized: "ありがとう！使えるようになりました")
                    case .pending: message = String(localized: "購入の承認を待っています")
                    case .cancelled: message = nil
                    case .failed: message = String(localized: "購入できませんでした。時間をおいてもう一度お試しください")
                    }
                }
            } label: {
                Text(busy == id ? "…" : String(localized: "\(L.s(product.displayPrice)) で買う"))
            }
            .buttonStyle(ChunkyButtonStyle(fill: Theme.mint, text: .white, height: 54))
            .disabled(busy != nil)
        } else if app.store.loadState == .loading || app.store.loadState == .idle {
            ProgressView().tint(Theme.ink).frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 6) {
                Text(String(localized: "いまは購入できません")).font(Theme.label(14)).foregroundStyle(Theme.ink)
                Button(String(localized: "もう一度読みこむ")) { Task { await app.store.load() } }
                    .font(Theme.label(13)).foregroundStyle(Theme.ink).underline()
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// ステージの数はデータから数える（ふえても書き直さなくてよい）
    private func count(_ worlds: ClosedRange<Int>) -> Int { app.book.filter { worlds.contains($0.world) }.count }

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
