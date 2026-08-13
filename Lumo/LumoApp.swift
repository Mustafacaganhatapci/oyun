import SwiftUI
import UIKit

/// Firebase'in kendi hata mesajının önerdiği kanonik başlatma noktası.
/// Bir UIApplicationDelegate sağlamak, hem FirebaseApp.configure()'ı doğru
/// anda çağırır (I-COR000003 giderilir) hem de GoogleUtilities'in
/// "App Delegate does not conform to UIApplicationDelegate" uyarısını kaldırır.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        LeaderboardService.bootstrapFirebase()
        return true
    }
}

@main
struct LumoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var app = AppModel()
    @StateObject private var progress = ProgressStore()
    @StateObject private var settings = SettingsStore()
    @StateObject private var store = StoreManager()
    @StateObject private var ads = AdsManager()
    @StateObject private var player = PlayerStore()
    @StateObject private var leaderboard = LeaderboardService()
    @StateObject private var tutorial = TutorialStore()
    @StateObject private var daily = DailyRewardStore()
    @StateObject private var missions = MissionStore()
    @StateObject private var consent = ConsentManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .environmentObject(progress)
                .environmentObject(settings)
                .environmentObject(store)
                .environmentObject(ads)
                .environmentObject(player)
                .environmentObject(leaderboard)
                .environmentObject(tutorial)
                .environmentObject(daily)
                .environmentObject(missions)
                .preferredColorScheme(.dark)
                .persistentSystemOverlays(.hidden)
                .onAppear {
                    AudioEngine.shared.startIfNeeded()
                    leaderboard.configureIfPossible()
                    // GDPR onayı + ATT izni; reklamlar bunlardan sonra anlamlı
                    consent.requestIfNeeded(isPremium: store.isPremium)
                }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        AudioEngine.shared.resume()
                        // Uygulama açıkken gece yarısı geçilmiş olabilir
                        daily.refresh()
                        missions.reloadForToday()
                    case .background, .inactive: AudioEngine.shared.stop()
                    @unknown default: break
                    }
                }
        }
    }
}

enum Route: Equatable {
    case menu
    case levels
    case game(Int)
    case endless
    case speedrun
    case shop
    case settings
    case username
    case ranking
}

@MainActor
final class AppModel: ObservableObject {
    @Published var route: Route = .menu

    /// Kullanıcı adı ekranı kapandığında gidilecek yer. Sıralamadan ya da
    /// menüden girildiğinde sıralama doğru hedef; ilk açılışta ise oyuncuyu
    /// antrenman bölümüne göndermek gerekiyor.
    @Published var usernameDestination: Route = .ranking

    /// Ad ekranını açar ve kapandığında nereye dönüleceğini de belirler.
    /// Hedefi her açılışta yeniden yazmak, ilk açılışta kurulan hedefin
    /// sonraki ziyaretlere sızmasını engeller.
    func openUsername(then destination: Route = .ranking) {
        usernameDestination = destination
        route = .username
    }
}
