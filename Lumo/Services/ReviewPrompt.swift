import Foundation
import StoreKit
import UIKit

/// App Store değerlendirme istemi.
///
/// Apple istemi yılda en fazla 3 kez gösterir ve ne zaman göstereceğine kendi
/// karar verir; bizim işimiz yalnızca DOĞRU ANI seçmek. En iyi an oyuncunun
/// başarılı hissettiği andır — 3/3 yıldızla bir bölüm bitirdiği an gibi.
/// Kaybettiği ya da reklam izlediği anda asla sormayız.
enum ReviewPrompt {

    /// İstemden önce tamamlanması gereken bölüm sayısı — yeni oyuncuya sorulmaz
    private static let minimumCompletions = 8
    /// Aynı sürümde bir kereden fazla denemeyiz
    private static let lastVersionKey = "lumo.review.lastPromptedVersion"

    /// Oyuncu 3/3 yıldızla bir bölüm bitirdiğinde çağrılır.
    static func requestAfterGreatRun(completedLevels: Int) {
        guard completedLevels >= minimumCompletions else { return }

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: lastVersionKey) != version else { return }
        defaults.set(version, forKey: lastVersionKey)

        // Kutlama animasyonu otursun; istem oyunun üstüne aniden binmesin
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
            AppStore.requestReview(in: scene)
        }
    }
}
