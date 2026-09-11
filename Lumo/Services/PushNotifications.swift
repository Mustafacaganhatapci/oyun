import Foundation
import UIKit
import UserNotifications
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

/// Uzaktan bildirim — "yeni sürüm çıktı", "hafta bitmek üzere" gibi haberler
/// için. Firebase Cloud Messaging'in "konu" (topic) yayını kullanılıyor:
/// sunucu yazmaya gerek yok, Firebase konsolundan tek bir gönderi herkese
/// ulaşıyor.
///
/// İKİ ŞEY BİLEREK BÖYLE:
///
///  1. iOS İZİN KUTUSU AÇILIŞTA ÇIKMIYOR — bizim kartımız çıkıyor.
///     Oyunu ilk kez açan birinin karşısına çıkan sistem kutusu çoğunlukla
///     reddediliyor ve iOS bir daha ASLA sormuyor; o kutu tek kerelik ve
///     geri dönüşsüz. Bu yüzden önüne kendi sorumuz konuyor
///     (`NotificationOptInView`): "şimdi değil" diyene hiçbir şey
///     kaybettirmiyoruz, izin hâlâ sorulmamış kalıyor. Yalnızca "Aç"
///     denince gerçek kutu çıkıyor. Apple da tanıtım amaçlı bildirim için
///     açık rıza şart koşuyor (4.5.4); kart o rızanın ta kendisi ve
///     ayarlardaki anahtarın varsayılanı kapalı.
///  2. FirebaseMessaging paketi projede yoksa dosya yine derleniyor,
///     `isAvailable` false dönüyor ve ayarlarda satır hiç görünmüyor.
///     Projedeki Firestore/Auth kalıbının aynısı.
@MainActor
final class PushManager: NSObject, ObservableObject {
    static let shared = PushManager()

    /// Oyuncu bildirimleri açtı mı (cihazda saklanır)
    @Published private(set) var isEnabled: Bool
    /// iOS izni reddedildi: ayarlarda "iOS Ayarları'ndan aç" uyarısı çıkar
    @Published private(set) var isDenied = false
    /// İzin kutusu ekrandayken
    @Published private(set) var isWorking = false

    /// iOS izni HENÜZ sorulmamış (`notDetermined`).
    ///
    /// İlk açılış kartı buna bakıyor: kabul ya da ret etmiş birine aynı soruyu
    /// bir daha sormak yalnızca rahatsız eder. Varsayılan false — gerçek değer
    /// `refreshUndecided()` ile geliyor, yani kart ancak durum okunduktan sonra
    /// çıkabiliyor. Ters varsayım kartı bir an için yanlışlıkla gösterirdi.
    @Published private(set) var isUndecided = false

    /// Bildirim özelliği HER ZAMAN var.
    ///
    /// Eskiden FirebaseMessaging paketi yoksa false dönüyordu ve ayarlardaki
    /// satır hiç görünmüyordu — yani paket eklenene kadar kimse bildirim
    /// açamıyordu. Oysa asıl işi yapan iki hatırlatma (haftalık yarış ve yeni
    /// sürüm) YEREL bildirim: ne sunucu ister ne APNs anahtarı, izin verilir
    /// verilmez çalışır. FCM yalnızca "herkese tek seferlik duyuru" için
    /// gerekli ve o da paket varsa devreye giriyor.
    static var isAvailable: Bool { true }

    /// Uzaktan yayın (konu aboneliği) yalnızca paket varsa
    static var canReceiveBroadcast: Bool {
        #if canImport(FirebaseMessaging)
        return true
        #else
        return false
        #endif
    }

    private static let enabledKey = "lumo.push.enabled"
    /// Konsoldan "Send to topic: all" ile herkese gönderilir
    private static let topic = "all"

    /// Uygulamanın konuştuğu diller
    private static let languages = ["tr", "en", "de", "es", "fr", "ja"]

