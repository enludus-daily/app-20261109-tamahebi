import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var app = app
        ZStack {
            StripeBackground()
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
        }
        .animation(.easeInOut(duration: 0.2), value: app.route)
        .sheet(isPresented: $app.showPro) { ProView() }
        .preferredColorScheme(.light)
    }
}
