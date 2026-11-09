import SwiftUI

/// プレイ画面：上に HUD、残りは台。台は 360 × 560 の点を、縁（pad）ごと画面に合わせて拡大する
struct GameView: View {
    @Environment(AppModel.self) private var app
    @Bindable var game: GameModel
    @State private var showIntro = true
    @State private var showHint = false

    static let pad: CGFloat = 22

    var body: some View {
        VStack(spacing: 10) {
            hud
            if let s = game.mode.stage { goalBar(s) }
            GeometryReader { geo in
                let w = game.engine.rules.width + Self.pad * 2, h = game.engine.rules.height + Self.pad * 2
                let scale = min(geo.size.width / w, geo.size.height / h)
                ZStack {
                    TimelineView(.animation) { tl in
                        TableCanvas(game: game, date: tl.date)
                            .onChange(of: tl.date) { _, d in game.tick(d) }
                    }
                    .frame(width: w * scale, height: h * scale)
                    .gesture(drag(scale: scale))
                    .accessibilityLabel("台。ひっぱって離すと、\(game.character.name)が転がります")
                    if let s = game.mode.stage, showIntro, game.engine.shotsTaken == 0, let hint = s.hint {
                        IntroCard(stage: s, hint: hint) { withAnimation { showIntro = false } }
                            .padding(24)
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }
                    if let r = game.summary {
                        ResultCard(game: game, summary: r)
                            .padding(12)
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: game.summary != nil)
        .sheet(isPresented: $showHint) {
            if let s = game.mode.stage {
                HintSheet(stage: s) { showHint = false }
                    .presentationDetents([.medium])
                    .presentationBackground(Theme.cream)
            }
        }
        .onAppear {
            game.onFinish = { g in
                let r = app.finish(g)
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(700))
                    g.setSummary(r)
                    app.maybeShowProAfterGame(g)
                }
            }
        }
    }

    private func drag(scale: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                if showIntro, game.mode.stage?.hint != nil, game.engine.shotsTaken == 0 { withAnimation { showIntro = false } }
                let p = CGPoint(x: v.location.x / scale - Self.pad, y: v.location.y / scale - Self.pad)
                if game.isAiming { game.moveAim(to: p) } else { game.beginAim(at: p) }
            }
            .onEnded { _ in game.endAim() }
    }

    private func goalBar(_ s: Stage) -> some View {
        HStack(spacing: 8) {
            Text(s.id).font(Theme.title(15)).foregroundStyle(Theme.cream)
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(Capsule().fill(Theme.ink))
            Text(s.goal.label).font(Theme.label(14)).foregroundStyle(Theme.ink)
            Spacer(minLength: 4)
            if let g = game.goalText {
                Text(g).font(Theme.label(13)).monospacedDigit().foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
            }
            Text("★3: \(s.par3)打").font(Theme.body(12)).foregroundStyle(Theme.inkSoft)
            if game.hintMode {
                if game.offPath {
                    Button("おてほんからやりなおす") { app.replay() }
                        .font(Theme.label(12)).foregroundStyle(Theme.ink)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(Color(hex: 0xF7A9C4)))
                } else {
                    Label("おてほん", systemImage: "lightbulb.fill").font(Theme.label(12)).foregroundStyle(Theme.ink)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(Color(hex: 0xF7A9C4).opacity(0.6)))
                }
            } else {
                Button { showHint = true } label: {
                    Image(systemName: "lightbulb.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Theme.sun))
                        .overlay(Circle().stroke(Theme.ink, lineWidth: 2))
                }
                .accessibilityLabel("ヒント")
            }
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }

