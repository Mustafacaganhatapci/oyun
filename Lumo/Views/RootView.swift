import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var ads: AdsManager
    @EnvironmentObject private var tutorial: TutorialStore

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
                // Sabit kimlik: bölüm değişince görünüm YIKILMAZ — siyah kaplama
                // sürekli ekranda kalır ve yeni sahnenin beyaz ilk karesini anında
                // örter. Sahne içeride yenilenir (transition YOK, top yapışmaz).
                GameContainerView(playMode: .level(id))
                    .id("game")
                    .transition(.identity)
            case .endless:
                GameContainerView(playMode: .endless)
                    .id("endless")
                    .transition(.identity)
            case .speedrun:
                GameContainerView(playMode: .speedrun)
                    .id("speedrun")
                    .transition(.identity)
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
                    // İlk açılış: doğrudan "nasıl oynanır" antrenman bölümüne
                    if tutorial.shouldShow(.launch) {
                        app.route = .game(LevelLibrary.tutorialID)
                    }
                }
                .transition(.opacity)
                .zIndex(200)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: app.route)
        .animation(.easeInOut(duration: 0.25), value: ads.showingPlaceholder)
        // Pencere/kök görünüm arka planını siyaha sabitler: bölüm geçişinde
        // SpriteKit sahnesi yeniden kurulurken bir karelik BEYAZ parlama olmasın
        .background(WindowBackgroundFixer())
    }
}

/// UIWindow'un ve kök view controller'ının arka planını koyu renge sabitler.
/// SwiftUI + SpriteKit birlikte kullanıldığında, sahne yeniden kurulurken
/// pencerenin varsayılan beyaz arka planı bir kare boyunca görünebiliyor.
private struct WindowBackgroundFixer: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        applyWhenAttached(view, tries: 0)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    private func applyWhenAttached(_ view: UIView, tries: Int) {
        DispatchQueue.main.async {
            if let window = view.window {
                window.backgroundColor = .black
                window.rootViewController?.view.backgroundColor = .black
            } else if tries < 10 {
                applyWhenAttached(view, tries: tries + 1)
            }
        }
    }
}
