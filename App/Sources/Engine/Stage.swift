import Foundation

// ステージ：決まった配置と「おだい」。データは App/Resources/stages.json（tools/stagegen で作り、解けることを確かめてある）。

struct Shot: Equatable, Codable, Sendable {
    /// 向き（ラジアン。0 が右、π/2 が下）
    var angle: Double
    var power: Double
}

struct Goal: Equatable, Codable, Sendable {
    enum Kind: String, Codable, Sendable { case eatAll, eatEight, score }
    var kind: Kind
    var target: Int = 0

    var label: String {
        switch kind {
        case .eatAll: String(localized: "ぜんぶ食べよう")
        case .eatEight: String(localized: "8 番球を食べよう")
        case .score: String(localized: "\(L.s(target)) 点とろう")
        }
    }
}

struct StageBumper: Equatable, Codable, Sendable {
    var center: Vec
    var radius: Double
    var axis = Vec(x: 1, y: 0)
    var amplitude = 0.0
    var speed = 0.0
    var phase = 0.0
}

struct StageBall: Equatable, Codable, Sendable {
    var center: Vec
    var number: Int
    var kind: BallKind = .normal
}

struct Stage: Identifiable, Equatable, Codable, Sendable {
    /// "1-1" のような番号
    var id: String
    var world: Int
    var index: Int
    var head: Vec
    /// はじめのからだ（尻尾から頭の手前までの折れ線）
    var body: [Vec]
    var bumpers: [StageBumper] = []
    var balls: [StageBall]
    var walls: [Wall] = []
    var warps: [Warp] = []
    var pads: [Pad] = []
    var muds: [Mud] = []
    var holes: [Hole] = []
    var ice = false
    /// じゅんばん球：番号の小さい順にしか食べられない
    var ordered = false
    var goal: Goal
    var shots: Int
    /// このショット数以内なら星 3、par2 以内なら星 2、それ以外のクリアは星 1
    var par3: Int
    var par2: Int
    /// 解けることを確かめた打ち方（テストで再生する）
    var solution: [Shot] = []
    /// はじめて見る仕掛けのときの説明
    var hint: String?

    func stars(shotsUsed: Int) -> Int {
        shotsUsed <= par3 ? 3 : (shotsUsed <= par2 ? 2 : 1)
    }
}

struct World: Identifiable, Equatable, Sendable {
    enum Access: Equatable, Sendable { case free, pro, pack }
    let id: Int
    let name: String
    let detail: String
    let access: Access
    let felt: UInt32
    var isPro: Bool { access == .pro }
    var isPack: Bool { access == .pack }
}

enum StageBook {
    static let worlds: [World] = [
        World(id: 1, name: String(localized: "ビリヤード場"), detail: String(localized: "まずは球を食べるところから"), access: .free, felt: 0x3D7CC0),
        World(id: 2, name: String(localized: "からだクッション"), detail: String(localized: "ゴースト球は、からだで跳ねてから"), access: .free, felt: 0x3F9A73),
        World(id: 3, name: String(localized: "こおりの台"), detail: String(localized: "よくすべる台と、かべ"), access: .free, felt: 0x5C8FB0),
        World(id: 4, name: String(localized: "ワープの台"), detail: String(localized: "穴に入ると、もう片方から出る"), access: .pro, felt: 0x8A5A8C),
        World(id: 5, name: String(localized: "うごくバンパー"), detail: String(localized: "タイミングをはかって打つ"), access: .pro, felt: 0x9A6B4F),
        World(id: 6, name: String(localized: "よるのごちゃまぜ"), detail: String(localized: "ぜんぶの仕掛けが出てくる"), access: .pro, felt: 0x2E3A66),
        World(id: 7, name: String(localized: "かそく床の台"), detail: String(localized: "矢印の床に乗ると、ぎゅんと加速"), access: .pack, felt: 0x4F8F8F),
        World(id: 8, name: String(localized: "こわれるブロック"), detail: String(localized: "ブロックは当てるとこわれる。こわして道を作る"), access: .pack, felt: 0x7A6A9A),
    ]

    static func decode(_ data: Data) throws -> [Stage] {
        try JSONDecoder().decode([Stage].self, from: data)
    }

    static func world(_ id: Int) -> World { worlds.first { $0.id == id } ?? worlds[0] }
}
