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
///  1. İzin AÇILIŞTA İSTENMİYOR. Oyuncu ayarlardan açtığı an isteniyor.
///     Oyunu ilk kez açan birinin karşısına çıkan izin kutusu çoğunlukla
///     reddediliyor ve bir daha sorulamıyor; üstelik Apple, tanıtım amaçlı
///     bildirimin açık rızayla gönderilmesini şart koşuyor. Ayarlardaki
///     anahtar o rızanın ta kendisi ve varsayılanı kapalı.
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
        #endif
    }

    private func unsubscribe() {
        #if canImport(FirebaseMessaging)
        Messaging.messaging().unsubscribe(fromTopic: Self.topic)
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
