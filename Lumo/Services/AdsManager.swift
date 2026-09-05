import Foundation
import SwiftUI

/// Reklam politikası — oyuncuya saygılı, net kurallar:
///  • İlk 10 bölümde ASLA reklam gösterilmez (yeni oyuncu deneyimi kutsaldır).
///  • 11. bölümden itibaren: her 2 bölüm tamamlamada 1 geçiş reklamı.
///  • Sonsuz modda: her 3 oyun sonunda 1 geçiş reklamı.
///  • Premium alındıysa hiçbir zaman reklam gösterilmez.
///  • Banner reklam yoktur — oyun alanı her zaman temizdir.
///
/// Gerçek reklam SDK'sı (Google AdMob) projeye eklendiğinde `AdMobProvider`
/// otomatik derlenir (aşağıdaki canImport bloğu). SDK yokken `NoOpProvider`
/// kullanılır: DEBUG'da akışı test etmek için yer tutucu gösterir,
/// RELEASE'te hiçbir şey göstermez.
@MainActor
final class AdsManager: ObservableObject {

    static let interstitialEveryNCompletions = 2
    static let interstitialEveryNEndlessRuns = 3

    /// SwiftUI bu yayına abone olur; true iken yer tutucu reklam tam ekran gösterilir (yalnızca DEBUG stub).
    @Published var showingPlaceholder = false

    /// Reklam kapandıktan sonra ara sıra (her 3 reklamda bir) nazik bir
    /// hatırlatma çıkar; sırayla biri Premium, biri "Destek Ol" (bahşiş).
    enum Nudge { case premium, support }
    @Published var nudge: Nudge?
    private static let nudgeEveryNAds = 3
    private var adsShownCount = 0
    private var nudgeShowsSupport = false   // her seferinde değişir (sıra ile)

    private var completionsSinceAd = 0
    private var endlessRunsSinceAd = 0
    private var provider: InterstitialProvider
    private var rewardedProvider: RewardedProvider

    /// Ödüllü reklam hazır mı (buton pasifleştirmek için)
    @Published private(set) var rewardedReady = false

    /// Ödüllü reklam yer tutucusu (yalnızca DEBUG stub akışı)
    @Published var showingRewardedPlaceholder = false

    init() {
        #if canImport(GoogleMobileAds)
        provider = AdMobProvider()
        rewardedProvider = AdMobRewardedProvider()
        #else
        provider = NoOpProvider()
        rewardedProvider = NoOpRewardedProvider()
        #endif
        provider.preload()
        rewardedProvider.preload { [weak self] ready in
            self?.rewardedReady = ready
        }
    }

    /// Ödüllü reklam sonucu — düğmenin sessizce hiçbir şey yapmaması yerine
    /// oyuncuya ne olduğu söylenir.
    enum RewardNotice: Equatable { case unavailable, notEarned }
    @Published var rewardNotice: RewardNotice?

    /// Ödüllü reklam gösterir. Kullanıcı ödülü hak ettiyse `granted: true`.
    /// Reklam yüklenememişse hiç istem çıkmaz; durum `rewardNotice` ile bildirilir.
    func showRewarded(granted: @escaping (Bool) -> Void) {
        rewardNotice = nil
        let shown = rewardedProvider.show { [weak self] earned in
            self?.rewardedProvider.preload { ready in self?.rewardedReady = ready }
            if !earned { self?.rewardNotice = .notEarned }
            granted(earned)
        }
        guard !shown else { return }
        #if DEBUG
        showingRewardedPlaceholder = true
        rewardedPlaceholderCompletion = granted
        #else
        // Elde reklam yok: yeni bir tane iste ve oyuncuya durumu bildir
        rewardedProvider.preload { [weak self] ready in self?.rewardedReady = ready }
        rewardNotice = .unavailable
        granted(false)
        #endif
    }

    func dismissRewardNotice() { rewardNotice = nil }

    private var rewardedPlaceholderCompletion: ((Bool) -> Void)?
    func dismissRewardedPlaceholder(granted: Bool) {
        showingRewardedPlaceholder = false
        rewardedPlaceholderCompletion?(granted)
        rewardedPlaceholderCompletion = nil
    }

    /// Bölüm tamamlandığında çağrılır. Reklam gösterilecekse true döner
    /// ve reklam kapandığında `completion` çalışır.
    func levelCompleted(level: Int, isPremium: Bool, completion: @escaping () -> Void) -> Bool {
        #if DEBUG
        // İlk 10 bölüm (adFreeLevels) HER ZAMAN reklamsızdır — yeni oyuncu
        // deneyimi kutsaldır. Premium'da da hiçbir zaman reklam yok.
        // (DEBUG'da 11+ bölümlerde her tamamlamada test reklamı gösterilir.)
        guard !isPremium, level > LevelLibrary.adFreeLevels else {
            completion()
            return false
        }
        return show(completion: completion)
        #else
        guard !isPremium, level > LevelLibrary.adFreeLevels else {
            completion()
            return false
        }
        completionsSinceAd += 1
        guard completionsSinceAd >= Self.interstitialEveryNCompletions else {
            completion()
            return false
        }
        completionsSinceAd = 0
        return show(completion: completion)
        #endif
    }

