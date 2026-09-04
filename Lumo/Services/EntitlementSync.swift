import Foundation

/// Bahşiş ve kodla açılan premium'un cihazlar arasında taşınması.
///
/// SORUN: bahşişler TÜKETİLEBİLİR (consumable) ürün. Apple tüketilebilirleri
/// geri yüklemez — "Satın Almaları Geri Yükle" onları getirmez, çünkü mağaza
/// açısından bir kez tüketilmiş bir maldır. Premium'u bahşiş karşılığında
/// veriyoruz, dolayısıyla telefon değiştiren bir destekçi parasını ödediği
/// şeyi kaybediyordu. Aynısı tanıdık kodları için de geçerli: kod bir
/// cihazda girilmiş oluyor, diğerinde yok.
///
/// ÇÖZÜM: hak, iCloud anahtar-değer deposunda tutuluyor. Aynı Apple kimliğine
/// giren her cihazda kendiliğinden beliriyor; sunucu, hesap, giriş ekranı
/// gerekmiyor. Kullanıcıdan hiçbir şey istemiyoruz.
///
/// XCODE'DA GEREKEN: hedefe **iCloud** yeteneği eklenmeli ve içinde
/// **Key-value storage** işaretli olmalı. O kutu işaretli değilse
/// `NSUbiquitousKeyValueStore` hata vermeden hiçbir şey yapmaz — yazar gibi
/// görünür, okur gibi görünür, ama hiçbir cihaza gitmez. Bu dosyanın
/// çalıştığını doğrulamanın tek yolu iki gerçek cihazda denemek.
///
/// SINIRI: iCloud Drive kapalıysa senkron olmaz. O yüzden yerel kopya
/// (UserDefaults) hâlâ duruyor ve ikisinden HANGİSİ evet derse hak veriliyor —
/// bir hakkı yanlışlıkla geri almak, fazladan vermekten çok daha kötü.
@MainActor
final class EntitlementSync {
    static let shared = EntitlementSync()

    private let cloud = NSUbiquitousKeyValueStore.default
    private static let supporterKey = "lumo.cloud.supporter"
    private static let promoKey = "lumo.cloud.promo"

    private init() {}

    var isSupporter: Bool { cloud.bool(forKey: Self.supporterKey) }
    var isPromoGranted: Bool { cloud.bool(forKey: Self.promoKey) }

    func markSupporter() { set(Self.supporterKey) }
    func markPromoGranted() { set(Self.promoKey) }

    private func set(_ key: String) {
        guard !cloud.bool(forKey: key) else { return }
        cloud.set(true, forKey: key)
        cloud.synchronize()
    }

    /// Başka bir cihazda verilen hak buraya düştüğünde haber verir.
    /// `synchronize()` yalnızca "sıradaki fırsatta yolla" demek; iCloud
    /// kendi zamanlamasıyla çalışıyor, o yüzden dinlemek şart.
    func startObserving(_ onChange: @escaping () -> Void) {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud, queue: .main
        ) { _ in
            MainActor.assumeIsolated { onChange() }
        }
        cloud.synchronize()
    }
}
