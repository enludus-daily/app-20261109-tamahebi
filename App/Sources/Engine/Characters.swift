import Foundation

// なかま（キャラクター）の一覧。手で用意したデータ。色は 0xRRGGBB（Theme が SwiftUI の色にする）。

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

/// とくい（遊びが少しだけ変わる）
enum Perk: String, Codable, Sendable {
    case none, longGuide, grow, lucky8, bouncy, coins, bigCoins

    var label: String {
        switch self {
        case .none: "とくになし。まっすぐな子"
        case .longGuide: "よそく線が 1 回ぶん長い"
        case .grow: "球を食べると、ちょっと多めに伸びる"
        case .lucky8: "8 番球（30 点）が出やすい"
        case .bouncy: "バンパーで、よりはずむ"
        case .coins: "もらえるおやつ +20%"
        case .bigCoins: "もらえるおやつ +50%"
        }
    }

    func apply(to rules: inout Rules) {
        switch self {
        case .longGuide: rules.previewBounces += 1
        case .grow: rules.growPerBall += 12
        case .lucky8: rules.eightBallChance = 0.24
        case .bouncy: rules.bumperKick = 1.16
        case .none, .coins, .bigCoins: break
        }
    }

    var coinMultiplier: Double {
        switch self {
        case .coins: 1.2
        case .bigCoins: 1.5
        default: 1
        }
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

    var rules: Rules {
        var r = Rules.standard
        perk.apply(to: &r)
        return r
    }
}

enum Roster {
    static let starterID = "tama"

    static let all: [Character] = [
        Character(id: "tama", name: "タマ", rarity: .common, body: 0xFF8A7E, shade: 0xEA8077, belly: 0xFFF6E6, spot: 0xFFF6E6, mark: .star, perk: .none,
                  line: "球がだいすき。ころがるのは、もっとすき。"),
        Character(id: "mint", name: "ミント", rarity: .common, body: 0x8FD9B6, shade: 0x6CBF98, belly: 0xF4FFF8, spot: 0xF4FFF8, mark: .leaf, perk: .none,
                  line: "すずしい顔で、いつもまっすぐ。"),
        Character(id: "soda", name: "ソーダ", rarity: .common, body: 0x8CC8F2, shade: 0x6AAAD9, belly: 0xF2FAFF, spot: 0xFFFFFF, mark: .drop, perk: .none,
                  line: "はじけるのが好き。しゅわっ。"),
        Character(id: "lemon", name: "レモン", rarity: .common, body: 0xF7DA72, shade: 0xE3C76A, belly: 0xFFFBEA, spot: 0xFFFFFF, mark: .sun, perk: .none,
                  line: "朝いちばんに起きて台をみがく。"),
        Character(id: "momo", name: "モモ", rarity: .common, body: 0xF7A9C4, shade: 0xE08CA9, belly: 0xFFF3F7, spot: 0xFFFFFF, mark: .heart, perk: .none,
                  line: "あまえんぼう。8 番球がちょっとこわい。"),
        Character(id: "ramune", name: "ラムネ", rarity: .common, body: 0xC3B1EE, shade: 0xA693D6, belly: 0xF8F4FF, spot: 0xFFFFFF, mark: .note, perk: .none,
                  line: "ころがりながら鼻歌をうたう。"),
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
