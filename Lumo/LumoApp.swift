import SwiftUI

@main
struct LumoApp: App {
    @StateObject private var app = AppModel()
    @StateObject private var progress = ProgressStore()
    @StateObject private var settings = SettingsStore()
    @StateObject private var store = StoreManager()
    @StateObject private var ads = AdsManager()
    @StateObject private var gameCenter = GameCenterService()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .environmentObject(progress)
                .environmentObject(settings)
                .environmentObject(store)
                .environmentObject(ads)
                .environmentObject(gameCenter)
                .preferredColorScheme(.dark)
                .persistentSystemOverlays(.hidden)
                .onAppear {
                    AudioEngine.shared.startIfNeeded()
                    // Game Center kimlik doğrulaması açılış anında değil, arayüz
                    // yerleştikten kısa süre sonra denenir (açılış çökmelerini önler).
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        gameCenter.authenticate()
                    }
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
}

@MainActor
final class AppModel: ObservableObject {
    @Published var route: Route = .menu
}
