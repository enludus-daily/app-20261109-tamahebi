import Foundation

// エリア：ワールドを 12 ステージずつに分けたもの。エリアごとに、新しい仕掛けか新しい組み合わせが出る。
// ステージの生成（tools/stagegen）と、ステージ一覧の見出しの両方がこの表を使う。

enum Gimmick: String, CaseIterable, Sendable {
    case bumper, wall, eight, mud, bouncy, hole, ordered, ghost, ice, warp, moving, pad, block

    var label: String {
        switch self {
        case .bumper: String(localized: "バンパー")
        case .wall: String(localized: "かべ")
        case .eight: String(localized: "8 番球")
        case .mud: String(localized: "ねばねば床")
        case .bouncy: String(localized: "はずむかべ")
        case .hole: String(localized: "おとし穴")
        case .ordered: String(localized: "じゅんばん球")
        case .ghost: String(localized: "ゴースト球")
        case .ice: String(localized: "こおり")
        case .warp: String(localized: "ワープ")
        case .moving: String(localized: "うごくバンパー")
        case .pad: String(localized: "かそく床")
        case .block: String(localized: "こわれるブロック")
        }
    }

    /// はじめて出てくるステージで見せる説明（stages.json の hint。String Catalog で英語になる）
    var introHint: String {
        switch self {
        case .bumper: "黄色いバンパーに当たると、よくはずむ"
        case .wall: "木のかべでも跳ね返る。かべを使って回りこもう"
        case .eight: "8 番球を食べればクリア。ほかの球は食べなくてもいい"
        case .mud: "茶色いねばねば床に乗ると、すぐに止まる。止めたいところで使おう"
        case .bouncy: "しま模様のかべは、よくはずむ。当たると速くなって返ってくる"
        case .hole: "おとし穴に落ちると、打つ前の場所にもどる。食べた球はそのまま"
        case .ordered: "じゅんばん球：番号の小さい順にしか食べられない。光っている球がつぎ"
        case .ghost: "すけている球はゴースト球。からだで跳ね返ったあとだけ食べられる"
        case .ice: "こおりの台はよくすべる。弱めに打とう。かべでも跳ね返る"
        case .warp: "穴に入ると、もう片方の穴から同じ向きで出てくる"
        case .moving: "バンパーが動いている。よそく線は、いま打ったときの線"
        case .pad: "矢印の床に乗ると、矢印の向きにぎゅんと飛びだす"
        case .block: "こわれるブロックは当てるとこわれる。白い線のブロックは 2 回"
        }
    }

    /// お金で開くワールドの仕掛け（無料のワールドでは「おためし」で少しだけ出す）
    var paidWorld: Int? {
        switch self {
        case .warp: 4
        case .moving: 5
        case .pad: 7
        case .block: 8
        default: nil
        }
    }
}

struct Area: Equatable, Sendable {
    let world: Int
    /// ワールドの中で 1 から
    let number: Int
    /// このエリアで出る仕掛け
    let gimmicks: [Gimmick]
    /// このエリアで、はじめて出てくる仕掛け（見出しに NEW を付け、1 ステージ目で説明する）
    let new: Gimmick?
    /// エリアの最後の 3 ステージだけに出す、お金で開くワールドの仕掛け
    let trial: Gimmick?

    static let size = 12
    /// おためしは、エリアの何ステージ目から（0 から数える）
    static let trialFrom = 9

    var firstIndex: Int { (number - 1) * Self.size }
    var title: String {
        if gimmicks.isEmpty { return String(localized: "きほん") }
        if gimmicks.count >= 3 { return String(localized: "ごちゃまぜ") }
        return gimmicks.map(\.label).joined(separator: " × ")
    }
    /// このステージ（ワールドの中の index）で出る仕掛け
    func gimmicks(atIndex index: Int) -> [Gimmick] {
        let p = index - firstIndex
        if let trial, p >= Self.trialFrom { return gimmicks + [trial] }
        return gimmicks
    }
    func isTrial(index: Int) -> Bool { trial != nil && index - firstIndex >= Self.trialFrom }
}

enum AreaBook {
    private static func a(_ w: Int, _ n: Int, _ g: [Gimmick], new: Gimmick? = nil, trial: Gimmick? = nil) -> Area {
        Area(world: w, number: n, gimmicks: g, new: new, trial: trial)
    }