    /// Sonsuz mod oyunu bittiğinde çağrılır.
    func endlessEnded(isPremium: Bool, endlessUnlocked: Bool, completion: @escaping () -> Void) -> Bool {
        #if DEBUG
        // DEBUG: her sonsuz mod sonunda test reklamı — Premium'da hiçbir zaman.
        guard !isPremium else {
            completion()
            return false
        }
        return show(completion: completion)
        #else
        guard !isPremium, endlessUnlocked else {
            completion()
            return false
        }
        endlessRunsSinceAd += 1
        guard endlessRunsSinceAd >= Self.interstitialEveryNEndlessRuns else {
            completion()
            return false
        }
        endlessRunsSinceAd = 0
        return show(completion: completion)
        #endif
    }

    private func show(completion: @escaping () -> Void) -> Bool {
        let shown = provider.show { [weak self] in
            self?.provider.preload()
            self?.adDismissed()
            completion()
        }
        if !shown {
            #if DEBUG
            // SDK yokken akışı görmek için yer tutucu göster
            showingPlaceholder = true
            placeholderCompletion = completion
            return true
            #else
            completion()
            return false
            #endif
        }
        return shown
    }

    /// Reklam kapandığında çağrılır: sayaç artar, her 3 reklamda bir
    /// hatırlatmayı tetikler (Premium ↔ Destek Ol sırayla).
    private func adDismissed() {
        adsShownCount += 1
        if adsShownCount % Self.nudgeEveryNAds == 0 {
            nudge = nudgeShowsSupport ? .support : .premium
            nudgeShowsSupport.toggle()
        }
    }

    func dismissNudge() { nudge = nil }

    // Yer tutucu kapatma (yalnızca DEBUG stub akışı)
    private var placeholderCompletion: (() -> Void)?
    func dismissPlaceholder() {
        showingPlaceholder = false
        adDismissed()
        placeholderCompletion?()
        placeholderCompletion = nil
    }
}

// MARK: - Sağlayıcı arayüzü

@MainActor
protocol InterstitialProvider {
    func preload()
    /// Reklamı gösterir; gösterilemiyorsa false döner. Kapanınca completion çağrılır.
    func show(completion: @escaping () -> Void) -> Bool
}

/// SDK'sız çalışan boş sağlayıcı.
final class NoOpProvider: InterstitialProvider {
    func preload() {}
    func show(completion: @escaping () -> Void) -> Bool { false }
}

@MainActor
protocol RewardedProvider {
    func preload(ready: @escaping (Bool) -> Void)
    /// Ödüllü reklamı gösterir; gösterilemiyorsa false döner.
    /// Kapanınca completion(ödül kazanıldı mı) çağrılır.
    func show(completion: @escaping (Bool) -> Void) -> Bool
}

final class NoOpRewardedProvider: RewardedProvider {
    func preload(ready: @escaping (Bool) -> Void) { ready(false) }
    func show(completion: @escaping (Bool) -> Void) -> Bool { false }
}

// MARK: - AdMob entegrasyonu (SDK 12.x API'si)
// Etkinleştirmek için:
//  1. Xcode > File > Add Package Dependencies…
//     https://github.com/googleads/swift-package-manager-google-mobile-ads
//  2. Info.plist'te GADApplicationIdentifier zaten test kimliğiyle ayarlı;
//     yayında kendi AdMob uygulama kimliğinizle değiştirin.
//  3. Aşağıdaki adUnitID Google'ın resmi test birimi; yayında kendi
//     geçiş reklamı birim kimliğinizle değiştirin.
#if canImport(GoogleMobileAds)
import GoogleMobileAds
import UIKit
import os.log

final class AdMobProvider: NSObject, InterstitialProvider, FullScreenContentDelegate {
    // DEBUG: Google'ın resmi TEST birimi — geliştirme build'inde GERÇEK reklam
    // gösterilmez; kendi reklamına tıklamak AdMob hesabını kapattırabilir.
    // RELEASE: gerçek geçiş reklamı birimi (App Store/TestFlight build'leri).
    #if DEBUG
    private let adUnitID = "ca-app-pub-3940256099942544/4411468910"
    #else
    private let adUnitID = "ca-app-pub-2696377554654488/4128883047"
    #endif
    private var interstitial: InterstitialAd?
    /// Sunulmakta olan reklam — kapanana kadar serbest bırakılmaz
    private var presenting: InterstitialAd?
    private var completion: (() -> Void)?
    private var startedSDK = false

