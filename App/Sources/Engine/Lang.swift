import Foundation

// 画面の文字は App/Resources/Localizable.xcstrings（日本語がキー、英語が訳）。
// 文の中に差しこむ値は、型によってキーの形（%lld・%@）が変わらないよう、L.s で文字にしてから入れる（キーはいつも %@）。
enum L {
    /// 差しこむ値を文字にする
    static func s<T>(_ value: T) -> String { "\(value)" }
    /// 「70%」のような値（% は書式の記号なので、文の側には書かない）
    static func pct<T>(_ value: T) -> String { "\(value)%" }
    /// データ（stages.json のヒントなど）の文を、カタログで訳す
    static func data(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: key, table: nil)
    }
}
