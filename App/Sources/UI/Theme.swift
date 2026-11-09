import SwiftUI

// 見た目の決まり（1 か所）。世界観：からし色のストライプのおもちゃ箱に、木の縁のビリヤード台。
// 線はすべてすもも色（ink）。黒は使わない。色は scripts/tone-check.py の「強い色」に当たらない範囲で選ぶ。
enum Theme {
    static let ink = Color(hex: 0x3A2340)
    static let inkSoft = Color(hex: 0x7A6470)
    static let sun = Color(hex: 0xFFD966)
    static let sunStripe = Color(hex: 0xFFE08A)
    static let cream = Color(hex: 0xFFF6E6)
    static let paper = Color(hex: 0xFFFDF8)
    static let mint = Color(hex: 0x6CCBA4)
    static let mintDeep = Color(hex: 0x3E9C78)
    static let wood = Color(hex: 0xB8692F)
    static let woodLight = Color(hex: 0xE0A672)
    static let bumper = Color(hex: 0xFFD966)
    static let disabled = Color(hex: 0xD9CCBC)

    static func felt(_ t: TableTheme) -> Color {
        switch t {
        case .blue: Color(hex: 0x3D7CC0)
        case .green: Color(hex: 0x3F9A73)
        case .plum: Color(hex: 0x8A5A8C)
        case .night: Color(hex: 0x2E3A66)
        }
    }

    static func ball(_ n: Int) -> Color {
        switch n {
        case 1: Color(hex: 0xF7D063)
        case 2: Color(hex: 0x3F6FC4)
        case 3: Color(hex: 0xC4554B)
        case 4: Color(hex: 0x8A63C4)
        case 5: Color(hex: 0xF2A65A)
        case 6: Color(hex: 0x4FA36E)
        case 7: Color(hex: 0xA0483F)
        default: Color(hex: 0x2B1F2E)
        }
    }

    static func rarity(_ r: Rarity) -> Color {
        switch r {
        case .common: Color(hex: 0xE9DFD0)
        case .rare: Color(hex: 0xA9D4F2)
        case .superRare: Color(hex: 0xF7D063)
        case .pro: Color(hex: 0xC3B1EE)
        case .pack: Color(hex: 0xF7C4DD)
        }
    }

    // 書体：丸ゴシックの太字で、数字は等幅
    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .black, design: .rounded) }
    static func label(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static func body(_ size: CGFloat) -> Font { .system(size: size, weight: .medium, design: .rounded) }

    static let line: CGFloat = 3
    static let radiusCard: CGFloat = 28
    static let radiusButton: CGFloat = 18
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

/// からし色のストライプの地
struct StripeBackground: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.sun))
            let w: CGFloat = 16
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var p = Path()
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x + w, y: 0))
                p.addLine(to: CGPoint(x: x + w + size.height, y: size.height))
                p.addLine(to: CGPoint(x: x + size.height, y: size.height))
                p.closeSubpath()
                ctx.fill(p, with: .color(Theme.sunStripe))
                x += w * 2
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// 太い縁と下に落ちる影の、押すと沈むボタン
struct ChunkyButtonStyle: ButtonStyle {
    var fill: Color = Theme.cream
    var text: Color = Theme.ink
    var height: CGFloat = 54

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(Theme.label(18))
            .foregroundStyle(text)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(RoundedRectangle(cornerRadius: Theme.radiusButton).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusButton).stroke(Theme.ink, lineWidth: Theme.line))
            .background(RoundedRectangle(cornerRadius: Theme.radiusButton).fill(Theme.ink).offset(y: pressed ? 0 : 5))
            .offset(y: pressed ? 5 : 0)
            .animation(.spring(response: 0.18, dampingFraction: 0.6), value: pressed)
    }
}

/// クリーム色の札（タイトル・結果・ダイアログの台紙）
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 20)
            .padding(.vertical, 22)
            .background(RoundedRectangle(cornerRadius: Theme.radiusCard).fill(Theme.cream))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusCard).stroke(Theme.ink, lineWidth: 4))
            .background(RoundedRectangle(cornerRadius: Theme.radiusCard).fill(Theme.ink).offset(y: 6))
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }

    /// 縁取りの文字（ロゴ・ポップアップ）
    func outlined(_ color: Color = Theme.ink, width: CGFloat = 2) -> some View {
        self
            .shadow(color: color, radius: 0, x: width, y: 0)
            .shadow(color: color, radius: 0, x: -width, y: 0)
            .shadow(color: color, radius: 0, x: 0, y: width)
            .shadow(color: color, radius: 0, x: 0, y: -width)
    }
}

/// HUD の丸い札
struct Pill<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        HStack(spacing: 6) { content }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(Capsule().fill(Theme.cream))
            .overlay(Capsule().stroke(Theme.ink, lineWidth: Theme.line))
            .background(Capsule().fill(Theme.ink).offset(y: 3))
    }
}

/// おやつ（ゲーム内ポイント）の小さな絵：クッキー
struct SnackIcon: View {
    var size: CGFloat = 18
    var body: some View {
        Canvas { ctx, s in
            let r = CGRect(origin: .zero, size: s).insetBy(dx: 1.5, dy: 1.5)
            ctx.fill(Path(ellipseIn: r), with: .color(Color(hex: 0xE8B57A)))
            ctx.stroke(Path(ellipseIn: r), with: .color(Theme.ink), lineWidth: 2)
            for (x, y) in [(0.35, 0.35), (0.62, 0.42), (0.45, 0.66), (0.7, 0.68)] {
                ctx.fill(Path(ellipseIn: CGRect(x: s.width * x - 1.6, y: s.height * y - 1.6, width: 3.2, height: 3.2)), with: .color(Theme.ink))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
