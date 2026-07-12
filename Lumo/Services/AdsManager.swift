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

    private var completionsSinceAd = 0
    private var endlessRunsSinceAd = 0
    private var provider: InterstitialProvider

    init() {
        #if canImport(GoogleMobileAds)
        provider = AdMobProvider()
        #else
        provider = NoOpProvider()
        #endif
        provider.preload()
    }

    /// Bölüm tamamlandığında çağrılır. Reklam gösterilecekse true döner
    /// ve reklam kapandığında `completion` çalışır.
    func levelCompleted(level: Int, isPremium: Bool, completion: @escaping () -> Void) -> Bool {
        #if DEBUG
        // DEBUG: test için 2. bölümden itibaren her bölüm sonunda reklam —
        // öğretici ve 1. bölüm deneyimi temiz kalır. Yayın kuralları ayrıdır.
        guard level >= 2 else {
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
        // DEBUG: her sonsuz mod sonunda test reklamı
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

    // Yer tutucu kapatma (yalnızca DEBUG stub akışı)
    private var placeholderCompletion: (() -> Void)?
    func dismissPlaceholder() {
        showingPlaceholder = false
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

final class AdMobProvider: NSObject, InterstitialProvider, FullScreenContentDelegate {
    // Google'ın resmi TEST kimliği — yayına çıkmadan önce değiştirin!
    private let adUnitID = "ca-app-pub-3940256099942544/4411468910"
    private var interstitial: InterstitialAd?
    private var completion: (() -> Void)?
    private var startedSDK = false

    func preload() {
        if !startedSDK {
            startedSDK = true
            MobileAds.shared.start()
        }
        InterstitialAd.load(with: adUnitID, request: Request()) { [weak self] ad, _ in
            self?.interstitial = ad
            ad?.fullScreenContentDelegate = self
        }
    }

    func show(completion: @escaping () -> Void) -> Bool {
        guard let interstitial, let root = Self.topViewController() else { return false }
        self.completion = completion
        self.interstitial = nil
        // Bir sonraki runloop'ta sun: SwiftUI geçiş animasyonu ortasında
        // sunum yapılırsa reklam boş/gri kalabiliyor
        DispatchQueue.main.async {
            interstitial.present(from: root)
        }
        return true
    }

    /// En üstteki (sunum zincirinin sonundaki) view controller — reklam
    /// buradan sunulmazsa boş gri ekran görülebilir
    private static func topViewController() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first
        var top = root
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        completion?()
        completion = nil
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        completion?()
        completion = nil
    }
}
#endif
