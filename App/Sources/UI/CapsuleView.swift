import SwiftUI

/// カプセル：遊んでためたおやつで、なかまを 1 匹よぶ（お金では回せない）
struct CapsuleView: View {
    @Environment(AppModel.self) private var app
    @State private var phase: Phase = .idle
    @State private var handle = 0.0
    @State private var wobble = 0.0
    @State private var drop: CGFloat = -40
    @State private var result: PullResult?
    @State private var showRates = false

    enum Phase { case idle, turning, dropped, revealed }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                BackButton { app.route = .home }
                Spacer()
                Text(String(localized: "カプセル")).font(Theme.title(24)).foregroundStyle(Theme.ink)
                Spacer()
                Pill {
                    SnackIcon()
                    Text("\(app.progress.snacks)").font(Theme.title(16)).monospacedDigit().foregroundStyle(Theme.ink)
                        .contentTransition(.numericText()).animation(.snappy, value: app.progress.snacks)
                }
            }
            Spacer(minLength: 0)
            ZStack {
                machine
                if phase == .revealed, let r = result { reveal(r).transition(.scale(scale: 0.6).combined(with: .opacity)) }
            }
            Spacer(minLength: 0)
            controls
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .sheet(isPresented: $showRates) { RatesSheet().presentationDetents([.medium, .large]).presentationBackground(Theme.cream) }
    }

    // MARK: 機械

    private var machine: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(Color.white.opacity(0.55))
                    .overlay(Circle().stroke(Theme.ink, lineWidth: 4))
                Canvas { ctx, size in
                    let colors: [UInt32] = Roster.capsulePool.map(\.body)
                    let c = CGPoint(x: size.width / 2, y: size.height / 2)
                    for i in 0..<14 {
                        let a = Double(i) * 2.4 + wobble * 0.3
                        let rr = Double(size.width) * 0.32 * (0.35 + 0.65 * Double((i * 7) % 10) / 10)
                        let p = CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr * 0.8 + size.height * 0.08)
                        let r = size.width * 0.085
                        ctx.fill(CharacterArt.circle(p, r), with: .color(Color(hex: colors[i % colors.count])))
                        var top = Path()
                        top.addArc(center: p, radius: r, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                        ctx.fill(top, with: .color(.white.opacity(0.7)))
                        ctx.stroke(CharacterArt.circle(p, r), with: .color(Theme.ink), lineWidth: 2.5)
                    }
                    ctx.fill(CharacterArt.ellipse(CGPoint(x: size.width * 0.3, y: size.height * 0.25), size.width * 0.08, size.width * 0.04), with: .color(.white.opacity(0.8)))
                }
                .clipShape(Circle())
            }
            .frame(width: 220, height: 220)
            .rotationEffect(.degrees(sin(wobble * .pi * 6) * 3))
            ZStack {
                RoundedRectangle(cornerRadius: 22).fill(Color(hex: 0xFF8A7E))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.ink, lineWidth: 4))
                HStack(spacing: 40) {
                    // 取り出し口
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(Theme.ink.opacity(0.85)).frame(width: 64, height: 50)
                        if phase == .dropped || phase == .revealed, let r = result {
                            capsuleBall(Color(hex: r.character.body), size: 40)
                                .offset(y: drop)
                                .onTapGesture { open() }
                        }
                    }
                    // ハンドル
                    ZStack {
                        Circle().fill(Theme.cream).overlay(Circle().stroke(Theme.ink, lineWidth: 4)).frame(width: 64, height: 64)
                        Capsule().fill(Theme.sun).overlay(Capsule().stroke(Theme.ink, lineWidth: 3)).frame(width: 14, height: 54)
                            .rotationEffect(.degrees(handle))
                    }
                    .accessibilityHidden(true)
                }
            }
            .frame(width: 260, height: 120)
            .offset(y: -10)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "カプセルの機械"))
    }

    private func capsuleBall(_ color: Color, size: CGFloat) -> some View {
        ZStack {
            Circle().fill(color)
            Circle().trim(from: 0.5, to: 1).fill(.white.opacity(0.75))
            Circle().stroke(Theme.ink, lineWidth: 3)
        }
        .frame(width: size, height: size)
    }

    private func reveal(_ r: PullResult) -> some View {
        VStack(spacing: 8) {
            Text(r.isNew ? String(localized: "あたらしいなかま！") : (r.levelUp != nil ? String(localized: "なかよし度アップ！") : String(localized: "また会えたね"))).font(Theme.title(18)).foregroundStyle(Theme.ink)
            CharacterPortrait(character: r.character.wearing(app.progress.costume(of: r.character)), face: .happy).frame(width: 200, height: 150)
            if !r.isNew {
                HStack(spacing: 6) {
                    Hearts(level: app.progress.level(of: r.character), size: 16)
                    Text("Lv\(app.progress.level(of: r.character))").font(Theme.title(16)).foregroundStyle(Theme.ink)
                }
                if let u = r.unlocked {
                    Text(u).font(Theme.label(14)).foregroundStyle(Theme.ink)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(Color(hex: 0xF7A9C4).opacity(0.5)))
                }
            }
            Text(r.character.name).font(Theme.title(30)).foregroundStyle(Theme.ink)
            Text(r.character.rarity.label).font(Theme.label(12)).foregroundStyle(Theme.ink)
                .padding(.horizontal, 10).padding(.vertical, 2)
                .background(Capsule().fill(Theme.rarity(r.character.rarity)))
            Text(r.character.line).font(Theme.body(14)).foregroundStyle(Theme.ink).multilineTextAlignment(.center)
            Label(String(localized: "とくい：") + r.character.perk.label(level: app.progress.level(of: r.character)), systemImage: "sparkle").font(Theme.body(12)).foregroundStyle(Theme.inkSoft)
            if r.refund > 0 {
                HStack(spacing: 4) { SnackIcon(size: 16); Text(String(localized: "おかえし +\(L.s(r.refund))")).font(Theme.label(13)) }.foregroundStyle(Theme.ink)
            }
            HStack(spacing: 10) {
                Button(String(localized: "この子にする")) { app.select(r.character); Feedback.tap(); withAnimation { phase = .idle; result = nil } }
                    .buttonStyle(ChunkyButtonStyle(fill: Theme.mint, text: .white))
                Button(String(localized: "とじる")) { withAnimation { phase = .idle; result = nil } }
                    .buttonStyle(ChunkyButtonStyle())
            }
        }
        .frame(maxWidth: 320)
        .card()
    }

    // MARK: 操作

    private var controls: some View {
        VStack(spacing: 8) {
            Button {
                turn()
            } label: {
                HStack(spacing: 8) {
                    Text(String(localized: "まわす"))
                    SnackIcon(size: 20)
                    Text("\(Progress.capsuleCost)").monospacedDigit()
                }
            }
            .buttonStyle(ChunkyButtonStyle(fill: app.progress.canPull() ? Theme.mint : Theme.disabled, text: .white, height: 58))
            .disabled(!app.progress.canPull() || phase != .idle)
            .frame(maxWidth: 340)
            if !app.progress.canPull() && phase == .idle {
                Text(String(localized: "おやつは遊ぶとたまるよ。きょうの台の1回目は +\(L.s(Progress.dailyFirstPlayBonus))"))
                    .font(Theme.body(12)).foregroundStyle(Theme.ink)
            }
            if phase == .dropped {
                Text(String(localized: "カプセルをタップしてあけよう")).font(Theme.label(14)).foregroundStyle(Theme.ink)
            }
            Button(String(localized: "出るなかまと確率")) { showRates = true }
                .font(Theme.label(13)).foregroundStyle(Theme.ink).underline()
        }
    }

    private func turn() {
        guard phase == .idle, let r = app.pull() else { return }
        result = r
        phase = .turning
        Feedback.tap()
        withAnimation(.easeInOut(duration: 0.8)) { handle += 360; wobble += 1 }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(850))
            Feedback.shot(power: 0.6)
            drop = -40
            phase = .dropped
            withAnimation(.spring(response: 0.45, dampingFraction: 0.5)) { drop = 0 }
        }
    }

    private func open() {
        guard phase == .dropped, let r = result else { return }
        Feedback.reveal(r.character.rarity)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { phase = .revealed }
    }
}