    /// Cihazın dil konusu — `all_tr`, `all_en` gibi.
    ///
    /// Konu yayını TEK metin gönderiyor ve cihazın diline göre değişmiyor.
    /// Firebase'in dile göre hedeflemesi ise Google Analytics istiyor, o da
    /// bu projede bağlı değil. Çözüm konunun kendisinde: her cihaz hem
    /// `all`'a hem kendi dilinin konusuna abone oluyor. Türkçe metni
    /// `all_tr`'ye, İngilizceyi `all_en`'e gönderiyorsun; iki dilde iki
    /// kampanya, tek metinle herkesi zorlamak yok.
    ///
    /// Desteklenmeyen bir dilde açılan cihaz `all_en`'e düşüyor: uygulamanın
    /// kendisi de o durumda İngilizce açılıyor.
    private static var languageTopic: String {
        let code = Locale.preferredLanguages.first?
            .split(separator: "-").first.map(String.init) ?? "en"
        return "all_" + (languages.contains(code) ? code : "en")
    }

    private override init() {
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        super.init()
    }

    /// Uygulama açılışında çağrılır. İZİN İSTEMEZ; yalnızca daha önce açmış
    /// olanın aboneliğini tazeler. Oyuncu iOS Ayarları'ndan bildirimleri
    /// kapatmışsa anahtarı da kapalıya çeker — açık görünüp hiçbir şey
    /// gelmemesi, kapalı görünmesinden daha kafa karıştırıcı.
    func restoreIfEnabled() {
        guard isEnabled else { return }
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard settings.authorizationStatus == .authorized ||
                  settings.authorizationStatus == .provisional else {
                self.isEnabled = false
                UserDefaults.standard.set(false, forKey: Self.enabledKey)
                self.cancelLocalReminders()
                return
            }
            UIApplication.shared.registerForRemoteNotifications()
            self.subscribe()
            // Hatırlatma her açılışta yeniden kuruluyor: metni ya da saati
            // değişmiş olabilir ve `UNCalendarNotificationTrigger` aynı
            // kimlikle sessizce üzerine yazılıyor.
            self.scheduleWeeklyRaceReminder()
        }
    }

    /// iOS izin durumunu okur. İzin İSTEMEZ — yalnızca bakar.
    func refreshUndecided() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isUndecided = settings.authorizationStatus == .notDetermined
        if settings.authorizationStatus == .denied { isDenied = true }
    }

    /// Ayarlardaki anahtar buraya bağlı
    func setEnabled(_ on: Bool) async {
        guard Self.isAvailable, !isWorking else { return }
        guard on else {
            unsubscribe()
            cancelLocalReminders()
            isEnabled = false
            UserDefaults.standard.set(false, forKey: Self.enabledKey)
            return
        }

        isWorking = true
        defer { isWorking = false }

        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        // Kutu bir kez çıktı: karar ne olursa olsun artık "sorulmamış" değil
        isUndecided = false
        guard granted else {
            // Reddedildi: iOS bir daha sormaz, yol Ayarlar'dan geçer
            isDenied = true
            isEnabled = false
            UserDefaults.standard.set(false, forKey: Self.enabledKey)
            return
        }

        isDenied = false
        UIApplication.shared.registerForRemoteNotifications()
        subscribe()
        scheduleWeeklyRaceReminder()
        isEnabled = true
        UserDefaults.standard.set(true, forKey: Self.enabledKey)
    }

    // MARK: Yerel hatırlatmalar
    //
    // Sunucu da APNs anahtarı da gerektirmiyorlar; izin verildiği an
    // çalışıyorlar. İkisi de "üstten düşen" bildirim.

    private static let raceID = "lumo.reminder.race"
    private static let updateID = "lumo.reminder.update"

    /// Haftalık yarış hatırlatması: sıralama sıfırlanmadan BİR GÜN önce,
    /// her hafta aynı gün ve saatte.
    ///
    /// Hafta tam yedi gün olduğu için sıfırlanma anının haftanın günü ve
    /// saati hiç kaymıyor; tekrarlayan takvim tetiği bu yüzden doğru
    /// çalışıyor ve bir daha kurulmasına gerek kalmıyor.
    func scheduleWeeklyRaceReminder() {
        let reset = LeaderboardService.nextReset()
        let fire = reset.addingTimeInterval(-24 * 60 * 60)
        var parts = Calendar.current.dateComponents([.weekday, .hour, .minute], from: fire)
        // Gece yarısına denk gelen bir bildirim kimseyi yakalamıyor; o saatte
        // düşerse akşam yediye çekiliyor. Gün aynı kalıyor, yarış hâlâ açık.
        if let hour = parts.hour, hour < 9 || hour > 22 {
            parts.hour = 19
            parts.minute = 0
        }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "This week's race closes tomorrow")
        content.body = String(localized: "One run is enough to take a place on the board.")
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: Self.raceID,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: true)
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Yeni sürüm hatırlatması.
    ///
    /// Güncelleme haberi Firestore'daki duyuru belgesinden geliyor; oyunu
    /// AÇAN kişi onu menüde zaten kart olarak görüyor. Bu çağrı aynı haberi
    /// birkaç saat sonra bildirim olarak da düşürüyor — çünkü kartı görüp
    /// "sonra" diyen kişiye ikinci bir dokunuş gerekiyor ve bunun için
    /// sunucu kurmaya değmez.
    ///
    /// Duyuru artık geçerli değilse (güncellendi ya da kapatıldı) bekleyen
    /// bildirim iptal ediliyor: güncellemeyi almış birine "güncelle" demek,
    /// hiç dememekten kötü.
    func syncUpdateReminder(title: String?, body: String?) {
        let center = UNUserNotificationCenter.current()
        guard isEnabled, let title, let body, !title.isEmpty else {
            center.removePendingNotificationRequests(withIdentifiers: [Self.updateID])
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: Self.updateID,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 4 * 60 * 60, repeats: false)
        )
        center.add(request)
    }

    private func cancelLocalReminders() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.raceID, Self.updateID])
    }

    /// İzin reddedilmişse oyuncuyu iOS Ayarları'na götürür
    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func subscribe() {
        #if canImport(FirebaseMessaging)
        Messaging.messaging().subscribe(toTopic: Self.topic)
        Messaging.messaging().subscribe(toTopic: Self.languageTopic)
        logFCMToken()
        #endif
    }

    /// FCM belirtecini günlüğe yazar — TEK bir cihaza test göndermek için.
    ///
    /// Konu yayını geri alınamıyor: yanlış yazılmış bir cümleyi `all`'a
    /// gönderdikten sonra düzeltmenin yolu yok, ikinci bir bildirim
    /// göndermek de ilkini silmiyor. Bu belirteç Firebase konsolundaki
    /// "Send test message" kutusuna yapıştırılınca bildirim yalnızca o
    /// telefona düşüyor; metni gerçek kilit ekranında görüp beğendikten
    /// sonra herkese gönderiliyor.
    ///
    /// Belirteç kişiyi değil KURULUMU adresliyor; uygulama silinip yeniden
    /// kurulunca değişiyor. Yine de yalnızca hata ayıklama derlemesinde
    /// yazılıyor: yayındaki bir cihazın günlüğünde durmasına gerek yok.
    private func logFCMToken() {
        #if DEBUG && canImport(FirebaseMessaging)
        Messaging.messaging().token { token, error in
            if let token {
                leaderboardLog("FCM BELİRTECİ (tek cihaz testi için): \(token)")
            } else if let error {
                leaderboardLog("FCM belirteci alınamadı: \(error.localizedDescription)",
                               isError: true)
            }
        }
        #endif
    }

    private func unsubscribe() {
        #if canImport(FirebaseMessaging)
        Messaging.messaging().unsubscribe(fromTopic: Self.topic)
        // Dil konularının HEPSİNDEN çıkılıyor, yalnızca şu ankinden değil:
        // oyuncu telefonun dilini değiştirmiş olabilir ve geride kalan bir
        // abonelik, bildirimleri kapatmış birine bildirim göndermek demek.
        for code in Self.languages {
            Messaging.messaging().unsubscribe(fromTopic: "all_" + code)
        }
        #endif
    }

    /// APNs belirtecini FCM'e bağlar — AppDelegate'ten çağrılır. Bu olmadan
    /// konu aboneliği sessizce çalışmıyor.
    nonisolated func handleAPNsToken(_ deviceToken: Data) {
        #if canImport(FirebaseMessaging)
        Messaging.messaging().apnsToken = deviceToken
        #endif
    }
}
