import Foundation

// なかま（キャラクター）の一覧。手で用意したデータ。色は 0xRRGGBB（Theme が SwiftUI の色にする）。
// なかよし度（Lv1〜5）：同じ子がカプセルでもう一度出ると上がる。Lv2・Lv4 できせかえ、Lv3・Lv5 でとくいが強くなる。

enum Rarity: String, Codable, CaseIterable, Sendable {
    case common, rare, superRare, pro, pack

    var label: String {
        switch self {
        case .common: String(localized: "ふつう")
        case .rare: String(localized: "レア")
        case .superRare: String(localized: "スーパーレア")
        case .pro: String(localized: "Pro 限定")
        case .pack: String(localized: "パック限定")
        }
    }
    /// カプセルで出る確率（Pro 限定はカプセルから出ない）
    var pullRate: Double {
        switch self {
        case .common: 0.70
        case .rare: 0.25
        case .superRare: 0.05
        case .pro, .pack: 0
        }
    }
}

/// おでこの印
enum Mark: String, Codable, Sendable {
    case star, leaf, drop, sun, heart, note, eight, flower, snow, moon, crown, bolt, galaxy, blossom, flame
}

/// とくい。どれもステージの攻略か、おやつに効く
enum Perk: String, Codable, Sendable {
    case none, grip, warpBoost, bigMouth, ghostFriend, extraShot, longGuide, grow, lucky8, bouncy, coins, bigCoins
    case padBoost, breaker, rolling
    /// 1.1：新しい仕掛けに効くとくい
    case mudWalker, springy

    /// レベルごとの説明（level は 1〜5）
    func label(level: Int) -> String {
        let strong = level >= 3, max = level >= 5
        switch self {
        case .none: return max ? String(localized: "なかよし Lv5：おやつ +\(L.pct(10))") : String(localized: "とくになし。まっすぐな子（Lv5 でおやつ +\(L.pct(10))）")
        case .grip: return strong ? String(localized: "こおりの台でもすべりにくい（つよい）") : String(localized: "こおりの台でもすべりにくい")
        case .warpBoost: return strong ? String(localized: "ワープから出るとき、はやくなる（もっと）") : String(localized: "ワープから出るとき、はやくなる")
        case .bigMouth: return strong ? String(localized: "口が大きく、球を食べやすい（もっと大きい）") : String(localized: "口が大きく、球を食べやすい")
        case .ghostFriend: return strong ? String(localized: "ゴースト球が、クッションやバンパーで跳ねても目をさます") : String(localized: "ゴースト球と仲よし（Lv3 で、クッションでも目をさます）")
        case .extraShot: return strong ? String(localized: "ステージののこりショット +2") : String(localized: "ステージののこりショット +1")
        case .longGuide: return strong ? String(localized: "よそく線が 2 回ぶん長い") : String(localized: "よそく線が 1 回ぶん長い")
        case .grow: return strong ? String(localized: "はじめから長く、食べるとよく伸びる（もっと）") : String(localized: "はじめから長く、食べるとよく伸びる")
        case .lucky8: return strong ? String(localized: "8 番球が出やすく、ステージで 8 番を食べるとショット +1") : String(localized: "きょうの台で 8 番球（30 点）が出やすい")
        case .bouncy: return strong ? String(localized: "バンパーで、よりはずむ（もっと）") : String(localized: "バンパーで、よりはずむ")
        case .coins: return strong ? String(localized: "もらえるおやつ +\(L.pct(30))") : String(localized: "もらえるおやつ +\(L.pct(20))")
        case .bigCoins: return strong ? String(localized: "もらえるおやつ +\(L.pct(70))") : String(localized: "もらえるおやつ +\(L.pct(50))")
        case .padBoost: return strong ? String(localized: "かそく床で、もっと速く飛びだす（いちばん速い）") : String(localized: "かそく床で、もっと速く飛びだす")
        case .breaker: return strong ? String(localized: "こわれるブロックを、どれも 1 回でこわす") : String(localized: "かたいブロックに強い（Lv3 で、どれも 1 回でこわす）")
        case .rolling: return strong ? String(localized: "よく転がる（とまりにくい）（もっと）") : String(localized: "よく転がる（とまりにくい）")
        case .mudWalker: return strong ? String(localized: "ねばねば床でも、ほとんど止まらない") : String(localized: "ねばねば床で止まりにくい")
        case .springy: return strong ? String(localized: "はずむかべで、もっと速く返ってくる（いちばん）") : String(localized: "はずむかべで、もっと速く返ってくる")
        }
    }

