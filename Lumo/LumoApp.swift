import SwiftUI

@main
struct LumoApp: App {
    @StateObject private var app = AppModel()
    @StateObject private var progress = ProgressStore()
    @StateObject private var settings = SettingsStore()
    @StateObject private var store = StoreManager()
    @StateObject private var ads = AdsManager()
    @StateObject private var player = PlayerStore()
    @StateObject private var leaderboard = LeaderboardService()
    @StateObject private var tutorial = TutorialStore()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Firebase, ilk kare çizilmeden önce yapılandırılmalı
        // (I-COR000003 uyarısının çözümü)
        LeaderboardService.bootstrapFirebase()
    }

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
                .preferredColorScheme(.dark)
                .persistentSystemOverlays(.hidden)
                .onAppear {
                    AudioEngine.shared.startIfNeeded()
                    leaderboard.configureIfPossible()
                }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active: AudioEngine.shared.resume()
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
}
