import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var ads: AdsManager

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
            }

            if ads.showingPlaceholder {
                AdPlaceholderView { ads.dismissPlaceholder() }
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: app.route)
        .animation(.easeInOut(duration: 0.25), value: ads.showingPlaceholder)
    }
}
