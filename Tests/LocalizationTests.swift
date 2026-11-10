import Foundation
import Testing
@testable import Tamahebi

/// 英語のカタログに抜けがないこと（ビルドされたアプリの en.lproj を読む）
struct LocalizationTests {
    static let japanese = try! NSRegularExpression(pattern: "[\\u3040-\\u30ff\\u4e00-\\u9fff]")

    static func table(_ lang: String) -> [String: String]? {
        guard let path = Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: lang) else { return nil }
        return NSDictionary(contentsOfFile: path) as? [String: String]
    }

    static func hasJapanese(_ s: String) -> Bool {
        japanese.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
    }

    @Test func theAppShipsEnglishAndJapanese() {
        #expect(Bundle.main.localizations.contains("en"))
        #expect(Bundle.main.localizations.contains("ja"))
    }

    @Test func everyEnglishStringIsTranslated() throws {
        let en = try #require(Self.table("en"), "en.lproj/Localizable.strings がない")
        #expect(en.count >= 250)
        let untranslated = en.filter { Self.hasJapanese($0.value) }.map(\.key)
        #expect(untranslated.isEmpty, "英語に日本語が残っている: \(untranslated.prefix(10))")
    }

    @Test func japaneseAndEnglishHaveTheSameKeys() throws {
        let en = try #require(Self.table("en")), ja = try #require(Self.table("ja"))
        #expect(Set(en.keys) == Set(ja.keys))
    }

    @Test func everyFriendAndWorldHasAnEnglishName() throws {
        let en = try #require(Self.table("en"))
        for key in ["タマ", "ギンガ", "マッチャ", "ビリヤード場", "こわれるブロック", "ぜんぶ食べよう", "8 番球を食べよう"] {
            let value = try #require(en[key], "\(key) の英語がない")
            #expect(!Self.hasJapanese(value))
        }
    }

    @Test func everyStageHintHasEnglish() throws {
        let en = try #require(Self.table("en"))
        let url = try #require(Bundle.main.url(forResource: "stages", withExtension: "json"))
        let hints = Set(try StageBook.decode(Data(contentsOf: url)).compactMap(\.hint))
        let missing = hints.filter { en[$0] == nil }
        #expect(missing.isEmpty, "ヒントの英語がない: \(missing)")
    }

    @Test func placeholdersMatchBetweenLanguages() throws {
        let en = try #require(Self.table("en"))
        for (key, value) in en {
            let keyCount = key.components(separatedBy: "%@").count - 1
            let positional = (1...9).filter { value.contains("%\($0)$@") }.count
            let plain = value.components(separatedBy: "%@").count - 1
            #expect(keyCount == max(positional, plain), "差しこむ値の数が違う: \(key) → \(value)")
        }
    }
}
