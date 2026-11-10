@preconcurrency import GoogleMobileAds
import SwiftUI

/// 画面の下に常に出すバナー（本人 2026-11-10）。Pro・チュートリアル・撮影では出さない。
/// このゲームは「どこでも引っぱる」操作なので、誤って押さないよう、台とのあいだを空け、引っぱっている間は押せないようにする（AdMob のポリシー）。
struct BannerSlot: View {
    let unitID: String
    @State private var height: CGFloat = 50

    var body: some View {
        GeometryReader { geo in
            BannerAdView(unitID: unitID, width: geo.size.width) { h in height = h }
        }
        .frame(height: height)
        .background(Theme.cream.opacity(0.6))
        .accessibilityLabel("広告")
    }
}

struct BannerAdView: UIViewRepresentable {
    let unitID: String
    let width: CGFloat
    let onHeight: (CGFloat) -> Void

    func makeUIView(context: Context) -> BannerView {
        let size = currentOrientationAnchoredAdaptiveBanner(width: max(width, 320))
        let view = BannerView(adSize: size)
        view.adUnitID = unitID
        view.rootViewController = AdMobRewarded.rootViewController
        view.load(Request())
        DispatchQueue.main.async { onHeight(size.size.height) }
        return view
    }

    func updateUIView(_ view: BannerView, context: Context) {
        if view.rootViewController == nil { view.rootViewController = AdMobRewarded.rootViewController }
    }
}
