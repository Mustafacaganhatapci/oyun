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

    /// Paket eklenmediyse özellik yok sayılır
    static var isAvailable: Bool {
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
        guard Self.isAvailable, isEnabled else { return }
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard settings.authorizationStatus == .authorized ||
                  settings.authorizationStatus == .provisional else {
                self.isEnabled = false
                UserDefaults.standard.set(false, forKey: Self.enabledKey)
                return
            }
            UIApplication.shared.registerForRemoteNotifications()
            self.subscribe()
        }
    }

    /// Ayarlardaki anahtar buraya bağlı
    func setEnabled(_ on: Bool) async {
        guard Self.isAvailable, !isWorking else { return }
        guard on else {
            unsubscribe()
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
        isEnabled = true
        UserDefaults.standard.set(true, forKey: Self.enabledKey)
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