    private var hud: some View {
        HStack(spacing: 8) {
            Pill {
                let total = max(game.engine.shotsLeft + game.engine.shotsTaken, game.engine.shotsLeft)
                HStack(spacing: 3) {
                    ForEach(0..<min(total, 14), id: \.self) { i in
                        let left = i < game.engine.shotsLeft
                        Circle()
                            .fill(left ? Color(hex: game.character.body) : .clear)
                            .overlay(Circle().stroke(left ? Theme.ink : Theme.disabled, lineWidth: 2))
                            .frame(width: 12, height: 12)
                            .scaleEffect(left ? 1 : 0.7)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: game.engine.shotsLeft)
                Spacer(minLength: 0)
            }
            .accessibilityElement()
            .accessibilityLabel("のこり \(game.engine.shotsLeft) ショット")
            Pill {
                Text("★").font(Theme.label(14)).foregroundStyle(Color(hex: 0xE07A70))
                Text("\(game.engine.score)")
                    .font(Theme.title(20)).monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy, value: game.engine.score)
            }
            .accessibilityElement(children: .combine)
            Button { app.leaveGame() } label: {
                Image(systemName: game.mode.stage == nil ? "house.fill" : "square.grid.3x3.fill").font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Theme.cream))
                    .overlay(Circle().stroke(Theme.ink, lineWidth: Theme.line))
                    .background(Circle().fill(Theme.ink).offset(y: 3))
            }
            .accessibilityLabel(game.mode.stage == nil ? "ホームへ" : "ステージの一覧へ")
        }
    }
}

/// ステージのはじめに出す、おだいと新しい仕掛けの説明
struct IntroCard: View {
    let stage: Stage
    let hint: String
    let close: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text("\(stage.id)  \(StageBook.world(stage.world).name)").font(Theme.label(13)).foregroundStyle(Theme.inkSoft)
            Text(stage.goal.label).font(Theme.title(24)).foregroundStyle(Theme.ink)
            Text(hint).font(Theme.body(15)).foregroundStyle(Theme.ink).multilineTextAlignment(.center)
            Button("わかった", action: close).buttonStyle(ChunkyButtonStyle(fill: Theme.mint, text: .white))
        }
        .frame(maxWidth: 300)
        .card()
    }
}

/// 台・バンパー・球・ヘビ・狙いの線・飛び出す文字を 1 枚に描く
struct TableCanvas: View {
    let game: GameModel
    /// 毎フレーム変わる値を渡して、描き直させる
    let date: Date

    var body: some View {
        Canvas { ctx, size in
            let pad = GameView.pad
            let rules = game.engine.rules
            let full = CGSize(width: rules.width + pad * 2, height: rules.height + pad * 2)
            let s = size.width / full.width
            ctx.scaleBy(x: s, y: s)
            drawFrame(&ctx, full: full, pad: pad)
            ctx.translateBy(x: pad, y: pad)
            drawFelt(&ctx, rules: rules)
            drawWarps(&ctx)
            drawWalls(&ctx)
            drawBumpers(&ctx)
            drawBalls(&ctx)
            let aim = game.aim
            if let h = game.hintShot, let hp = game.hintPreview { drawHint(&ctx, shot: h, preview: hp) }
            if let a = aim, let pv = game.preview { drawGuide(&ctx, preview: pv, aim: a) }
            drawSnake(&ctx, aim: aim)
            drawSparks(&ctx)
            drawPops(&ctx)
            if let a = aim { drawGauge(&ctx, power: a.power, rules: rules) }
            if let h = game.hintShot, aim != nil { drawGaugeTarget(&ctx, power: h.power, rules: rules) }
            if game.engine.shotsTaken == 0, !game.isAiming, !game.engine.isMoving { drawHint(&ctx) }
        }
    }

    private func rounded(_ r: CGRect, _ c: CGFloat) -> Path { Path(roundedRect: r, cornerRadius: c) }

    private func drawFrame(_ ctx: inout GraphicsContext, full: CGSize, pad: CGFloat) {
        ctx.fill(rounded(CGRect(origin: .zero, size: full), 22), with: .color(Theme.ink))
        ctx.fill(rounded(CGRect(x: 3, y: 3, width: full.width - 6, height: full.height - 6), 19), with: .color(Theme.wood))
        ctx.fill(rounded(CGRect(x: 6, y: 5, width: full.width - 12, height: 8), 4), with: .color(Theme.woodLight.opacity(0.7)))
        let w = full.width - pad * 2, h = full.height - pad * 2
        // 縁の目印（ダイヤモンド）。ビリヤード台の照準の点
        for i in 1..<4 {
            for y in [pad / 2 + 1, full.height - pad / 2] {
                ctx.fill(CharacterArt.circle(CGPoint(x: pad + w * CGFloat(i) / 4, y: y), 2.6), with: .color(Theme.cream))
            }
        }
        for i in 1..<8 where i != 4 {
            for x in [pad / 2 + 1, full.width - pad / 2 - 1] {
                ctx.fill(CharacterArt.circle(CGPoint(x: x, y: pad + h * CGFloat(i) / 8), 2.6), with: .color(Theme.cream))
            }
        }
    }

