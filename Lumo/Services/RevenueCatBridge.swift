import Foundation
import StoreKit
#if canImport(RevenueCat)
import RevenueCat
#endif

/// RevenueCat — GÖZLEMCİ kipinde.
///
/// Satın almaları hâlâ `StoreManager` yürütüyor: StoreKit 2 ile yazılmış,
/// çalışıyor, ve içinde yalnızca bize ait olan işler var (tanıdık kodları,
/// bahşişin premium açması, teşekkür kartı, iCloud yedeği). RevenueCat bunu
/// devralmıyor; yanında durup her satın almayı kendi tarafına kaydediyor.
///
/// Böyle olmasının sebebi: bugün RevenueCat'in vereceği tek şey pano ve
/// Android'e geçince ortak entitlement. İkisi de gözlemci kipiyle geliyor.
/// Para akışını çalışan bir koddan çıkarıp yenisine taşımanın karşılığı yok.
///
/// XCODE'DA GEREKEN: Package Dependencies → `https://github.com/RevenueCat/purchases-ios`
/// ekle, hedefe **RevenueCat** ürününü bağla. Paket yokken bu dosya derleniyor
/// ama hiçbir şey yapmıyor — projedeki Firebase kalıbının aynısı.
///
/// SÜRÜM NOTU: aşağıdaki çağrılar RevenueCat **5.x** API'sine göre yazıldı.
/// 4.x kurarsan gözlemci kipi `.with(observerMode: true)` oluyor ve
/// `recordPurchase` hiç yok — o durumda bu dosyadaki iki satırı değiştirmek
/// yeterli, başka hiçbir yere dokunmaya gerek kalmıyor.
enum RevenueCatBridge {

    /// Genel (public) anahtar. Gizli değil: yayınlanan her uygulamanın
    /// ikilisinin içinde zaten bulunuyor, istemciye gömülmek için tasarlandı.
    /// Gizli olan `sk_` ile başlayan anahtardır ve o buraya ASLA girmez.
    private static let publicKey = "appl_xAfNaNiwZKEUukiWnmmjbyAysPx"

    static var isAvailable: Bool {
        #if canImport(RevenueCat)
        return true
        #else
        return false
        #endif
    }

    /// Uygulama açılışında bir kez. `playerID` verilirse RevenueCat müşterisi
    /// bizim oyuncu kimliğimizle aynı olur — panoda gördüğün kişiyle
    /// Firestore'daki `supporters` kaydı aynı kimliği taşır, destekçiyi
    /// aramak iş olmaktan çıkar. Yoksa anonim kimlik kullanılır.
    static func configure(playerID: String?) {
        #if canImport(RevenueCat)
        var builder = Configuration.Builder(withAPIKey: publicKey)
            .with(purchasesAreCompletedBy: .myApp, storeKitVersion: .storeKit2)
        if let playerID, !playerID.isEmpty {
            builder = builder.with(appUserID: playerID)
        }
        Purchases.configure(with: builder.build())
        // Paketin gerçekten bağlı olduğunu görmenin en kısa yolu: çalıştır,
        // Xcode konsolunda "Orbeon" ile süz. Bu satır düşüyorsa bağlı.
        leaderboardLog("REVENUECAT: gözlemci kipinde kuruldu (kimlik: \(playerID ?? "anonim"))")
        #else
        leaderboardLog("REVENUECAT: paket projeye eklenmemiş — satın almalar kaydedilmiyor")
        #endif
    }

    /// Gözlemci kipinde satın almayı RevenueCat'e biz bildiriyoruz; SDK
    /// kuyruğu kendi dinlemiyor. Bildirmezsek pano boş kalır.
    ///
    /// Hata yutuluyor: kayıt tutulamadı diye oyuncunun satın alması
    /// geçersiz sayılamaz. Hakkı zaten StoreKit veriyor.
    static func record(_ result: Product.PurchaseResult) async {
        #if canImport(RevenueCat)
        _ = try? await Purchases.shared.recordPurchase(result)
        #endif
    }
}
