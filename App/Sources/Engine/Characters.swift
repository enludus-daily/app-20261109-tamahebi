import Foundation

// なかま（キャラクター）の一覧。手で用意したデータ。色は 0xRRGGBB（Theme が SwiftUI の色にする）。
// なかよし度（Lv1〜5）：同じ子がカプセルでもう一度出ると上がる。Lv2・Lv4 できせかえ、Lv3・Lv5 でとくいが強くなる。

enum Rarity: String, Codable, CaseIterable, Sendable {
    case common, rare, superRare, pro

    var label: String {
        switch self {
        case .common: "ふつう"
        case .rare: "レア"
        case .superRare: "スーパーレア"
        case .pro: "Pro 限定"
        }
    }
    /// カプセルで出る確率（Pro 限定はカプセルから出ない）
    var pullRate: Double {
        switch self {
        case .common: 0.70
        case .rare: 0.25
        case .superRare: 0.05
        case .pro: 0
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

    /// レベルごとの説明（level は 1〜5）
    func label(level: Int) -> String {
        let strong = level >= 3, max = level >= 5
        switch self {
        case .none: return max ? "なかよし Lv5：おやつ +10%" : "とくになし。まっすぐな子（Lv5 でおやつ +10%）"
        case .grip: return "こおりの台でもすべりにくい" + (strong ? "（つよい）" : "")
        case .warpBoost: return "ワープから出るとき、はやくなる" + (strong ? "（もっと）" : "")
        case .bigMouth: return "口が大きく、球を食べやすい" + (strong ? "（もっと大きい）" : "")
        case .ghostFriend: return strong ? "ゴースト球が、クッションやバンパーで跳ねても目をさます" : "ゴースト球と仲よし（Lv3 で、クッションでも目をさます）"
        case .extraShot: return strong ? "ステージののこりショット +2" : "ステージののこりショット +1"
        case .longGuide: return strong ? "よそく線が 2 回ぶん長い" : "よそく線が 1 回ぶん長い"
        case .grow: return "はじめから長く、食べるとよく伸びる" + (strong ? "（もっと）" : "")
        case .lucky8: return strong ? "8 番球が出やすく、ステージで 8 番を食べるとショット +1" : "きょうの台で 8 番球（30 点）が出やすい"
        case .bouncy: return "バンパーで、よりはずむ" + (strong ? "（もっと）" : "")
        case .coins: return "もらえるおやつ +\(strong ? 30 : 20)%"
        case .bigCoins: return "もらえるおやつ +\(strong ? 70 : 50)%"
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
        case .original: "いつもの"
        case .pastel: "パステル"
        case .night: "よるいろ"
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
        Character(id: "tama", name: "タマ", rarity: .common, body: 0xFF8A7E, shade: 0xEA8077, belly: 0xFFF6E6, spot: 0xFFF6E6, mark: .star, perk: .none,
                  line: "球がだいすき。ころがるのは、もっとすき。"),
        Character(id: "mint", name: "ミント", rarity: .common, body: 0x8FD9B6, shade: 0x6CBF98, belly: 0xF4FFF8, spot: 0xF4FFF8, mark: .leaf, perk: .grip,
                  line: "すずしい顔で、こおりの上もへっちゃら。"),
        Character(id: "soda", name: "ソーダ", rarity: .common, body: 0x8CC8F2, shade: 0x6AAAD9, belly: 0xF2FAFF, spot: 0xFFFFFF, mark: .drop, perk: .warpBoost,
                  line: "穴をくぐると、しゅわっと加速する。"),
        Character(id: "lemon", name: "レモン", rarity: .common, body: 0xF7DA72, shade: 0xE3C76A, belly: 0xFFFBEA, spot: 0xFFFFFF, mark: .sun, perk: .bigMouth,
                  line: "朝いちばんに起きて、大きな口であくび。"),
        Character(id: "momo", name: "モモ", rarity: .common, body: 0xF7A9C4, shade: 0xE08CA9, belly: 0xFFF3F7, spot: 0xFFFFFF, mark: .heart, perk: .ghostFriend,
                  line: "ゴースト球とだけは、なぜか仲よし。"),
        Character(id: "ramune", name: "ラムネ", rarity: .common, body: 0xC3B1EE, shade: 0xA693D6, belly: 0xF8F4FF, spot: 0xFFFFFF, mark: .note, perk: .extraShot,
                  line: "あきらめが悪い。もう 1 回だけ！"),
        Character(id: "kurosuke", name: "クロスケ", rarity: .rare, body: 0x5B5160, shade: 0x463D4B, belly: 0xE9E2EC, spot: 0xF7D063, mark: .eight, perk: .lucky8,
                  line: "8 番球のにおいがわかるらしい。"),
        Character(id: "wataame", name: "ワタアメ", rarity: .rare, body: 0xF9C6DD, shade: 0xA9D4F2, belly: 0xFFFFFF, spot: 0xA9D4F2, mark: .flower, perk: .grow,
                  line: "食べるたびに、ふわっとふくらむ。"),
        Character(id: "hakka", name: "ハッカ", rarity: .rare, body: 0xD6ECF7, shade: 0xAFD3E6, belly: 0xFFFFFF, spot: 0x8CC8F2, mark: .snow, perk: .longGuide,
                  line: "先のことまで、ひんやり見とおす。"),
        Character(id: "caramel", name: "キャラメル", rarity: .rare, body: 0xD9A877, shade: 0xBD8D5E, belly: 0xFFF1DE, spot: 0xFFF1DE, mark: .moon, perk: .coins,
                  line: "おやつをためこむのがとくい。"),
        Character(id: "kirari", name: "キラリ", rarity: .superRare, body: 0xF2D27E, shade: 0xDEC172, belly: 0xFFFDF2, spot: 0xFFFFFF, mark: .crown, perk: .bigCoins,
                  line: "台の王さま。おやつがざくざく。"),
        Character(id: "neon", name: "ネオン", rarity: .superRare, body: 0x9FE6E0, shade: 0xF5A3D8, belly: 0xFFFFFF, spot: 0xF5A3D8, mark: .bolt, perk: .bouncy,
                  line: "バンパーに当たると、ぴかっと光る。"),
        Character(id: "ginga", name: "ギンガ", rarity: .pro, body: 0x6F7FC9, shade: 0x5867AE, belly: 0xE8ECFF, spot: 0xFFF3B0, mark: .galaxy, perk: .longGuide,
                  line: "夜の台で、星の線をたどる。"),
        Character(id: "sakura", name: "サクラ", rarity: .pro, body: 0xF8C3CF, shade: 0xE7A2B3, belly: 0xFFF7F9, spot: 0xFFFFFF, mark: .blossom, perk: .grow,
                  line: "春のように、のびのびと。"),
        Character(id: "homura", name: "ホムラ", rarity: .pro, body: 0xF7B27A, shade: 0xE59D6A, belly: 0xFFF2E3, spot: 0xFFE08A, mark: .flame, perk: .bouncy,
                  line: "あつい一打で、台をかけぬける。"),
    ]

    static func character(_ id: String) -> Character {
        all.first { $0.id == id } ?? all[0]
    }

    static var capsulePool: [Character] { all.filter { $0.rarity != .pro } }
    static var proOnly: [Character] { all.filter { $0.rarity == .pro } }
}
