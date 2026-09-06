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

    /// Oyuncu kimliğini RevenueCat müşterisine bağlar.
    ///
    /// `configure` uygulama açılışında çalışıyor ama İLK açılışta oyuncu
    /// kimliği henüz YOK: onu `PlayerStore` üretiyor ve o, AppDelegate'ten
    /// sonra kuruluyor. Sonuç, ilk açılışta anonim bir müşteri açılması ve
    /// panodaki kişinin Firestore'daki destekçi kaydıyla hiç eşleşmemesiydi;
    /// üstelik aynı kişi ikinci açılışta ikinci bir müşteri gibi görünüyordu.
    /// Kimlik belli olduğunda burası devreye giriyor.
    static func identify(playerID: String) async {
        #if canImport(RevenueCat)
        guard Purchases.isConfigured, !playerID.isEmpty,
              Purchases.shared.appUserID != playerID else { return }
        _ = try? await Purchases.shared.logIn(playerID)
        leaderboardLog("REVENUECAT: kimlik bağlandı (\(playerID))")
        #endif
    }

    /// Cihazda ZATEN olan satın almaları RevenueCat'e bir kez gönderir.
    ///
    /// Gözlemci kipi yalnızca kurulumdan SONRA olanı görüyor; bugüne kadarki
    /// satışlar panoda hiç yok. Bu çağrı cihazın makbuzunu okuyup gönderiyor,
    /// yani premium'u olan biri güncellemeyi açtığında hakkıyla birlikte
    /// beliriyor. Sınırı açık: yalnızca uygulamayı tekrar AÇANLAR gelir,
    /// silmiş olanlar gelmez; tüketilmiş bahşişler de makbuzda kalmadığı
    /// için gelmez.
    ///
    /// KURULUM BAŞINA BİR KEZ — RevenueCat her açılışta çağırmamayı açıkça
    /// söylüyor, çağrı makbuz doğrulaması yapıyor. Bayrak ancak çağrı
    /// başarılı olursa yazılıyor: çevrimdışı bir ilk açılış tek şansı
    /// harcamasın.
    static func syncExistingPurchasesOnce() async {
        #if canImport(RevenueCat)
        let key = "lumo.revenuecat.synced"
        guard Purchases.isConfigured,
              !UserDefaults.standard.bool(forKey: key) else { return }
        guard (try? await Purchases.shared.syncPurchases()) != nil else { return }
        UserDefaults.standard.set(true, forKey: key)
        leaderboardLog("REVENUECAT: cihazdaki satın almalar bir kez eşitlendi")
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
