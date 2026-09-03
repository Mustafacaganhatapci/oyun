import Foundation
import UIKit

/// Ana menüde gösterilen duyuru kartı — "yeni sürüm çıktı", "bu hafta çift
/// yıldız" gibi.
///
/// Firestore'daki `config/announcement` belgesinden okunur, yani yeni bir
/// derleme yüklemeden duyuru yayınlanabilir. Bildirim göndermenin aksine
/// hiçbir Apple kurulumu (APNs anahtarı, izin ekranı) gerektirmiyor; buna
/// karşılık yalnızca oyunu AÇAN kişiye ulaşır. İkisi birbirinin yerine değil,
/// yanına: bildirim uzaktakini çağırır, bu kart geleni karşılar.
///
/// Belge alanları:
///   enabled     Bool    — kapalıysa hiçbir şey gösterilmez
///   id          String  — "kapat" takibi bunun üzerinden; metni değiştirip
///                         id'yi de değiştirirsen kapatanlar tekrar görür
///   title       String  — İngilizce taban
///   body        String
///   title_tr / body_tr / title_de / ... — dile göre karşılık (varsa)
///   minVersion  String  — "2.1". Uygulama bu sürümdeyse ya da üstündeyse
///                         duyuru GÖSTERİLMEZ. Güncelleme duyurusu için:
///                         güncellemeyi almış olan kişi çağrıyı görmemeli.
///   appStoreID  String  — düğme App Store'da bu kimliği açar; yoksa düğme yok
@MainActor
final class Announcement: ObservableObject {
    static let shared = Announcement()

    struct Item: Equatable {
        let id: String
        let title: String
        let body: String
        let appStoreID: String?
    }

    @Published private(set) var current: Item?

    private var didLoad = false
    private static func dismissKey(_ id: String) -> String { "lumo.announcement.seen.\(id)" }

    /// Uygulamanın kendi sürümü ("2.0")
    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    private init() {}

    /// Ana menü açılınca çağrılır. Oturumda bir kez okur — duyuru her açılışta
    /// yeniden indirilecek kadar önemli değil, ama uygulama yeniden başlarsa
    /// tazelenir.
    func refreshIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        #if canImport(FirebaseCore)
        guard let raw = await FirebaseBridge.fetchAnnouncement() else { return }
        current = Self.resolve(raw, appVersion: Self.appVersion,
                               language: Locale.preferredLanguages.first ?? "en")
        #endif
    }

    /// Ham alanlardan gösterilecek duyuruyu çıkarır. Saf fonksiyon: sürüm
    /// karşılaştırması ve dil seçimi Firebase'e bağlanmadan da denenebilsin.
    static func resolve(_ data: [String: Any], appVersion: String,
                        language: String) -> Item? {
        guard data["enabled"] as? Bool ?? true else { return nil }
        guard let id = data["id"] as? String, !id.isEmpty else { return nil }
        guard !UserDefaults.standard.bool(forKey: dismissKey(id)) else { return nil }

        // Güncelleme çağrısı: hedeflenen sürüme ulaşmış olana gösterme
        if let minVersion = data["minVersion"] as? String, !minVersion.isEmpty,
           compare(appVersion, minVersion) >= 0 { return nil }

        // Dil kodu "tr-TR" gelir; ilk parçası yeter
        let lang = language.split(separator: "-").first.map(String.init) ?? "en"
        func field(_ name: String) -> String? {
            (data["\(name)_\(lang)"] as? String) ?? (data[name] as? String)
        }
        guard let title = field("title"), !title.isEmpty,
              let body = field("body"), !body.isEmpty else { return nil }

        let appStoreID = (data["appStoreID"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        return Item(id: id, title: title, body: body, appStoreID: appStoreID)
    }

    /// "2.10" > "2.9" olmalı: parça parça SAYI karşılaştırması, metin değil.
    /// Düz string karşılaştırması "2.10" < "2.9" derdi.
    static func compare(_ a: String, _ b: String) -> Int {
        let lhs = a.split(separator: ".").map { Int($0) ?? 0 }
        let rhs = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(lhs.count, rhs.count) {
            let l = i < lhs.count ? lhs[i] : 0
            let r = i < rhs.count ? rhs[i] : 0
            if l != r { return l < r ? -1 : 1 }
        }
        return 0
    }

    func dismiss() {
        guard let item = current else { return }
        UserDefaults.standard.set(true, forKey: Self.dismissKey(item.id))
        current = nil
    }

    /// App Store'daki sayfayı açar. `itms-apps` doğrudan App Store uygulamasına
    /// gider; https bağlantısı önce Safari'yi açıp oradan sıçrıyor.
    func openStore() {
        guard let id = current?.appStoreID,
              let url = URL(string: "itms-apps://itunes.apple.com/app/id\(id)") else { return }
        UIApplication.shared.open(url)
    }
}
