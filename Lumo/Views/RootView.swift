import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var ads: AdsManager

    @State private var splashDone = false

    var body: some View {
        ZStack {
            ThemeGradient(theme: settings.theme)

            switch app.route {
            case .menu:
                MainMenuView()
                    .transition(.opacity)
            case .levels:
                LevelSelectView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .game(let id):
                GameContainerView(playMode: .level(id))
                    .id("level-\(id)")
                    .transition(.opacity)
            case .endless:
                GameContainerView(playMode: .endless)
                    .id("endless")
                    .transition(.opacity)
            case .speedrun:
                GameContainerView(playMode: .speedrun)
                    .id("speedrun")
                    .transition(.opacity)
            case .shop:
                ShopView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            case .settings:
                SettingsView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .username:
                UsernameView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            case .ranking:
                WorldRankingView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            if ads.showingPlaceholder {
                AdPlaceholderView { ads.dismissPlaceholder() }
                    .transition(.opacity)
                    .zIndex(100)
            }

            // Açılış imzası — yalnızca uygulama başlarken bir kez
            if !splashDone {
                SplashView {
                    withAnimation(.easeOut(duration: 0.5)) { splashDone = true }
                }
                .transition(.opacity)
                .zIndex(200)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: app.route)
        .animation(.easeInOut(duration: 0.25), value: ads.showingPlaceholder)
    }
}