    private func drawFelt(_ ctx: inout GraphicsContext, rules: Rules) {
        let r = CGRect(x: 0, y: 0, width: rules.width, height: rules.height)
        let shape = rounded(r, 8)
        let felt = game.mode.stage.map { Color(hex: StageBook.world($0.world).felt) } ?? Theme.felt(game.table)
        ctx.fill(shape, with: .color(felt))
        if game.engine.isIce {
            // こおり：白い斜めのつや
            for i in stride(from: -560.0, to: 360, by: 70) {
                var p = Path()
                p.move(to: CGPoint(x: i, y: rules.height)); p.addLine(to: CGPoint(x: i + rules.height, y: 0))
                ctx.stroke(p, with: .color(.white.opacity(0.13)), lineWidth: 14)
            }
        }
        ctx.fill(shape, with: .radialGradient(Gradient(colors: [.white.opacity(0.16), .black.opacity(0.12)]),
                                             center: CGPoint(x: r.midX, y: r.height * 0.45), startRadius: 30, endRadius: r.height * 0.7))
        var line = Path()
        line.move(to: CGPoint(x: 10, y: rules.height * 0.75))
        line.addLine(to: CGPoint(x: rules.width - 10, y: rules.height * 0.75))
        ctx.stroke(line, with: .color(.white.opacity(0.18)), style: StrokeStyle(lineWidth: 2, dash: [4, 6]))
        ctx.stroke(shape, with: .color(Theme.ink), lineWidth: 3)
    }