    static let all: [Area] = [
        // ワールド 1（無料）：12 ステージごとに 1 つずつ新しい仕掛け
        a(1, 1, []),
        a(1, 2, [.bumper], new: .bumper),
        a(1, 3, [.eight, .bumper], new: .eight),
        a(1, 4, [.mud], new: .mud),
        a(1, 5, [.wall], new: .wall),
        a(1, 6, [.bouncy], new: .bouncy),
        a(1, 7, [.hole], new: .hole),
        a(1, 8, [.ordered], new: .ordered),
        a(1, 9, [.bumper, .mud, .wall]),
        a(1, 10, [.bumper, .hole, .bouncy], trial: .warp),
        // ワールド 2（無料）：いつもゴースト球
        a(2, 1, [.ghost], new: .ghost),
        a(2, 2, [.ghost, .bumper]),
        a(2, 3, [.ghost, .wall]),
        a(2, 4, [.ghost, .mud]),
        a(2, 5, [.ghost, .ordered]),
        a(2, 6, [.ghost, .hole]),
        a(2, 7, [.ghost, .bouncy]),
        a(2, 8, [.ghost, .eight]),
        a(2, 9, [.ghost, .bumper, .mud, .hole]),
        a(2, 10, [.ghost, .wall, .ordered], trial: .moving),
        // ワールド 3（無料）：いつもこおりとかべ
        a(3, 1, [.ice], new: .ice),
        a(3, 2, [.ice, .bumper]),
        a(3, 3, [.ice, .mud]),
        a(3, 4, [.ice, .hole]),
        a(3, 5, [.ice, .bouncy], trial: .pad),
        a(3, 6, [.ice, .ordered]),
        a(3, 7, [.ice, .ghost]),
        a(3, 8, [.ice, .eight]),
        a(3, 9, [.ice, .mud, .hole, .bumper]),
        a(3, 10, [.ice, .ghost, .bouncy], trial: .block),
        // ワールド 4（Pro）：いつもワープ
        a(4, 1, [.warp], new: .warp),
        a(4, 2, [.warp, .bumper]),
        a(4, 3, [.warp, .ghost]),
        a(4, 4, [.warp, .mud]),
        a(4, 5, [.warp, .hole]),
        a(4, 6, [.warp, .ordered]),
        a(4, 7, [.warp, .bouncy]),
        a(4, 8, [.warp, .eight]),
        a(4, 9, [.warp, .ice]),
        a(4, 10, [.warp, .ghost, .hole]),
        // ワールド 5（Pro）：いつもうごくバンパー
        a(5, 1, [.moving], new: .moving),
        a(5, 2, [.moving, .wall]),
        a(5, 3, [.moving, .ghost]),
        a(5, 4, [.moving, .mud]),
        a(5, 5, [.moving, .hole]),
        a(5, 6, [.moving, .ordered]),
        a(5, 7, [.moving, .bouncy]),
        a(5, 8, [.moving, .eight]),
        a(5, 9, [.moving, .ice]),
        a(5, 10, [.moving, .warp, .mud]),
        // ワールド 6（Pro）：ごちゃまぜ
        a(6, 1, [.ice, .warp, .ghost]),
        a(6, 2, [.moving, .hole]),
        a(6, 3, [.warp, .mud, .ordered]),
        a(6, 4, [.ice, .bouncy, .moving]),
        a(6, 5, [.ghost, .hole, .warp]),
        a(6, 6, [.ordered, .moving, .mud]),
        a(6, 7, [.eight, .warp, .bouncy]),
        a(6, 8, [.ice, .hole, .ghost]),
        a(6, 9, [.moving, .warp, .ordered]),
        a(6, 10, [.ghost, .mud, .hole, .bouncy]),
        // ワールド 7（ワールドパック）：いつもかそく床
        a(7, 1, [.pad], new: .pad),
        a(7, 2, [.pad, .wall]),
        a(7, 3, [.pad, .hole]),
        a(7, 4, [.pad, .mud]),
        a(7, 5, [.pad, .ordered, .bouncy]),
        // ワールド 8（ワールドパック）：いつもこわれるブロック
        a(8, 1, [.block], new: .block),
        a(8, 2, [.block, .pad]),
        a(8, 3, [.block, .hole]),
        a(8, 4, [.block, .mud]),
        a(8, 5, [.block, .ordered, .ghost]),
    ]

    static func areas(world: Int) -> [Area] { all.filter { $0.world == world } }

    static func area(world: Int, index: Int) -> Area? {
        all.first { $0.world == world && $0.number == index / Area.size + 1 }
    }
}
