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
        case .eatAll: "ぜんぶ食べよう"
        case .eatEight: "8 番球を食べよう"
        case .score: "\(target) 点とろう"
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
    var ice = false
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
    let id: Int
    let name: String
    let detail: String
    let isPro: Bool
    let felt: UInt32
}

enum StageBook {
    static let worlds: [World] = [
        World(id: 1, name: "ビリヤード場", detail: "まずは球を食べるところから", isPro: false, felt: 0x3D7CC0),
        World(id: 2, name: "からだクッション", detail: "ゴースト球は、からだで跳ねてから", isPro: false, felt: 0x3F9A73),
        World(id: 3, name: "こおりの台", detail: "よくすべる台と、かべ", isPro: false, felt: 0x5C8FB0),
        World(id: 4, name: "ワープの台", detail: "穴に入ると、もう片方から出る", isPro: true, felt: 0x8A5A8C),
        World(id: 5, name: "うごくバンパー", detail: "タイミングをはかって打つ", isPro: true, felt: 0x9A6B4F),
        World(id: 6, name: "よるのごちゃまぜ", detail: "ぜんぶの仕掛けが出てくる", isPro: true, felt: 0x2E3A66),
    ]

    static func decode(_ data: Data) throws -> [Stage] {
        try JSONDecoder().decode([Stage].self, from: data)
    }

    static func world(_ id: Int) -> World { worlds.first { $0.id == id } ?? worlds[0] }
}
