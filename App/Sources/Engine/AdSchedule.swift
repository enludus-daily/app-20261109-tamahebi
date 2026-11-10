import Foundation

/// 全画面広告をいつ出すか（本人 2026-11-10：最初の 10 回は出さずに慣れてもらい、11 回目からは 5 回ごと）
enum AdSchedule {
    /// 広告なしで遊べる回数
    static let freePlays = 10
    /// そのあと、何回ごとに出すか
    static let every = 5

    /// plays 回目を遊び終えたとき、全画面広告を出すか（チュートリアルは数えない）
    static func shouldShowInterstitial(afterPlay plays: Int) -> Bool {
        plays > freePlays && (plays - freePlays) % every == 0
    }
}
