import AppTrackingTransparency
@preconcurrency import GoogleMobileAds
import SwiftUI
@preconcurrency import UserMessagingPlatform

// リワード広告（AdMob）。本人の許可 2026-11-10。見るかどうかはいつも利用者が選ぶ（勝手に出す広告・バナーはない）。
// 使い道：ステージのヒントを開ける／結果のおやつを 2 倍にする。Pro・パックを持っていても出し方は同じ（見なくても遊べる）。

/// 広告の出どころを差し替えられるようにする（テストと撮影では広告を出さない）
@MainActor
protocol RewardedAds: AnyObject {
    var isReady: Bool { get }
    func prepare() async
    /// 広告を最後まで見たら true
    func show() async -> Bool
    /// 何回か遊んだあとの全画面広告（見終わる・閉じるまで待つ）。出せなければすぐ戻る
    func showInterstitial() async
}

/// 広告を出さない（テスト・撮影・広告が使えないとき）
@MainActor
final class NoAds: RewardedAds {
    var isReady: Bool { false }
    func prepare() async {}
    func show() async -> Bool { false }
    func showInterstitial() async {}
}

@MainActor
@Observable
final class AdMobRewarded: NSObject, RewardedAds, FullScreenContentDelegate {
    /// 本番の広告ユニット
    static let productionUnit = "ca-app-pub-1806737602764042/3664570268"
    /// Google のテスト用のリワード広告（TestFlight と開発で使う。自分で本番の広告を見ると、不正な表示として扱われることがある）
    static let testUnit = "ca-app-pub-3940256099942544/1712485313"
    /// 全画面広告の本番のユニット（本人が AdMob で作ったら入れる。空のあいだ、App Store のビルドでは出さない）
    static let productionInterstitialUnit = ""
    static let testInterstitialUnit = "ca-app-pub-3940256099942544/4411468910"

    private(set) var isReady = false
    @ObservationIgnored private var ad: RewardedAd?
    @ObservationIgnored private var interstitial: InterstitialAd?
    @ObservationIgnored private var started = false
    @ObservationIgnored private var dismissed: CheckedContinuation<Void, Never>?

    /// 開発と TestFlight（レシートが sandboxReceipt）ではテスト広告
    private var usesTestAds: Bool {
        #if DEBUG
        return true
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }
    private var unitID: String { usesTestAds ? Self.testUnit : Self.productionUnit }
    private var interstitialUnitID: String? {
        if usesTestAds { return Self.testInterstitialUnit }
        return Self.productionInterstitialUnit.isEmpty ? nil : Self.productionInterstitialUnit
    }

    /// 同意（ヨーロッパ向け）→ トラッキングの許可 → SDK を始める → 1 本読みこむ
    func prepare() async {
        if !started {
            started = true
            await requestConsent()
            guard ConsentInformation.shared.canRequestAds else { return }
            if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
                _ = await ATTrackingManager.requestTrackingAuthorization()
            }
            _ = await MobileAds.shared.start()
        }
        await load()
    }

    private func requestConsent() async {
        let params = RequestParameters()
        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: params)
            if let root = Self.rootViewController {
                try await ConsentForm.loadAndPresentIfRequired(from: root)
            }
        } catch {
            // 同意の画面が出せなくても、遊ぶのには困らない（広告が出ないだけ）
        }
    }

    private func loadInterstitial() async {
        guard interstitial == nil, let unit = interstitialUnitID, ConsentInformation.shared.canRequestAds else { return }
        if let loaded = try? await InterstitialAd.load(with: unit, request: Request()) {
            loaded.fullScreenContentDelegate = self
            interstitial = loaded
        }
    }

    func showInterstitial() async {
        guard let ad = interstitial, let root = Self.rootViewController else {
            Task { await loadInterstitial() }
            return
        }
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            dismissed = c
            ad.present(from: root)
        }
        interstitial = nil
        Task { await loadInterstitial() }
    }

    private func load() async {
        await loadInterstitial()
        guard ad == nil, ConsentInformation.shared.canRequestAds else { return }
        do {
            let loaded = try await RewardedAd.load(with: unitID, request: Request())
            loaded.fullScreenContentDelegate = self
            ad = loaded
            isReady = true
        } catch {
            isReady = false
        }
    }

    func show() async -> Bool {
        guard let ad, let root = Self.rootViewController else { return false }
        var earned = false
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            dismissed = c
            ad.present(from: root) { earned = true }
        }
        self.ad = nil
        isReady = false
        Task { await load() }
        return earned
    }

    nonisolated func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        Task { @MainActor in self.finish() }
    }

    nonisolated func ad(_ ad: any FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: any Error) {
        Task { @MainActor in self.finish() }
    }

    private func finish() {
        dismissed?.resume()
        dismissed = nil
    }

    static var rootViewController: UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var vc = scene?.windows.first(where: \.isKeyWindow)?.rootViewController ?? scene?.windows.first?.rootViewController
        while let next = vc?.presentedViewController { vc = next }
        return vc
    }

    /// 同意をあとから変える（設定から）
    static func showPrivacyOptions() async {
        guard let root = rootViewController else { return }
        try? await ConsentForm.presentPrivacyOptionsForm(from: root)
    }

    static var needsPrivacyOptions: Bool {
        ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }
}