/// 確率の表（すべて画面に出す）
struct RatesSheet: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "出るなかまと確率")).font(Theme.title(22)).foregroundStyle(Theme.ink)
                Text(String(localized: "カプセルは遊んでためたおやつだけで回せます。お金では回せません。同じ子にもう一度会うと、なかよし度が上がります（Lv5 まで。Lv2・Lv4 できせかえ、Lv3・Lv5 でとくいが強くなる）。Lv5 の子に会ったときは、おやつが \(L.s(Progress.maxLevelRefund)) 返ってきます。Pro 限定のなかまはカプセルからは出ません。"))
                    .font(Theme.body(13)).foregroundStyle(Theme.inkSoft)
                ForEach([Rarity.superRare, .rare, .common], id: \.self) { r in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "\(L.s(r.label))（合計 \(L.s(L.pct(Int(r.pullRate * 100))))）")).font(Theme.label(15)).foregroundStyle(Theme.ink)
                        ForEach(Roster.capsulePool.filter { $0.rarity == r }) { c in
                            HStack {
                                Text(c.name)
                                Spacer()
                                Text(Progress.rate(of: c), format: .percent.precision(.fractionLength(1))).monospacedDigit()
                            }
                            .font(Theme.body(14)).foregroundStyle(Theme.ink)
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.rarity(r).opacity(0.5)))
                }
            }
            .padding(20)
        }
    }
}
