import SwiftUI

// なかまの絵（Canvas に描く）。頭はビリヤードの球のように丸く、おでこに白い丸と印がある。
enum Face: Equatable, Sendable {
    case idle, aim, zoom, roll, happy, bonk, oops, sad, full, sleep
}

enum CharacterArt {
    static let ink = Theme.ink

    static func circle(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    static func ellipse(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2))
    }

    static func arc(_ c: CGPoint, _ r: CGFloat, from a: Double, to b: Double) -> Path {
        var p = Path()
        p.addArc(center: c, radius: r, startAngle: .degrees(a), endAngle: .degrees(b), clockwise: false)
        return p
    }

    // MARK: 頭

    /// dir はまなざしの向き（長さ 1 くらい）。t は秒（まばたきなど）。power は狙いの強さ 0〜1
    static func drawHead(_ ctx: inout GraphicsContext, at center: CGPoint, radius r: CGFloat, character ch: Character,
                         face: Face, look dir: CGVector = .init(dx: 0, dy: 0.3), t: Double, power: Double = 0) {
        var g = ctx
        g.translateBy(x: center.x, y: center.y)
        let squish: CGFloat = face == .bonk ? 0.12 : (face == .happy ? -0.06 : 0)
        g.scaleBy(x: 1 + squish, y: 1 - squish)
        let o = CGPoint.zero
        let lw = r * 0.2
        let body = Color(hex: ch.body), shade = Color(hex: ch.shade), belly = Color(hex: ch.belly)

        g.fill(circle(o, r), with: .color(body))
        // 下半分の影
        var shadePath = Path()
        shadePath.addArc(center: CGPoint(x: r * 0.12, y: r * 0.18), radius: r * 0.84, startAngle: .degrees(15), endAngle: .degrees(150), clockwise: false)
        shadePath.addArc(center: o, radius: r * 0.94, startAngle: .degrees(150), endAngle: .degrees(15), clockwise: true)
        g.fill(shadePath, with: .color(shade.opacity(0.55)))
        g.stroke(circle(o, r), with: .color(ink), lineWidth: lw)

        // おでこの白い丸と印
        let spotC = CGPoint(x: 0, y: -r * 0.58)
        g.fill(circle(spotC, r * 0.3), with: .color(Color(hex: 0xFFFDF8)))
        drawMark(&g, ch.mark, at: spotC, size: r * 0.19, color: shade, t: t)

        // 口もと
        g.fill(ellipse(CGPoint(x: 0, y: r * 0.42), r * 0.52, r * 0.36), with: .color(belly))
        // ほっぺ
        let blush = Color(hex: 0xFFA9B8).opacity(0.85)
        g.fill(ellipse(CGPoint(x: -r * 0.66, y: r * 0.22), r * 0.16, r * 0.1), with: .color(blush))
        g.fill(ellipse(CGPoint(x: r * 0.66, y: r * 0.22), r * 0.16, r * 0.1), with: .color(blush))

        // 目
        let ex = r * 0.36, ey = -r * 0.06
        let lx = dir.dx * r * 0.09, ly = dir.dy * r * 0.07
        let eyeStyle = StrokeStyle(lineWidth: r * 0.15, lineCap: .round, lineJoin: .round)
        let browStyle = StrokeStyle(lineWidth: r * 0.1, lineCap: .round)
        let blink = (face == .idle || face == .aim) && t.truncatingRemainder(dividingBy: 3.4) < 0.12
        for s in [-1.0, 1.0] {
            let c = CGPoint(x: s * ex, y: ey)
            switch face {
            case .happy, .full:
                g.stroke(arc(CGPoint(x: c.x, y: c.y + r * 0.06), r * 0.14, from: 198, to: 342), with: .color(ink), style: eyeStyle)
            case .sleep:
                g.stroke(arc(CGPoint(x: c.x, y: c.y - r * 0.04), r * 0.13, from: 20, to: 160), with: .color(ink), style: eyeStyle)
            case .zoom:
                var p = Path()
                p.move(to: CGPoint(x: c.x - s * r * 0.14, y: c.y - r * 0.12))
                p.addLine(to: CGPoint(x: c.x + s * r * 0.08, y: c.y))
                p.addLine(to: CGPoint(x: c.x - s * r * 0.14, y: c.y + r * 0.12))
                g.stroke(p, with: .color(ink), style: eyeStyle)
            case .bonk:
                g.stroke(arc(c, r * 0.15, from: 0, to: 300), with: .color(ink), style: StrokeStyle(lineWidth: r * 0.1, lineCap: .round))
                g.fill(circle(c, r * 0.05), with: .color(ink))
            default:
                if blink {
                    var p = Path()
                    p.move(to: CGPoint(x: c.x - r * 0.14, y: c.y))
                    p.addLine(to: CGPoint(x: c.x + r * 0.14, y: c.y))
                    g.stroke(p, with: .color(ink), style: eyeStyle)
                } else {
                    g.fill(ellipse(CGPoint(x: c.x + lx, y: c.y + ly), r * 0.15, r * 0.2), with: .color(ink))
                    g.fill(circle(CGPoint(x: c.x + lx - r * 0.05, y: c.y + ly - r * 0.08), r * 0.06), with: .color(.white))
                }
                if face == .sad || face == .oops {
                    var p = Path()
                    p.move(to: CGPoint(x: c.x - s * r * 0.2, y: c.y - r * 0.32))
                    p.addLine(to: CGPoint(x: c.x + s * r * 0.08, y: c.y - r * 0.4))
                    g.stroke(p, with: .color(ink), style: browStyle)
                }
                if face == .aim && power > 0.55 {
                    var p = Path()
                    p.move(to: CGPoint(x: c.x + s * r * 0.22, y: c.y - r * 0.32))
                    p.addLine(to: CGPoint(x: c.x - s * r * 0.08, y: c.y - r * 0.24))
                    g.stroke(p, with: .color(ink), style: browStyle)
                }
            }
        }

        // 口
        let mouth = StrokeStyle(lineWidth: r * 0.11, lineCap: .round, lineJoin: .round)
        switch face {
        case .happy, .full:
            var p = Path()
            p.addArc(center: CGPoint(x: 0, y: r * 0.36), radius: r * 0.18, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
            p.closeSubpath()
            g.fill(p, with: .color(ink))
            var tongue = Path()
            tongue.addArc(center: CGPoint(x: 0, y: r * 0.47), radius: r * 0.08, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
            g.fill(tongue, with: .color(Color(hex: 0xFF9A9A)))
        case .zoom, .bonk:
            g.fill(ellipse(CGPoint(x: 0, y: r * 0.42), r * 0.09, r * 0.12), with: .color(ink))
        case .sad, .oops:
            g.stroke(arc(CGPoint(x: 0, y: r * 0.54), r * 0.13, from: 207, to: 333), with: .color(ink), style: mouth)
        case .sleep:
            g.fill(ellipse(CGPoint(x: 0, y: r * 0.42), r * 0.06, r * 0.07), with: .color(ink))
        default:
            var p = Path()
            p.move(to: CGPoint(x: -r * 0.16, y: r * 0.36))
            p.addQuadCurve(to: CGPoint(x: 0, y: r * 0.36), control: CGPoint(x: -r * 0.08, y: r * 0.47))
            p.addQuadCurve(to: CGPoint(x: r * 0.16, y: r * 0.36), control: CGPoint(x: r * 0.08, y: r * 0.47))
            g.stroke(p, with: .color(ink), style: mouth)
            if face == .idle && t.truncatingRemainder(dividingBy: 5) > 4.4 {
                var tg = Path()
                tg.move(to: CGPoint(x: 0, y: r * 0.44))
                tg.addLine(to: CGPoint(x: 0, y: r * 0.66))
                tg.addLine(to: CGPoint(x: -r * 0.07, y: r * 0.74))
                tg.move(to: CGPoint(x: 0, y: r * 0.66))
                tg.addLine(to: CGPoint(x: r * 0.07, y: r * 0.74))
                g.stroke(tg, with: .color(Color(hex: 0xE07A70)), style: StrokeStyle(lineWidth: r * 0.09, lineCap: .round))
            }
        }
    }

    // MARK: 印

    static func star(_ c: CGPoint, outer: CGFloat, inner: CGFloat, points n: Int = 5) -> Path {
        var p = Path()
        for i in 0..<(n * 2) {
            let a = -Double.pi / 2 + Double(i) * .pi / Double(n)
            let rr = i % 2 == 0 ? outer : inner
            let pt = CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    static func drawMark(_ g: inout GraphicsContext, _ m: Mark, at c: CGPoint, size s: CGFloat, color: Color, t: Double) {
        let fill = GraphicsContext.Shading.color(color)
        switch m {
        case .star: g.fill(star(c, outer: s, inner: s * 0.42), with: fill)
        case .galaxy:
            g.fill(star(c, outer: s, inner: s * 0.35, points: 4), with: fill)
            g.fill(circle(CGPoint(x: c.x + s * 0.8, y: c.y - s * 0.6), s * 0.18), with: fill)
        case .heart:
            var p = Path()
            p.move(to: CGPoint(x: c.x, y: c.y + s * 0.8))
            p.addCurve(to: CGPoint(x: c.x, y: c.y - s * 0.3), control1: CGPoint(x: c.x - s * 1.3, y: c.y), control2: CGPoint(x: c.x - s * 0.6, y: c.y - s * 1.1))
            p.addCurve(to: CGPoint(x: c.x, y: c.y + s * 0.8), control1: CGPoint(x: c.x + s * 0.6, y: c.y - s * 1.1), control2: CGPoint(x: c.x + s * 1.3, y: c.y))
            g.fill(p, with: fill)
        case .leaf, .drop, .flame:
            var p = Path()
            p.move(to: CGPoint(x: c.x, y: c.y - s))
            p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + s), control: CGPoint(x: c.x + s * 1.2, y: c.y + s * 0.2))
            p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - s), control: CGPoint(x: c.x - s * 1.2, y: c.y + s * 0.2))
            g.fill(p, with: fill)
        case .sun:
            g.fill(circle(c, s * 0.55), with: fill)
            for i in 0..<8 {
                let a = Double(i) * .pi / 4
                var p = Path()
                p.move(to: CGPoint(x: c.x + cos(a) * s * 0.75, y: c.y + sin(a) * s * 0.75))
                p.addLine(to: CGPoint(x: c.x + cos(a) * s * 1.05, y: c.y + sin(a) * s * 1.05))
                g.stroke(p, with: fill, style: StrokeStyle(lineWidth: s * 0.2, lineCap: .round))
            }
        case .note:
            g.fill(ellipse(CGPoint(x: c.x - s * 0.25, y: c.y + s * 0.5), s * 0.42, s * 0.32), with: fill)
            var p = Path()
            p.move(to: CGPoint(x: c.x + s * 0.12, y: c.y + s * 0.5))
            p.addLine(to: CGPoint(x: c.x + s * 0.12, y: c.y - s * 0.9))
            p.addLine(to: CGPoint(x: c.x + s * 0.7, y: c.y - s * 0.6))
            g.stroke(p, with: fill, style: StrokeStyle(lineWidth: s * 0.24, lineCap: .round, lineJoin: .round))
        case .eight:
            g.draw(Text("8").font(.system(size: s * 1.8, weight: .black, design: .rounded)).foregroundStyle(color), at: c)
        case .flower, .blossom:
            for i in 0..<5 {
                let a = Double(i) * 2 * .pi / 5 - .pi / 2
                g.fill(circle(CGPoint(x: c.x + cos(a) * s * 0.55, y: c.y + sin(a) * s * 0.55), s * 0.42), with: fill)
            }
            g.fill(circle(c, s * 0.3), with: .color(Color(hex: 0xFFE08A)))
        case .snow:
            for i in 0..<3 {
                let a = Double(i) * .pi / 3
                var p = Path()
                p.move(to: CGPoint(x: c.x - cos(a) * s, y: c.y - sin(a) * s))
                p.addLine(to: CGPoint(x: c.x + cos(a) * s, y: c.y + sin(a) * s))
                g.stroke(p, with: fill, style: StrokeStyle(lineWidth: s * 0.22, lineCap: .round))
            }
        case .moon:
            var p = Path()
            p.addArc(center: c, radius: s, startAngle: .degrees(60), endAngle: .degrees(300), clockwise: false)
            p.addArc(center: CGPoint(x: c.x + s * 0.45, y: c.y), radius: s * 0.72, startAngle: .degrees(270), endAngle: .degrees(90), clockwise: true)
            p.closeSubpath()
            g.fill(p, with: fill)
        case .crown:
            var p = Path()
            p.move(to: CGPoint(x: c.x - s, y: c.y + s * 0.6))
            p.addLine(to: CGPoint(x: c.x - s, y: c.y - s * 0.5))
            p.addLine(to: CGPoint(x: c.x - s * 0.45, y: c.y))
            p.addLine(to: CGPoint(x: c.x, y: c.y - s * 0.8))
            p.addLine(to: CGPoint(x: c.x + s * 0.45, y: c.y))
            p.addLine(to: CGPoint(x: c.x + s, y: c.y - s * 0.5))
            p.addLine(to: CGPoint(x: c.x + s, y: c.y + s * 0.6))
            p.closeSubpath()
            g.fill(p, with: fill)
        case .bolt:
            var p = Path()
            p.move(to: CGPoint(x: c.x + s * 0.2, y: c.y - s))
            p.addLine(to: CGPoint(x: c.x - s * 0.6, y: c.y + s * 0.15))
            p.addLine(to: CGPoint(x: c.x, y: c.y + s * 0.15))
            p.addLine(to: CGPoint(x: c.x - s * 0.2, y: c.y + s))
            p.addLine(to: CGPoint(x: c.x + s * 0.6, y: c.y - s * 0.15))
            p.addLine(to: CGPoint(x: c.x, y: c.y - s * 0.15))
            p.closeSubpath()
            g.fill(p, with: fill)
        }
    }

    // MARK: 胴体

    /// 尻尾から頭へ並んだ点を、縁取り・地の色・つやの3重の線で描く
    static func drawBody(_ ctx: inout GraphicsContext, points p: [CGPoint], width w: CGFloat, character ch: Character, shadowOffset: CGSize = CGSize(width: 2, height: 4)) {
        guard p.count >= 2 else { return }
        let body = Color(hex: ch.body), light = Color(hex: ch.belly), spot = Color(hex: ch.spot)
        func path(from start: Int, dx: CGFloat = 0, dy: CGFloat = 0) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: p[start].x + dx, y: p[start].y + dy))
            for i in (start + 1)..<p.count { path.addLine(to: CGPoint(x: p[i].x + dx, y: p[i].y + dy)) }
            return path
        }
        let round = { (lw: CGFloat) in StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round) }
        ctx.stroke(path(from: 0, dx: shadowOffset.width, dy: shadowOffset.height), with: .color(Color(hex: 0x0A1446).opacity(0.22)), style: round(w))
        // 細くなる尻尾の先
        let tail = min(p.count - 1, 8)
        for layer in 0..<2 {
            for i in 1...tail {
                let tw = w * CGFloat(i) / CGFloat(tail) * 0.8 + 3
                var seg = Path()
                seg.move(to: p[i - 1]); seg.addLine(to: p[i])
                ctx.stroke(seg, with: .color(layer == 0 ? ink : body), style: round(layer == 0 ? tw + 3.5 : tw))
            }
        }
        guard tail < p.count - 1 else { return }
        ctx.stroke(path(from: tail), with: .color(ink), style: round(w + 3.5))
        ctx.stroke(path(from: tail), with: .color(body), style: round(w))
        ctx.stroke(path(from: tail, dx: -1.5, dy: -2), with: .color(light.opacity(0.45)), style: round(w * 0.35))
        // 模様の点（胴体に付いて動く）
        var acc: CGFloat = 0
        for i in (tail + 1)..<max(tail + 1, p.count - 4) {
            let d = hypot(p[i].x - p[i - 1].x, p[i].y - p[i - 1].y)
            acc += d
            if acc.truncatingRemainder(dividingBy: 18) < d {
                ctx.fill(circle(p[i], w * 0.14), with: .color(spot))
            }
        }
    }
}