    private func drawBumpers(_ ctx: inout GraphicsContext) {
        for b in game.engine.bumpers {
            let cv = b.center(at: game.engine.time)
            let c = CGPoint(x: cv.x, y: cv.y)
            if b.amplitude > 0 {
                var rail = Path()
                let a = b.base + b.axis * b.amplitude, z = b.base - b.axis * b.amplitude
                rail.move(to: CGPoint(x: a.x, y: a.y)); rail.addLine(to: CGPoint(x: z.x, y: z.y))
                ctx.stroke(rail, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [2, 7]))
            }
            let r = b.radius * (1 + b.squash * 0.18)
            ctx.fill(CharacterArt.circle(CGPoint(x: c.x + 2, y: c.y + 5), b.radius), with: .color(Color(hex: 0x0A1446).opacity(0.22)))
            ctx.fill(CharacterArt.circle(c, r), with: .color(Theme.bumper))
            ctx.stroke(CharacterArt.circle(c, r), with: .color(Theme.ink), lineWidth: 3)
            ctx.fill(CharacterArt.circle(c, r * 0.55), with: .color(b.squash > 0 ? .white : Color(hex: game.character.body)))
            ctx.stroke(CharacterArt.circle(c, r * 0.55), with: .color(Theme.ink), lineWidth: 2.5)
            ctx.fill(CharacterArt.ellipse(CGPoint(x: c.x - r * 0.45, y: c.y - r * 0.5), r * 0.22, r * 0.12), with: .color(.white.opacity(0.7)))
        }
    }

    private func drawBalls(_ ctx: inout GraphicsContext) {
        for b in game.engine.balls {
            let age = game.engine.clock - b.born
            let s = age < 0.3 ? Self.easeOutBack(age / 0.3) : 1
            let bob = abs(sin(game.clock * 2.2 + b.phase)) * 2
            if b.kind == .ghost {
                let awake = game.engine.ghostsAwake
                var g = ctx
                g.opacity = awake ? 0.95 : 0.4
                Self.drawBall(&g, at: CGPoint(x: b.center.x, y: b.center.y), number: b.number, radius: 10, scale: max(0.01, s), lift: bob)
                let ring = CharacterArt.circle(CGPoint(x: b.center.x, y: b.center.y - bob), 15 + (awake ? sin(game.clock * 10) * 2 : 0))
                ctx.stroke(ring, with: .color(awake ? Color(hex: 0xC3B1EE) : .white.opacity(0.6)), style: StrokeStyle(lineWidth: 2, dash: awake ? [] : [3, 4]))
            } else {
                Self.drawBall(&ctx, at: CGPoint(x: b.center.x, y: b.center.y), number: b.number, radius: 10, scale: max(0.01, s), lift: bob)
            }
        }
    }

    private func drawWalls(_ ctx: inout GraphicsContext) {
        for w in game.engine.walls {
            var p = Path()
            p.move(to: CGPoint(x: w.a.x, y: w.a.y)); p.addLine(to: CGPoint(x: w.b.x, y: w.b.y))
            ctx.stroke(p.offsetBy(dx: 2, dy: 4), with: .color(Color(hex: 0x0A1446).opacity(0.22)), style: StrokeStyle(lineWidth: Wall.thickness * 2, lineCap: .round))
            ctx.stroke(p, with: .color(Theme.ink), style: StrokeStyle(lineWidth: Wall.thickness * 2 + 3, lineCap: .round))
            ctx.stroke(p, with: .color(Theme.wood), style: StrokeStyle(lineWidth: Wall.thickness * 2 - 1, lineCap: .round))
        }
    }

    private func drawWarps(_ ctx: inout GraphicsContext) {
        let colors = [Color(hex: 0xC3B1EE), Color(hex: 0x8FD9B6)]
        for (i, w) in game.engine.warps.enumerated() {
            for v in [w.a, w.b] {
                let c = CGPoint(x: v.x, y: v.y)
                ctx.fill(CharacterArt.circle(c, Warp.radius + 4), with: .color(colors[i % 2]))
                ctx.fill(CharacterArt.circle(c, Warp.radius), with: .color(Theme.ink))
                let t = game.clock * 2
                for k in 0..<3 {
                    let rr = Warp.radius * (0.3 + 0.7 * ((t + Double(k) / 3).truncatingRemainder(dividingBy: 1)))
                    ctx.stroke(CharacterArt.circle(c, rr), with: .color(colors[i % 2].opacity(0.7)), lineWidth: 1.5)
                }
            }
        }
    }

    static func drawBall(_ ctx: inout GraphicsContext, at c: CGPoint, number n: Int, radius r: CGFloat, scale s: CGFloat = 1, lift: CGFloat = 0) {
        ctx.fill(CharacterArt.ellipse(CGPoint(x: c.x + 2, y: c.y + 4), r * s, r * 0.75 * s), with: .color(Color(hex: 0x0A1446).opacity(0.22)))
        let p = CGPoint(x: c.x, y: c.y - lift)
        let rr = r * s
        ctx.fill(CharacterArt.circle(p, rr), with: .color(Theme.ball(n)))
        ctx.stroke(CharacterArt.circle(p, rr), with: .color(Theme.ink), lineWidth: 2.2)
        ctx.fill(CharacterArt.circle(p, rr * 0.5), with: .color(.white))
        ctx.draw(Text("\(n)").font(.system(size: max(1, rr * 0.8), weight: .heavy, design: .rounded)).foregroundStyle(Theme.ink), at: CGPoint(x: p.x, y: p.y + 0.5))
        ctx.fill(CharacterArt.ellipse(CGPoint(x: p.x - rr * 0.38, y: p.y - rr * 0.45), rr * 0.2, rr * 0.13), with: .color(.white.opacity(0.6)))
    }

    private func drawGuide(_ ctx: inout GraphicsContext, preview pv: ShotPreview, aim: (direction: Vec, power: Double)) {
        let n = pv.points.count
        for (i, p) in pv.points.enumerated() {
            let a = 1 - Double(i) / Double(max(n, 1))
            ctx.fill(CharacterArt.circle(CGPoint(x: p.x, y: p.y), 3), with: .color(.white.opacity(0.35 + a * 0.65)))
        }
        if pv.reachesStop {
            ctx.stroke(CharacterArt.circle(CGPoint(x: pv.end.x, y: pv.end.y), game.engine.rules.headRadius), with: .color(.white),
                       style: StrokeStyle(lineWidth: 2.5, dash: [4, 4]))
        }
        // キュー
        let h = game.engine.head
        let back = game.engine.rules.headRadius + 6 + aim.power * 36, len = 170.0
        func seg(_ a: Double, _ b: Double, _ w: CGFloat, _ c: Color) {
            var p = Path()
            p.move(to: CGPoint(x: h.x - aim.direction.x * a, y: h.y - aim.direction.y * a))
            p.addLine(to: CGPoint(x: h.x - aim.direction.x * b, y: h.y - aim.direction.y * b))
            ctx.stroke(p, with: .color(c), style: StrokeStyle(lineWidth: w, lineCap: .round))
        }
        seg(back, back + len, 10, Theme.ink)
        seg(back, back + len, 5, Color(hex: 0xF2D9A6))
        seg(back, back + 7, 5, Color(hex: 0x6AA5E3))
        seg(back + len * 0.65, back + len, 5, Color(hex: game.character.shade))
    }

    private func drawSnake(_ ctx: inout GraphicsContext, aim: (direction: Vec, power: Double)?) {
        let e = game.engine
        // ワープした所で線を切る
        var runs: [[CGPoint]] = [[]]
        for (i, v) in e.path.enumerated() {
            if i < e.jumps.count, e.jumps[i], !(runs.last?.isEmpty ?? true) { runs.append([]) }
            runs[runs.count - 1].append(CGPoint(x: v.x, y: v.y))
        }
        for run in runs where run.count >= 2 {
            CharacterArt.drawBody(&ctx, points: run, width: e.rules.bodyRadius * 2, character: game.character)
        }
        let h = CGPoint(x: e.head.x, y: e.head.y)
        ctx.fill(CharacterArt.ellipse(CGPoint(x: h.x + 2, y: h.y + 5), e.rules.headRadius, e.rules.headRadius * 0.8), with: .color(Color(hex: 0x0A1446).opacity(0.22)))
        let look = aim.map { CGVector(dx: $0.direction.x, dy: $0.direction.y) } ?? CGVector(dx: e.direction.x, dy: e.direction.y)
        CharacterArt.drawHead(&ctx, at: h, radius: e.rules.headRadius + 1, character: game.character, face: game.currentFace,
                              look: look, t: game.clock, power: aim?.power ?? 0)
    }

    private func drawSparks(_ ctx: inout GraphicsContext) {
        for s in game.sparks {
            let life = 1 - (game.clock - s.born) / (s.ring ? 0.35 : 0.5)
            guard life > 0 else { continue }
            if s.ring {
                let r = game.engine.rules.bodyRadius + (1 - life) * 14
                ctx.stroke(CharacterArt.circle(s.at, r), with: .color(.white.opacity(life)), lineWidth: 3)
            } else {
                ctx.fill(CharacterArt.circle(s.at, 3.5), with: .color(s.color.opacity(life)))
                ctx.stroke(CharacterArt.circle(s.at, 3.5), with: .color(Theme.ink.opacity(life)), lineWidth: 1.5)
            }
        }
    }

    private func drawPops(_ ctx: inout GraphicsContext) {
        for p in game.pops {
            let t = game.clock - p.born
            let k = t < 0.15 ? Self.easeOutBack(t / 0.15) : 1
            let alpha = max(0, 1 - max(0, t - 0.7) / 0.5)
            let y = p.at.y - t * (p.big ? 10 : 34)
            let size = max(1, (p.big ? 22 : 18) * k)
            let font = Font.system(size: size, weight: .black, design: .rounded)
            for (dx, dy) in [(-2.0, 0.0), (2, 0), (0, -2), (0, 2), (-1.5, -1.5), (1.5, 1.5), (-1.5, 1.5), (1.5, -1.5)] {
                ctx.draw(Text(p.text).font(font).foregroundStyle(Theme.ink.opacity(alpha)), at: CGPoint(x: p.at.x + dx, y: y + dy))
            }
            ctx.draw(Text(p.text).font(font).foregroundStyle(p.color.opacity(alpha)), at: CGPoint(x: p.at.x, y: y))
        }
    }

    /// おてほんの線（ピンク）と、キューの影
    private func drawHint(_ ctx: inout GraphicsContext, shot: Shot, preview pv: ShotPreview) {
        let pink = Color(hex: 0xF7A9C4)
        let match = game.aimMatchesHint
        for (i, p) in pv.points.enumerated() where i % 2 == 0 {
            ctx.fill(CharacterArt.circle(CGPoint(x: p.x, y: p.y), match ? 3.4 : 2.6), with: .color(pink.opacity(match ? 1 : 0.85)))
        }
        let h = game.engine.head, d = Vec.angle(shot.angle)
        let back = game.engine.rules.headRadius + 6 + shot.power * 36
        var cue = Path()
        cue.move(to: CGPoint(x: h.x - d.x * back, y: h.y - d.y * back))
        cue.addLine(to: CGPoint(x: h.x - d.x * (back + 150), y: h.y - d.y * (back + 150)))
        ctx.stroke(cue, with: .color(pink.opacity(0.75)), style: StrokeStyle(lineWidth: 8, lineCap: .round, dash: [6, 6]))
        if !game.isAiming {
            let label = "おてほん：強さ \(Int((shot.power * 100).rounded()))%"
            let font = Font.system(size: 13, weight: .black, design: .rounded)
            let at = CGPoint(x: min(max(h.x, 90), game.engine.rules.width - 90), y: max(h.y - 34, 20))
            for (dx, dy) in [(-1.5, 0.0), (1.5, 0), (0, -1.5), (0, 1.5)] {
                ctx.draw(Text(label).font(font).foregroundStyle(Theme.ink), at: CGPoint(x: at.x + dx, y: at.y + dy))
            }
            ctx.draw(Text(label).font(font).foregroundStyle(pink), at: at)
        } else if match {
            let font = Font.system(size: 15, weight: .black, design: .rounded)
            let at = CGPoint(x: game.engine.rules.width / 2, y: game.engine.rules.height - 44)
            for (dx, dy) in [(-1.5, 0.0), (1.5, 0), (0, -1.5), (0, 1.5)] {
                ctx.draw(Text("ぴったり！はなして").font(font).foregroundStyle(Theme.ink), at: CGPoint(x: at.x + dx, y: at.y + dy))
            }
            ctx.draw(Text("ぴったり！はなして").font(font).foregroundStyle(pink), at: at)
        }
    }

    private func drawGaugeTarget(_ ctx: inout GraphicsContext, power: Double, rules: Rules) {
        let gw = 140.0, gx = rules.width / 2 - gw / 2, gy = rules.height - 26
        let x = gx + gw * power
        var p = Path()
        p.move(to: CGPoint(x: x, y: gy - 7)); p.addLine(to: CGPoint(x: x, y: gy + 17))
        ctx.stroke(p, with: .color(Color(hex: 0xF7A9C4)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
    }

    private func drawGauge(_ ctx: inout GraphicsContext, power: Double, rules: Rules) {
        let gw = 140.0, gx = rules.width / 2 - gw / 2, gy = rules.height - 26
        ctx.fill(rounded(CGRect(x: gx - 3, y: gy - 3, width: gw + 6, height: 16), 8), with: .color(Theme.ink))
        let c: Color = power < rules.minimumPower ? Theme.inkSoft : (power > 0.8 ? Color(hex: 0xFF8A7E) : Theme.sun)
        ctx.fill(rounded(CGRect(x: gx, y: gy, width: max(10, gw * power), height: 10), 5), with: .color(c))
    }

    private func drawHint(_ ctx: inout GraphicsContext) {
        let k = game.clock.truncatingRemainder(dividingBy: 1.6) / 1.6
        let h = game.engine.head
        let fy = h.y + 40 + Self.easeOutBack(min(1, k * 1.4)) * 60
        let alpha = k > 0.85 ? (1 - k) / 0.15 : 1
        let finger = CharacterArt.circle(CGPoint(x: h.x + 10, y: fy), 13)
        ctx.fill(finger, with: .color(.white.opacity(alpha)))
        ctx.stroke(finger, with: .color(Theme.ink.opacity(alpha)), lineWidth: 3)
        let label = "ひっぱって、はなす！"
        let font = Font.system(size: 16, weight: .black, design: .rounded)
        for (dx, dy) in [(-2.0, 0.0), (2, 0), (0, -2), (0, 2)] {
            ctx.draw(Text(label).font(font).foregroundStyle(Theme.ink), at: CGPoint(x: game.engine.rules.width / 2 + dx, y: h.y - 48 + dy))
        }
        ctx.draw(Text(label).font(font).foregroundStyle(.white), at: CGPoint(x: game.engine.rules.width / 2, y: h.y - 48))
    }

    static func easeOutBack(_ x: Double) -> Double {
        let c = 1.70158
        return 1 + (c + 1) * pow(x - 1, 3) + c * pow(x - 1, 2)
    }
}

/// ヒントを開ける確認
struct HintSheet: View {
    @Environment(AppModel.self) private var app
    let stage: Stage
    let close: () -> Void

    var body: some View {
        let price = app.hintPrice(for: stage)
        VStack(spacing: 14) {
            Image(systemName: "lightbulb.fill").font(.system(size: 30, weight: .bold)).foregroundStyle(Theme.ink)
                .frame(width: 60, height: 60).background(Circle().fill(Theme.sun))
                .overlay(Circle().stroke(Theme.ink, lineWidth: 3))
            Text("\(stage.id) のおてほん").font(Theme.title(22)).foregroundStyle(Theme.ink)
            Text("最初からやりなおして、★3 の打ち方を 1 打ずつピンクの線で見せます。近い向きと強さで引くと「ぴったり」になり、おてほんどおりに打てます。おてほんの間は、なかまのとくいはお休みです。")
                .font(Theme.body(14)).foregroundStyle(Theme.ink).multilineTextAlignment(.center)
            Group {
                switch price {
                case .owned:
                    Button("おてほんを見る") { open() }.buttonStyle(ChunkyButtonStyle(fill: Theme.mint, text: .white))
                case .pro:
                    Button("おてほんを見る（Pro は無料）") { open() }.buttonStyle(ChunkyButtonStyle(fill: Theme.mint, text: .white))
                case .freeToday:
                    Button("きょうの無料ヒントで見る") { open() }.buttonStyle(ChunkyButtonStyle(fill: Theme.mint, text: .white))
                    Text("無料ヒントは 1 日 1 回。一度開けたステージは、ずっと見られます").font(Theme.body(12)).foregroundStyle(Theme.inkSoft)
                case .snacks(let n):
                    Button { open() } label: {
                        HStack(spacing: 6) { Text("おやつ"); SnackIcon(size: 18); Text("\(n) で見る") }
                    }
                    .buttonStyle(ChunkyButtonStyle(fill: Theme.mint, text: .white))
                    Text("いまのおやつ \(app.progress.snacks)。一度開けたステージは、ずっと見られます").font(Theme.body(12)).foregroundStyle(Theme.inkSoft)
                case .tooFewSnacks(let n):
                    Text("おやつが \(n) 要ります（いま \(app.progress.snacks)）。あしたの無料ヒントを待つか、ステージやきょうの台でおやつをためよう")
                        .font(Theme.body(13)).foregroundStyle(Theme.ink).multilineTextAlignment(.center)
                }
            }
            if !app.isPro {
                Button("Pro ならヒントはいつも無料") { close(); app.showPro = true }
                    .font(Theme.label(13)).foregroundStyle(Theme.ink).underline()
            }
        }
        .padding(24)
    }

    private func open() {
        if app.playWithHint(stage) { Feedback.bonus(); close() }
    }
}