    func apply(to rules: inout Rules, level: Int) {
        let strong = level >= 3
        switch self {
        case .grip: rules.iceFactor = strong ? 0.8 : 0.62
        case .warpBoost: rules.warpBoost = strong ? 1.35 : 1.2
        case .bigMouth: rules.eatRadius += strong ? 7 : 4
        case .ghostFriend: rules.ghostWakesOnAnyBounce = strong
        case .extraShot: rules.extraStageShots = strong ? 2 : 1
        case .longGuide: rules.previewBounces += strong ? 2 : 1
        case .grow: rules.growPerBall += strong ? 20 : 12; rules.extraStartLength = strong ? 80 : 40
        case .lucky8: rules.eightBallChance = 0.24; rules.eightGivesShot = strong
        case .bouncy: rules.bumperKick = strong ? 1.22 : 1.16
        case .padBoost: rules.padSpeed = strong ? 1000 : 900
        case .breaker: rules.breaksInOneHit = strong
        case .rolling: rules.friction *= strong ? 0.72 : 0.84
        case .mudWalker: rules.mudFactor = strong ? 2.0 : 3.5
        case .springy: rules.bouncyRestitution = strong ? 1.55 : 1.42
        case .none, .coins, .bigCoins: break
        }
    }

    func coinMultiplier(level: Int) -> Double {
        let strong = level >= 3
        switch self {
        case .coins: return strong ? 1.3 : 1.2
        case .bigCoins: return strong ? 1.7 : 1.5
        case .none: return level >= 5 ? 1.1 : 1
        default: return 1
        }
    }
}

/// きせかえ（なかよし Lv2 と Lv4 で増える）
enum Costume: Int, Codable, CaseIterable, Sendable {
    case original = 0, pastel = 1, night = 2

    var label: String {
        switch self {
        case .original: String(localized: "いつもの")
        case .pastel: String(localized: "パステル")
        case .night: String(localized: "よるいろ")
        }
    }
    /// このきせかえが使えるなかよし度
    var requiredLevel: Int {
        switch self {
        case .original: 1
        case .pastel: 2
        case .night: 4
        }
    }

    func transform(_ c: UInt32) -> UInt32 {
        switch self {
        case .original: return c
        case .pastel: return Self.mix(c, 0xFFFFFF, 0.35)
        case .night: return Self.mix(c, 0x6F7FC9, 0.45)
        }
    }

    static func mix(_ a: UInt32, _ b: UInt32, _ t: Double) -> UInt32 {
        func ch(_ v: UInt32, _ s: UInt32) -> Double { Double((v >> s) & 0xFF) }
        func m(_ s: UInt32) -> UInt32 { UInt32((ch(a, s) * (1 - t) + ch(b, s) * t).rounded()) << s }
        return m(16) | m(8) | m(0)
    }
}

struct Character: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let rarity: Rarity
    let body: UInt32
    let shade: UInt32
    let belly: UInt32
    let spot: UInt32
    let mark: Mark
    let perk: Perk
    let line: String

    func rules(level: Int = 1) -> Rules {
        var r = Rules.standard
        perk.apply(to: &r, level: level)
        return r
    }

    /// きせかえを着た色にした同じ子
    func wearing(_ costume: Costume) -> Character {
        guard costume != .original else { return self }
        return Character(id: id, name: name, rarity: rarity, body: costume.transform(body), shade: costume.transform(shade),
                         belly: belly, spot: spot, mark: mark, perk: perk, line: line)
    }
}

enum Roster {
    static let starterID = "tama"
    static let maxLevel = 5

