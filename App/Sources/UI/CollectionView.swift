import SwiftUI

/// なかまの一覧。会ったなかまは選べる。まだのなかまは影だけ見える
struct CollectionView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var detail: Character?

    var body: some View {
        VStack(spacing: 12) {
            header
            ScrollView {
                VStack(spacing: 18) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: sizeClass == .regular ? 5 : 3), spacing: 12) {
                        ForEach(Roster.all) { c in tile(c) }
                    }
                    tablePicker
                }
                .padding(.vertical, 8)
                .padding(.bottom, 24)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .sheet(item: $detail) { c in
            CharacterDetail(character: c)
                .presentationDetents([.large])
                .presentationBackground(Theme.cream)
        }
    }

    private var header: some View {
        HStack {
            BackButton { app.route = .home }
            Spacer()
            Text("なかま").font(Theme.title(24)).foregroundStyle(Theme.ink)
            Spacer()
            Pill {
                SnackIcon()
                Text("\(app.progress.snacks)").font(Theme.title(16)).monospacedDigit().foregroundStyle(Theme.ink)
            }
        }
    }

    private func tile(_ c: Character) -> some View {
        let owned = app.owns(c)
        let selected = app.progress.selected == c.id
        let level = app.progress.level(of: c)
        let look = owned ? c.wearing(app.progress.costume(of: c)) : c
        return Button {
            Feedback.tap()
            if owned { detail = c } else if c.rarity == .pro || c.rarity == .pack { app.showPro = true } else { app.route = .capsule }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    CharacterPortrait(character: look, face: owned ? (selected ? .happy : .idle) : .sleep, showBody: false, silhouette: !owned)
                        .frame(height: 76)
                    if (c.rarity == .pro || c.rarity == .pack) && !owned {
                        Image(systemName: "lock.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.ink)
                            .padding(5).background(Circle().fill(Theme.rarity(c.rarity)))
                    }
                }
                Text(owned ? c.name : "？？？").font(Theme.label(13)).foregroundStyle(Theme.ink)
                if owned { Hearts(level: level, size: 9) }
                Text(c.rarity.label).font(Theme.body(10)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Capsule().fill(Theme.rarity(c.rarity)))
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 18).fill(selected ? Theme.sun.opacity(0.6) : Theme.cream))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.ink, lineWidth: selected ? 4 : Theme.line))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(owned ? "\(c.name)、\(c.rarity.label)、なかよし Lv\(level)\(selected ? "、えらんでいる" : "")" : "まだ会っていない\(c.rarity.label)のなかま")
    }

    private var tablePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("台のいろ").font(Theme.label(16)).foregroundStyle(Theme.ink)
                if !app.isPro { Text("あお以外は Pro").font(Theme.body(12)).foregroundStyle(Theme.inkSoft) }
            }
            HStack(spacing: 10) {
                ForEach(TableTheme.allCases, id: \.self) { t in
                    let locked = t.isPro && !app.isPro
                    Button {
                        Feedback.tap()
                        if locked { app.showPro = true } else { app.progress.table = t }
                    } label: {
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 10).fill(Theme.felt(t))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.wood, lineWidth: 5).padding(1))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.ink, lineWidth: app.progress.table == t ? 4 : 2))
                                .overlay { if locked { Image(systemName: "lock.fill").foregroundStyle(.white) } }
                                .frame(height: 54)
                            Text(t.label).font(Theme.body(12)).foregroundStyle(Theme.ink)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("台のいろ \(t.label)\(locked ? "、Pro" : "")")
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.cream))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.ink, lineWidth: Theme.line))
    }
}

struct CharacterDetail: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let character: Character

    var body: some View {
        let level = app.progress.level(of: character)
        let costume = app.progress.costume(of: character)
        ScrollView {
            VStack(spacing: 12) {
                CharacterPortrait(character: character.wearing(costume), face: .happy)
                    .frame(width: 220, height: 160)
                Text(character.name).font(Theme.title(28)).foregroundStyle(Theme.ink)
                HStack(spacing: 8) {
                    Text(character.rarity.label).font(Theme.label(12)).foregroundStyle(Theme.ink)
                        .padding(.horizontal, 10).padding(.vertical, 2)
                        .background(Capsule().fill(Theme.rarity(character.rarity)))
                    Hearts(level: level, size: 13)
                    Text("なかよし Lv\(level)").font(Theme.label(12)).foregroundStyle(Theme.ink)
                }
                Text(character.line).font(Theme.body(15)).foregroundStyle(Theme.ink).multilineTextAlignment(.center)
                Label("とくい：\(character.perk.label(level: level))", systemImage: "sparkle")
                    .font(Theme.body(13)).foregroundStyle(Theme.ink).multilineTextAlignment(.leading)
                if level < Roster.maxLevel && character.rarity != .pro {
                    Text("次の Lv\(level + 1)：\(nextUnlock(level + 1))（カプセルでもう一度会うと上がる）")
                        .font(Theme.body(12)).foregroundStyle(Theme.inkSoft).multilineTextAlignment(.center)
                }
                HStack(spacing: 10) {
                    ForEach(Costume.allCases, id: \.self) { k in
                        let ok = k.requiredLevel <= level
                        Button {
                            Feedback.tap()
                            app.wear(k, on: character)
                        } label: {
                            VStack(spacing: 2) {
                                CharacterPortrait(character: character.wearing(k), face: .idle, showBody: false, silhouette: !ok)
                                    .frame(width: 60, height: 48)
                                Text(ok ? k.label : "Lv\(k.requiredLevel)").font(Theme.body(11)).foregroundStyle(Theme.ink)
                            }
                            .padding(6)
                            .background(RoundedRectangle(cornerRadius: 12).fill(costume == k ? Theme.sun.opacity(0.6) : Theme.paper))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.ink, lineWidth: costume == k ? 3 : 1.5))
                        }
                        .buttonStyle(.plain)
                        .disabled(!ok)
                        .accessibilityLabel("きせかえ \(k.label)\(ok ? "" : "、なかよし Lv\(k.requiredLevel) で使える")")
                    }
                }
                Button(app.progress.selected == character.id ? "いっしょに遊んでいる" : "この子で遊ぶ") {
                    app.select(character)
                    Feedback.bonus()
                    dismiss()
                }
                .buttonStyle(ChunkyButtonStyle(fill: Theme.mint, text: .white))
                .disabled(app.progress.selected == character.id)
                .padding(.horizontal, 24)
            }
            .padding(20)
        }
    }

    private func nextUnlock(_ l: Int) -> String {
        switch l {
        case 2: "きせかえ「パステル」"
        case 3: "とくいが強くなる"
        case 4: "きせかえ「よるいろ」"
        default: "とくいがいちばん強くなる"
        }
    }
}

/// なかよし度のハート（5 こ）
struct Hearts: View {
    let level: Int
    var size: CGFloat = 10
    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<Roster.maxLevel, id: \.self) { i in
                Image(systemName: i < level ? "heart.fill" : "heart")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(i < level ? Color(hex: 0xF7A9C4) : Theme.disabled)
            }
        }
        .accessibilityHidden(true)
    }
}

struct BackButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left").font(.system(size: 16, weight: .black))
                .foregroundStyle(Theme.ink)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Theme.cream))
                .overlay(Circle().stroke(Theme.ink, lineWidth: Theme.line))
                .background(Circle().fill(Theme.ink).offset(y: 3))
        }
        .accessibilityLabel("もどる")
    }
}
