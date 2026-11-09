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
                .presentationDetents([.medium])
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
        let owned = app.progress.owns(c, isPro: app.isPro)
        let selected = app.progress.selected == c.id
        return Button {
            Feedback.tap()
            if owned { detail = c } else if c.rarity == .pro { app.showPro = true } else { app.route = .capsule }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    CharacterPortrait(character: c, face: owned ? (selected ? .happy : .idle) : .sleep, showBody: false, silhouette: !owned)
                        .frame(height: 76)
                    if c.rarity == .pro && !owned {
                        Image(systemName: "lock.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.ink)
                            .padding(5).background(Circle().fill(Theme.rarity(.pro)))
                    }
                }
                Text(owned ? c.name : "？？？").font(Theme.label(13)).foregroundStyle(Theme.ink)
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
        .accessibilityLabel(owned ? "\(c.name)、\(c.rarity.label)\(selected ? "、えらんでいる" : "")" : "まだ会っていない\(c.rarity.label)のなかま")
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
        VStack(spacing: 12) {
            CharacterPortrait(character: character, face: .happy)
                .frame(width: 220, height: 160)
            Text(character.name).font(Theme.title(28)).foregroundStyle(Theme.ink)
            Text(character.rarity.label).font(Theme.label(12)).foregroundStyle(Theme.ink)
                .padding(.horizontal, 10).padding(.vertical, 2)
                .background(Capsule().fill(Theme.rarity(character.rarity)))
            Text(character.line).font(Theme.body(15)).foregroundStyle(Theme.ink).multilineTextAlignment(.center)
            Label("とくい：\(character.perk.label)", systemImage: "sparkle")
                .font(Theme.body(13)).foregroundStyle(Theme.inkSoft)
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