    static let all: [Character] = [
        Character(id: "tama", name: String(localized: "タマ"), rarity: .common, body: 0xFF8A7E, shade: 0xEA8077, belly: 0xFFF6E6, spot: 0xFFF6E6, mark: .star, perk: .none,
                  line: String(localized: "球がだいすき。ころがるのは、もっとすき。")),
        Character(id: "mint", name: String(localized: "ミント"), rarity: .common, body: 0x8FD9B6, shade: 0x6CBF98, belly: 0xF4FFF8, spot: 0xF4FFF8, mark: .leaf, perk: .grip,
                  line: String(localized: "すずしい顔で、こおりの上もへっちゃら。")),
        Character(id: "soda", name: String(localized: "ソーダ"), rarity: .common, body: 0x8CC8F2, shade: 0x6AAAD9, belly: 0xF2FAFF, spot: 0xFFFFFF, mark: .drop, perk: .warpBoost,
                  line: String(localized: "穴をくぐると、しゅわっと加速する。")),
        Character(id: "lemon", name: String(localized: "レモン"), rarity: .common, body: 0xF7DA72, shade: 0xE3C76A, belly: 0xFFFBEA, spot: 0xFFFFFF, mark: .sun, perk: .bigMouth,
                  line: String(localized: "朝いちばんに起きて、大きな口であくび。")),
        Character(id: "momo", name: String(localized: "モモ"), rarity: .common, body: 0xF7A9C4, shade: 0xE08CA9, belly: 0xFFF3F7, spot: 0xFFFFFF, mark: .heart, perk: .ghostFriend,
                  line: String(localized: "ゴースト球とだけは、なぜか仲よし。")),
        Character(id: "ramune", name: String(localized: "ラムネ"), rarity: .common, body: 0xC3B1EE, shade: 0xA693D6, belly: 0xF8F4FF, spot: 0xFFFFFF, mark: .note, perk: .extraShot,
                  line: String(localized: "あきらめが悪い。もう 1 回だけ！")),
        Character(id: "goma", name: String(localized: "ゴマ"), rarity: .common, body: 0xCFC3B0, shade: 0xB5A893, belly: 0xFFFBF2, spot: 0x6E625C, mark: .moon, perk: .rolling,
                  line: String(localized: "のんびり屋。いちど転がると、なかなか止まらない。")),
        Character(id: "yuzu", name: String(localized: "ユズ"), rarity: .common, body: 0xD8E58A, shade: 0xBFCC72, belly: 0xFBFFE8, spot: 0xFFFFFF, mark: .leaf, perk: .padBoost,
                  line: String(localized: "矢印を見ると、つい乗りたくなる。")),
        Character(id: "kurosuke", name: String(localized: "クロスケ"), rarity: .rare, body: 0x5B5160, shade: 0x463D4B, belly: 0xE9E2EC, spot: 0xF7D063, mark: .eight, perk: .lucky8,
                  line: String(localized: "8 番球のにおいがわかるらしい。")),
        Character(id: "wataame", name: String(localized: "ワタアメ"), rarity: .rare, body: 0xF9C6DD, shade: 0xA9D4F2, belly: 0xFFFFFF, spot: 0xA9D4F2, mark: .flower, perk: .grow,
                  line: String(localized: "食べるたびに、ふわっとふくらむ。")),
        Character(id: "hakka", name: String(localized: "ハッカ"), rarity: .rare, body: 0xD6ECF7, shade: 0xAFD3E6, belly: 0xFFFFFF, spot: 0x8CC8F2, mark: .snow, perk: .longGuide,
                  line: String(localized: "先のことまで、ひんやり見とおす。")),
        Character(id: "caramel", name: String(localized: "キャラメル"), rarity: .rare, body: 0xD9A877, shade: 0xBD8D5E, belly: 0xFFF1DE, spot: 0xFFF1DE, mark: .moon, perk: .coins,
                  line: String(localized: "おやつをためこむのがとくい。")),
        Character(id: "ishimaru", name: String(localized: "イシマル"), rarity: .rare, body: 0xA9A4B5, shade: 0x8E899B, belly: 0xF1EFF5, spot: 0xD9D5E2, mark: .bolt, perk: .breaker,
                  line: String(localized: "かたい頭が自まん。ブロックはまかせて。")),
        Character(id: "ruri", name: String(localized: "ルリ"), rarity: .rare, body: 0x8FA9E8, shade: 0x7590D1, belly: 0xF0F4FF, spot: 0xFFFFFF, mark: .drop, perk: .rolling,
                  line: String(localized: "台の上を、すべるように泳ぐ。")),
        Character(id: "kirari", name: String(localized: "キラリ"), rarity: .superRare, body: 0xF2D27E, shade: 0xDEC172, belly: 0xFFFDF2, spot: 0xFFFFFF, mark: .crown, perk: .bigCoins,
                  line: String(localized: "台の王さま。おやつがざくざく。")),
        Character(id: "neon", name: String(localized: "ネオン"), rarity: .superRare, body: 0x9FE6E0, shade: 0xF5A3D8, belly: 0xFFFFFF, spot: 0xF5A3D8, mark: .bolt, perk: .bouncy,
                  line: String(localized: "バンパーに当たると、ぴかっと光る。")),
        Character(id: "aurora", name: String(localized: "オーロラ"), rarity: .superRare, body: 0xA6E3CF, shade: 0xC6B4F0, belly: 0xFFFFFF, spot: 0xF7C4DD, mark: .galaxy, perk: .longGuide,
                  line: String(localized: "夜空のいろを、からだにまとう。")),
        Character(id: "milk", name: String(localized: "ミルク"), rarity: .superRare, body: 0xF4F1EC, shade: 0xDCD6CE, belly: 0xFFFFFF, spot: 0xA9D4F2, mark: .note, perk: .bigMouth,
                  line: String(localized: "なんでもひとのみ。口の大きさは台いちばん。")),
        Character(id: "kinako", name: String(localized: "キナコ"), rarity: .common, body: 0xE8CFA0, shade: 0xD1B684, belly: 0xFFF8EA, spot: 0xFFFFFF, mark: .moon, perk: .mudWalker,
                  line: String(localized: "ねばねばの床でも、すいすい進む。")),
        Character(id: "sora", name: String(localized: "ソラ"), rarity: .common, body: 0xA9D4F2, shade: 0x8BBCE0, belly: 0xF5FBFF, spot: 0xFFFFFF, mark: .star, perk: .extraShot,
                  line: String(localized: "空を見上げて、もう 1 回。")),
        Character(id: "ichigo", name: String(localized: "イチゴ"), rarity: .common, body: 0xF58E9A, shade: 0xDE7581, belly: 0xFFF1F2, spot: 0xFFF3B0, mark: .heart, perk: .springy,
                  line: String(localized: "しま模様のかべが大すき。ぽよん！")),
        Character(id: "nori", name: String(localized: "ノリ"), rarity: .common, body: 0x7E9C7E, shade: 0x678567, belly: 0xF1F7EE, spot: 0xFFFFFF, mark: .leaf, perk: .grip,
                  line: String(localized: "しっとりして、すべらない。")),
        Character(id: "purin", name: String(localized: "プリン"), rarity: .rare, body: 0xF7E3A0, shade: 0xE5CC80, belly: 0xFFFBEE, spot: 0xC98A5A, mark: .crown, perk: .mudWalker,
                  line: String(localized: "ぷるぷるで、ねばねばに負けない。")),
        Character(id: "cocoa", name: String(localized: "ココア"), rarity: .rare, body: 0xA9826F, shade: 0x8E6A59, belly: 0xF5E8DF, spot: 0xFFFFFF, mark: .note, perk: .breaker,
                  line: String(localized: "あまい顔して、力もち。")),
        Character(id: "hotaru", name: String(localized: "ホタル"), rarity: .rare, body: 0xC9E86F, shade: 0xAFCF58, belly: 0xFBFFE6, spot: 0xFFF3B0, mark: .bolt, perk: .longGuide,
                  line: String(localized: "暗い台でも、道を照らす。")),
        Character(id: "umi", name: String(localized: "ウミ"), rarity: .rare, body: 0x6FB7C9, shade: 0x579EB0, belly: 0xEEFAFD, spot: 0xFFFFFF, mark: .drop, perk: .warpBoost,
                  line: String(localized: "波にのって、穴から穴へ。")),
        Character(id: "marshmallow", name: String(localized: "マシュマロ"), rarity: .rare, body: 0xFBEFF5, shade: 0xE9D3E0, belly: 0xFFFFFF, spot: 0xF7C4DD, mark: .flower, perk: .grow,
                  line: String(localized: "ふわふわ伸びる、白いからだ。")),
        Character(id: "niji", name: String(localized: "ニジ"), rarity: .superRare, body: 0xF7B6C8, shade: 0xA6E3CF, belly: 0xFFFFFF, spot: 0xF7E3A0, mark: .galaxy, perk: .springy,
                  line: String(localized: "かべに当たるたびに、いろが変わる。")),
        Character(id: "kohaku", name: String(localized: "コハク"), rarity: .superRare, body: 0xF0B45A, shade: 0xD99A43, belly: 0xFFF4E0, spot: 0xFFFFFF, mark: .sun, perk: .lucky8,
                  line: String(localized: "8 番球を見つけると、きらりと光る。")),
        Character(id: "yozora", name: String(localized: "ヨゾラ"), rarity: .superRare, body: 0x45528A, shade: 0x34406E, belly: 0xE6E9FA, spot: 0xFFF3B0, mark: .moon, perk: .ghostFriend,
                  line: String(localized: "ゴースト球と、夜どおしおしゃべり。")),
        Character(id: "ginga", name: String(localized: "ギンガ"), rarity: .pro, body: 0x6F7FC9, shade: 0x5867AE, belly: 0xE8ECFF, spot: 0xFFF3B0, mark: .galaxy, perk: .longGuide,
                  line: String(localized: "夜の台で、星の線をたどる。")),
        Character(id: "sakura", name: String(localized: "サクラ"), rarity: .pro, body: 0xF8C3CF, shade: 0xE7A2B3, belly: 0xFFF7F9, spot: 0xFFFFFF, mark: .blossom, perk: .grow,
                  line: String(localized: "春のように、のびのびと。")),
        Character(id: "homura", name: String(localized: "ホムラ"), rarity: .pro, body: 0xF7B27A, shade: 0xE59D6A, belly: 0xFFF2E3, spot: 0xFFE08A, mark: .flame, perk: .bouncy,
                  line: String(localized: "あつい一打で、台をかけぬける。")),
        Character(id: "custard", name: String(localized: "カスタード"), rarity: .pack, body: 0xF6DD9A, shade: 0xE3C47A, belly: 0xFFF9E8, spot: 0xD9A877, mark: .flower, perk: .padBoost,
                  line: String(localized: "おやつ三姉妹の長女。ぷるんと加速。")),
        Character(id: "choco", name: String(localized: "チョコ"), rarity: .pack, body: 0xB88A6E, shade: 0x9C7258, belly: 0xF5E6DA, spot: 0xF7C4DD, mark: .heart, perk: .breaker,
                  line: String(localized: "おやつ三姉妹の次女。かたいものもパキッ。")),
        Character(id: "matcha", name: String(localized: "マッチャ"), rarity: .pack, body: 0xA9C98A, shade: 0x8FB070, belly: 0xF6FBEE, spot: 0xFFFFFF, mark: .leaf, perk: .bigCoins,
                  line: String(localized: "おやつ三姉妹の三女。おやつ集めの名人。")),
    ]

    static func character(_ id: String) -> Character {
        all.first { $0.id == id } ?? all[0]
    }

    static var capsulePool: [Character] { all.filter { $0.rarity != .pro && $0.rarity != .pack } }
    static var proOnly: [Character] { all.filter { $0.rarity == .pro } }
    static var packOnly: [Character] { all.filter { $0.rarity == .pack } }
}
