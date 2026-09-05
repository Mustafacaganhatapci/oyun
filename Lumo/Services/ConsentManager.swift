import Foundation
import SwiftUI
import UIKit
import os.log

#if canImport(UserMessagingPlatform)
import UserMessagingPlatform
#endif

#if canImport(AppTrackingTransparency)
import AppTrackingTransparency
#endif

/// Reklam izinleri — iki ayrı ve sıralı adım:
///
///  1. **UMP (Google User Messaging Platform)**: Avrupa'daki kullanıcılara
///     GDPR onay ekranını gösterir. Bu olmadan AdMob, EEA kullanıcılarına
///     reklam sunmayı kısıtlar ve politika ihlali sayar.
///  2. **ATT (App Tracking Transparency)**: IDFA izni. İzin verilirse
///     reklamlar kişiselleştirilir ve eCPM belirgin şekilde yükselir.
///
/// Sıra önemlidir: Google, ATT isteminin UMP akışından SONRA gösterilmesini
/// şart koşar; ters sırada iki pencere üst üste binebilir.
///
/// Premium kullanıcıya hiç reklam gösterilmediği için ikisi de sorulmaz.
@MainActor
final class ConsentManager: ObservableObject {

    /// İzin akışı tamamlandı mı (reklam yüklemeye başlanabilir)
    @Published private(set) var finished = false

    private var started = false

    /// Uygulama açılışında bir kez çağrılır. Premium'da tamamen atlanır.
    func requestIfNeeded(isPremium: Bool) {
        guard !started else { return }
        started = true
        guard !isPremium else { finished = true; return }

        gatherConsent { [weak self] in
            self?.requestTracking { self?.finished = true }
        }
    }

    // MARK: 1. adım — GDPR / UMP

    private func gatherConsent(then next: @escaping () -> Void) {
        #if canImport(UserMessagingPlatform)
        let params = RequestParameters()
        params.isTaggedForUnderAgeOfConsent = false

        ConsentInformation.shared.requestConsentInfoUpdate(with: params) { error in
            if let error {
                os_log(.error, "UMP bilgi güncelleme hatası: %{public}@", error.localizedDescription)
                next()
                return
            }
            // UMP geri çağrıyı ana iş parçacığında veriyor; ekranı ve formu
            // ancak orada isteyebiliriz.
            MainActor.assumeIsolated {
                guard let root = Self.topViewController() else { next(); return }
                ConsentForm.loadAndPresentIfRequired(from: root) { formError in
                    if let formError {
                        os_log(.error, "UMP form hatası: %{public}@", formError.localizedDescription)
                    }
                    next()
                }
            }
        }
        #else
        next()
        #endif
    }

    // MARK: 2. adım — ATT (IDFA)

    private func requestTracking(then done: @escaping () -> Void) {
        #if canImport(AppTrackingTransparency)
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            done()
            return
        }
        // Uygulama yeni öne geldiyse istem yutulabiliyor; kısa bir gecikme
        // pencerenin güvenilir şekilde görünmesini sağlıyor.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            ATTrackingManager.requestTrackingAuthorization { _ in
                DispatchQueue.main.async { done() }
            }
        }
        #else
        done()
        #endif
    }

    /// UMP formunun sunulacağı en üstteki view controller
    private static func topViewController() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first
        var top = root
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