    func preload() {
        // Info.plist'te GADApplicationIdentifier eksikse Google SDK'sı
        // start() çağrısında tüm uygulamayı çökertir (NSException fırlatır).
        // Bozuk/eski bir derleme (stale build) bu duruma düşerse reklamsız
        // devam etmek, uygulamayı tamamen çökertmekten her zaman evladır.
        guard Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") != nil else {
            return
        }
        if !startedSDK {
            startedSDK = true
            MobileAds.shared.start(completionHandler: nil)
        }
        InterstitialAd.load(with: adUnitID, request: Request()) { [weak self] ad, error in
            if let error {
                // Console.app'te "Orbeon" sürecine filtrelenip görülebilir —
                // reklam gelmeme sebebini (doldurulamadı/ağ/geçersiz istek) gösterir
                os_log(.error, "AdMob yükleme hatası: %{public}@", error.localizedDescription)
            }
            // Google bu geri çağrıyı ANA iş parçacığında veriyor; derleyiciye
            // bunu söylüyoruz. `Task { @MainActor }` ile hoplamak burada
            // çalışmaz: reklam nesnesi Sendable değil, aktör sınırını geçemez.
            MainActor.assumeIsolated {
                self?.interstitial = ad
                ad?.fullScreenContentDelegate = self
            }
        }
    }

    func show(completion: @escaping () -> Void) -> Bool {
        guard let ad = interstitial, let root = Self.topViewController() else { return false }
        self.completion = completion
        // Ödüllü reklamdakiyle aynı gerekçe: reklam kapanana kadar güçlü bir
        // referansla tutulur, yoksa sunum sırasında serbest kalıp kapanış
        // geri çağrısı hiç gelmeyebilir ve akış olduğu yerde takılır.
        interstitial = nil
        presenting = ad
        // Bir sonraki runloop'ta sun: SwiftUI geçiş animasyonu ortasında
        // sunum yapılırsa reklam boş/gri kalabiliyor
        DispatchQueue.main.async {
            ad.present(from: root)
        }
        return true
    }

    /// En üstteki (sunum zincirinin sonundaki) view controller — reklam
    /// buradan sunulmazsa boş gri ekran görülebilir
    static func topViewController() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first
        var top = root
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        presenting = nil
        completion?()
        completion = nil
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        presenting = nil
        completion?()
        completion = nil
    }
}

/// Ödüllü reklam — oyuncunun kendi isteğiyle izlediği tek reklam türü.
/// Ödül yalnızca reklam sonuna kadar izlenirse verilir.
final class AdMobRewardedProvider: NSObject, RewardedProvider, FullScreenContentDelegate {
    #if DEBUG
    private let adUnitID = "ca-app-pub-3940256099942544/1712485313"   // Google resmi test birimi
    #else
    private let adUnitID = "ca-app-pub-2696377554654488/9121540024"
    #endif
    private var rewarded: RewardedAd?
    /// Sunulmakta olan reklam — kapanana kadar serbest bırakılmaz
    private var presenting: RewardedAd?
    private var completion: ((Bool) -> Void)?
    private var earned = false
    private var startedSDK = false

    func preload(ready: @escaping (Bool) -> Void) {
        guard !adUnitID.isEmpty,
              Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") != nil else {
            ready(false)
            return
        }
        if !startedSDK {
            startedSDK = true
            MobileAds.shared.start(completionHandler: nil)
        }
        RewardedAd.load(with: adUnitID, request: Request()) { [weak self] ad, error in
            if let error {
                os_log(.error, "AdMob ödüllü yükleme hatası: %{public}@", error.localizedDescription)
            }
            // Geçiş reklamındakiyle aynı gerekçe: geri çağrı ana iş
            // parçacığında geliyor, reklam nesnesi Sendable değil.
            MainActor.assumeIsolated {
                self?.rewarded = ad
                ad?.fullScreenContentDelegate = self
                ready(ad != nil)
            }
        }
    }

    func show(completion: @escaping (Bool) -> Void) -> Bool {
        guard let ad = rewarded, let root = AdMobProvider.topViewController() else { return false }
        self.completion = completion
        self.earned = false
        // Reklam sunum boyunca BURADA canlı tutulur. Daha önce `rewarded` nil'e
        // çekilip nesne yalnızca aşağıdaki async bloğun yakalamasına bırakılıyordu;
        // blok çalışıp bittiğinde son güçlü referans da düşüyor ve reklam sunum
        // sırasında serbest kalabiliyordu. Ödül geri çağrısı reklam nesnesinin
        // üstünde durduğu için de ödül hiç verilmiyordu.
        rewarded = nil
        presenting = ad
        DispatchQueue.main.async {
            ad.present(from: root) { [weak self] in
                self?.earned = true
            }
        }
        return true
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        presenting = nil
        completion?(earned)
        completion = nil
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        presenting = nil
        completion?(false)
        completion = nil
    }
}
#endif
