import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var app = app
        ZStack {
            StripeBackground()
            VStack(spacing: 0) {
            Group {
                switch app.route {
                case .home: HomeView()
                case .game:
                    if let g = app.game { GameView(game: g).id(ObjectIdentifier(g)) } else { HomeView() }
                case .collection: CollectionView()
                case .capsule: CapsuleView()
                case .worlds: WorldsView()
                case .stages(let w): StagesView(world: w)
                }
            }
            .frame(maxWidth: 560)
            .transition(.opacity)
            if let unit = app.bannerUnitID {
                // 台とのあいだを空け、引っぱっている間は押せないようにする（誤タップを防ぐ）
                BannerSlot(unitID: unit)
                    .padding(.top, 14)
                    .allowsHitTesting(!(app.game?.isAiming ?? false) && !(app.game?.engine.isMoving ?? false))
            }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: app.route)
        .sheet(isPresented: $app.showPro) { ProView() }
        .preferredColorScheme(.light)
    }
}
