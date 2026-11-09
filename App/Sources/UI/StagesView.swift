import SwiftUI

/// ワールドの一覧。小さな台の絵に、星の数と鍵
struct WorldsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                BackButton { app.route = .home }
                Spacer()
                Text("ステージ").font(Theme.title(24)).foregroundStyle(Theme.ink)
                Spacer()
                Pill {
                    Image(systemName: "star.fill").foregroundStyle(Theme.ink)
                    Text("\(app.totalStageStars)/\(app.book.count * 3)").font(Theme.title(15)).monospacedDigit().foregroundStyle(Theme.ink)
                }
            }
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: sizeClass == .regular ? 3 : 2), spacing: 14) {
                    ForEach(StageBook.worlds) { w in worldCard(w) }
                }
                .padding(.vertical, 8)
                .padding(.bottom, 24)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func worldCard(_ w: World) -> some View {
        let stages = app.stages(in: w.id)
        let first = stages.first
        let open = first.map { app.isUnlocked($0) } ?? false
        let proLocked = w.isPro && !app.isPro
        let stars = app.progress.totalStars(world: w.id, in: app.book)
        return Button {
            Feedback.tap()
            if proLocked { app.showPro = true } else if open { app.route = .stages(w.id) }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    MiniTable(stage: first, felt: Color(hex: w.felt))
                        .opacity(open || proLocked ? 1 : 0.55)
                    if proLocked {
                        Label("Pro", systemImage: "lock.fill").font(Theme.label(13)).foregroundStyle(Theme.ink)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Capsule().fill(Theme.rarity(.pro)))
                            .overlay(Capsule().stroke(Theme.ink, lineWidth: 2))
                    } else if !open {
                        Image(systemName: "lock.fill").font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                    }
                }
                .frame(height: 120)
                Text("ワールド \(w.id)").font(Theme.body(11)).foregroundStyle(Theme.inkSoft)
                Text(w.name).font(Theme.label(16)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.8)
                Text(w.detail).font(Theme.body(11)).foregroundStyle(Theme.inkSoft).lineLimit(2, reservesSpace: true)
                HStack(spacing: 4) {
                    Image(systemName: "star.fill").font(.system(size: 11)).foregroundStyle(Theme.ink)
                    Text("\(stars)/\(stages.count * 3)").font(Theme.label(12)).monospacedDigit().foregroundStyle(Theme.ink)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 20).fill(Theme.cream))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.ink, lineWidth: Theme.line))
            .background(RoundedRectangle(cornerRadius: 20).fill(Theme.ink).offset(y: 4))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("ワールド \(w.id) \(w.name)、星 \(stars)\(proLocked ? "、Pro" : (open ? "" : "、まだ遊べない"))")
    }
}

/// 1 つのワールドの 12 ステージ
struct StagesView: View {
    @Environment(AppModel.self) private var app
    let world: Int

    var body: some View {
        let w = StageBook.world(world)
        VStack(spacing: 12) {
            HStack {
                BackButton { app.route = .worlds }
                Spacer()
                VStack(spacing: 0) {
                    Text("ワールド \(w.id)").font(Theme.body(11)).foregroundStyle(Theme.inkSoft)
                    Text(w.name).font(Theme.title(22)).foregroundStyle(Theme.ink)
                }
                Spacer()
                Color.clear.frame(width: 40, height: 40)
            }
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 12) {
                    ForEach(app.stages(in: world)) { s in tile(s, felt: Color(hex: w.felt)) }
                }
                .padding(.vertical, 8)
                friendTip(w)
                    .padding(.bottom, 24)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func tile(_ s: Stage, felt: Color) -> some View {
        let open = app.isUnlocked(s)
        let stars = app.progress.stars(of: s.id)
        let isNext = app.nextStage?.id == s.id
        return Button {
            Feedback.tap()
            if open { app.playStage(s) }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    MiniTable(stage: s, felt: felt).opacity(open ? 1 : 0.4)
                    if !open { Image(systemName: "lock.fill").foregroundStyle(.white) }
                }
                .frame(height: 92)
                Text(s.id).font(Theme.title(15)).foregroundStyle(Theme.ink)
                HStack(spacing: 1) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < stars ? "star.fill" : "star")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(i < stars ? Color(hex: 0xF5CF63) : Theme.disabled)
                    }
                }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 16).fill(isNext ? Theme.sun.opacity(0.7) : Theme.cream))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.ink, lineWidth: isNext ? 4 : Theme.line))
        }
        .buttonStyle(.plain)
        .disabled(!open)
        .accessibilityLabel("\(s.id)、\(s.goal.label)、星 \(stars)\(open ? "" : "、まだ遊べない")")
    }

    /// このワールドで役に立つなかま
    private func friendTip(_ w: World) -> some View {
        let id: String? = [2: "momo", 3: "mint", 4: "soda", 5: "neon"][w.id]
        return Group {
            if let id {
                let c = Roster.character(id)
                HStack(spacing: 12) {
                    CharacterPortrait(character: c, face: .happy, showBody: false).frame(width: 64, height: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("このワールドでは \(c.name) が活やく").font(Theme.label(14)).foregroundStyle(Theme.ink)
                        Text(c.perk.label(level: 1)).font(Theme.body(12)).foregroundStyle(Theme.inkSoft)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.paper))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.ink, lineWidth: 2))
            }
        }
    }
}

/// ステージの配置を小さく描いた台（一覧用）
struct MiniTable: View {
    let stage: Stage?
    let felt: Color

    var body: some View {
        Canvas { ctx, size in
            let r = CGRect(origin: .zero, size: size)
            ctx.fill(Path(roundedRect: r, cornerRadius: 10), with: .color(Theme.wood))
            let inner = r.insetBy(dx: 5, dy: 5)
            ctx.fill(Path(roundedRect: inner, cornerRadius: 6), with: .color(felt))
            guard let s = stage else { return }
            let k = min(inner.width / 360, inner.height / 560)
            let ox = inner.midX - 180 * k, oy = inner.midY - 280 * k
            func p(_ v: Vec) -> CGPoint { CGPoint(x: ox + v.x * k, y: oy + v.y * k) }
            for w in s.walls {
                var path = Path(); path.move(to: p(w.a)); path.addLine(to: p(w.b))
                ctx.stroke(path, with: .color(Theme.woodLight), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
            for w in s.warps { for v in [w.a, w.b] { ctx.fill(CharacterArt.circle(p(v), 4), with: .color(Theme.ink)) } }
            for b in s.bumpers { ctx.fill(CharacterArt.circle(p(b.center), max(2, b.radius * k)), with: .color(Theme.bumper)) }
            for b in s.balls {
                ctx.fill(CharacterArt.circle(p(b.center), 3), with: .color(b.kind == .ghost ? .white.opacity(0.6) : Theme.ball(b.number)))
            }
            let line = s.body + [s.head]
            var body = Path(); body.move(to: p(line[0])); for v in line.dropFirst() { body.addLine(to: p(v)) }
            ctx.stroke(body, with: .color(Color(hex: 0xFF8A7E)), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            ctx.fill(CharacterArt.circle(p(s.head), 4), with: .color(Color(hex: 0xFF8A7E)))
        }
        .accessibilityHidden(true)
    }
}