/// 一覧・カプセル・タイトルで使う、動くなかまの絵
struct CharacterPortrait: View {
    let character: Character
    var face: Face = .idle
    var showBody = true
    var silhouette = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let s = min(size.width / 300, size.height / 240)
                ctx.scaleBy(x: s, y: s)
                if silhouette { ctx.addFilter(.colorMultiply(Theme.ink.opacity(0.9))) }
                let bob = sin(t * 4) * 4
                ctx.fill(CharacterArt.ellipse(CGPoint(x: 160, y: 216), 115, 12), with: .color(Theme.ink.opacity(0.12)))
                if showBody {
                    let pts = (0...40).map { i -> CGPoint in
                        let u = Double(i) / 40
                        return CGPoint(x: 30 + u * 160, y: 196 - sin(u * .pi * 1.6 + t * 2) * 16 * u - u * 50)
                    }
                    CharacterArt.drawBody(&ctx, points: pts, width: 24, character: character, shadowOffset: .zero)
                }
                let center = showBody ? CGPoint(x: 200, y: 100 + bob) : CGPoint(x: 150, y: 116 + bob)
                CharacterArt.drawHead(&ctx, at: center, radius: showBody ? 52 : 70, character: character, face: face,
                                      look: CGVector(dx: 0.6, dy: 0.5), t: t)
            }
        }
        .accessibilityLabel(silhouette ? String(localized: "まだ会っていないなかま") : character.name)
    }
}
