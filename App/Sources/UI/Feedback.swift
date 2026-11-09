import UIKit

// 手応えの振動（README の「手応えの表」と対応）。音は v1 では入れない。
@MainActor
enum Feedback {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let notice = UINotificationFeedbackGenerator()
    private static let selection = UISelectionFeedbackGenerator()

    static func prepare() { light.prepare(); rigid.prepare(); soft.prepare() }

    /// 引いている間、強さの目盛りをまたぐたびに
    static func aimTick() { selection.selectionChanged() }
    static func shot(power: Double) { medium.impactOccurred(intensity: 0.4 + power * 0.6) }
    static func rail(speed: Double) { light.impactOccurred(intensity: min(1, 0.2 + speed / 1200)) }
    static func bumper() { rigid.impactOccurred(intensity: 0.9) }
    static func body() { soft.impactOccurred(intensity: 0.8) }
    static func eat(combo: Int) { rigid.impactOccurred(intensity: min(1, 0.5 + Double(combo) * 0.15)) }
    static func bonus() { notice.notificationOccurred(.success) }
    static func miss() { soft.impactOccurred(intensity: 0.3) }
    static func finished() { notice.notificationOccurred(.success) }
    static func tap() { light.impactOccurred(intensity: 0.5) }
    static func reveal(_ r: Rarity) {
        switch r {
        case .superRare, .pro, .pack: notice.notificationOccurred(.success)
        case .rare: rigid.impactOccurred()
        case .common: medium.impactOccurred()
        }
    }
}
