import SwiftUI
import StoreKit
import UIKit

struct RootView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var ads: AdsManager
    @EnvironmentObject private var tutorial: TutorialStore
    @EnvironmentObject private var player: PlayerStore
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var progress: ProgressStore
    @ObservedObject private var net = Connectivity.shared

    @State private var splashDone = false
    @State private var showOfflineNotice = false

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

            if ads.showingRewardedPlaceholder {
                RewardedPlaceholderView(
                    onReward: { ads.dismissRewardedPlaceholder(granted: true) },
                    onSkip: { ads.dismissRewardedPlaceholder(granted: false) }
                )
                .transition(.opacity)
                .zIndex(120)
            }

            // Reklamdan sonra ara sıra nazik hatırlatma (sırayla Premium / Destek)
            if let kind = ads.nudge {
                NudgeView(
                    kind: kind,
                    onAction: { ads.dismissNudge(); app.route = .shop },
                    onClose: { ads.dismissNudge() }
                )
                .transition(.opacity)
                .zIndex(150)
            }

            // İnterneti kapalı oynayana bir kez çıkan nazik not (menüde)
            if showOfflineNotice {
                OfflineNoticeView(
                    onPremium: {
                        OfflineNotice.markShown()
                        showOfflineNotice = false
                        app.route = .shop
                    },
                    onClose: {
                        OfflineNotice.markShown()
                        showOfflineNotice = false
                    }
                )
                .transition(.opacity)
                .zIndex(160)
            }

            // Açılış imzası — yalnızca uygulama başlarken bir kez
            if !splashDone {
                SplashView {
                    withAnimation(.easeOut(duration: 0.5)) { splashDone = true }
                    startFirstRunFlow()
                }
                .transition(.opacity)
                .zIndex(200)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: app.route)
        .animation(.easeInOut(duration: 0.25), value: ads.showingPlaceholder)
        .animation(.easeInOut(duration: 0.25), value: ads.showingRewardedPlaceholder)
        .animation(.easeInOut(duration: 0.3), value: ads.nudge)
        // Pencere/kök görünüm arka planını siyaha sabitler: bölüm geçişinde
        // SpriteKit sahnesi yeniden kurulurken bir karelik BEYAZ parlama olmasın
        .background(WindowBackgroundFixer())
        // Premium'un kendi kaydettiği sesler: abonelik durumu değiştikçe motora
        // yüklenir ya da boşaltılır (kayıtlar diskte kalır).
        .animation(.easeInOut(duration: 0.3), value: showOfflineNotice)
        .onAppear { CustomSoundStore.shared.premiumActive = store.isPremium }
        .onChange(of: store.isPremium) { _, isPremium in
            CustomSoundStore.shared.premiumActive = isPremium
        }
        // Not yalnızca menüde ve oyun dışıyken çıkar; bir turu asla bölmez.
        .onChange(of: app.route) { _, _ in evaluateOfflineNotice() }
        .onChange(of: net.isOnline) { _, _ in evaluateOfflineNotice() }
        .onChange(of: splashDone) { _, _ in evaluateOfflineNotice() }
    }

    private func evaluateOfflineNotice() {
        guard splashDone, app.route == .menu, !showOfflineNotice else { return }
        showOfflineNotice = OfflineNotice.shouldShow(
            isOnline: net.isOnline,
            isPremium: store.isPremium,
            totalStars: progress.totalStars
        )
    }

    /// Açılıştan sonraki ilk yönlendirme. Ad önce sorulur — sıralamaya sonradan
    /// katılmak isteyen oyuncunun ekranı kendi başına bulması gerekiyordu.
    /// Ad ekranı kapanınca (kaydedilsin ya da atlansın) antrenman bölümü
    /// devralır; ad bir kez sorulduktan sonra bir daha kendiliğinden açılmaz.
    private func startFirstRunFlow() {
        let tutorialRoute: Route = .game(LevelLibrary.tutorialID)
        if player.shouldPromptForUsername {
            app.usernameDestination = tutorial.shouldShow(.launch) ? tutorialRoute : .menu
            app.route = .username
        } else if tutorial.shouldShow(.launch) {
            app.route = tutorialRoute
        }
    }
}

/// Reklamdan sonra ara sıra çıkan nazik hatırlatma: Premium ya da Destek Ol.
/// Ürün mağazadan geldiyse satın alma buradan doğrudan yapılır — reklamı yeni
/// izlemiş oyuncuyu ayrıca mağazaya yollamak teklifi soğutuyordu.
private struct NudgeView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var store: StoreManager
    let kind: AdsManager.Nudge
    let onAction: () -> Void
    let onClose: () -> Void

    private var icon: String { kind == .premium ? "crown.fill" : "cup.and.saucer.fill" }
    private var accent: Color { settings.theme.lumen.color }
    private var title: LocalizedStringKey {
        kind == .premium ? "Tired of the ads?" : "Love the game?"
    }
    private var body_: LocalizedStringKey {
        kind == .premium
            ? "Premium removes every ad forever, hands you an extra life each endless run, 8 exclusive themes and your own photo in the orb."
            : "Ads keep Orbeon free. If you're enjoying it, you can buy the developer a coffee ☕️"
    }

    /// Teklifi buradan bitirebileceğimiz ürün (premium kartında premium,
    /// destek kartında en küçük bahşiş). Yoksa mağazaya yönlendiririz.
    private var directProduct: Product? {
        kind == .premium ? store.premiumProduct : store.tipProducts.first
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 44))
                    .foregroundStyle(accent)
                    .shadow(color: accent.opacity(0.8), radius: 16)

                Text(title)
                    .font(.system(.title2, design: .rounded).bold())
                    .foregroundStyle(.white)

                Text(body_)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)

                if let product = directProduct {
                    // Tek dokunuşta satın alma — App Store sayfası buradan açılır
                    Button {
                        Task {
                            await store.purchase(product)
                            if kind == .premium, store.isPremium { onClose() }
                        }
                    } label: {
                        HStack {
                            Label(kind == .premium ? "Go Premium" : "Buy a coffee",
                                  systemImage: kind == .premium ? "crown.fill" : "heart.fill")
                            Spacer()
                            Text(product.displayPrice).bold()
                        }
                        .padding(.horizontal, 8)
                    }
                    .buttonStyle(GlowButtonStyle(color: accent, prominent: true))
                    .disabled(store.purchaseInProgress)
                    .padding(.top, 4)

                    Button(action: onAction) {
                        Text("See all options")
                            .font(.system(.footnote, design: .rounded).bold())
                            .foregroundStyle(.white.opacity(0.55))
                            .underline()
                    }
                } else {
                    Button(action: onAction) {
                        Label(kind == .premium ? "See Premium" : "Support the developer",
                              systemImage: kind == .premium ? "crown.fill" : "heart.fill")
                    }
                    .buttonStyle(GlowButtonStyle(color: accent, prominent: true))
                    .padding(.top, 4)
                }

                Button(action: onClose) {
                    Text("Not now")
                        .font(.system(.subheadline, design: .rounded).bold())
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.top, 2)
            }
            .padding(28)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.black.opacity(0.85))
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(accent.opacity(0.5), lineWidth: 1.5)
            }
            .padding(.horizontal, 40)
        }
    }
}

/// Ödüllü reklam yer tutucusu (yalnızca DEBUG — SDK yokken akışı denemek için).
/// Ödülü vermek ile yarıda bırakmak ayrı ayrı denenebilsin diye iki çıkış var.
private struct RewardedPlaceholderView: View {
    @EnvironmentObject private var settings: SettingsStore
    let onReward: () -> Void
    let onSkip: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(settings.theme.lumen.color)

                Text("Rewarded ad (test)")
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundStyle(.white)

                Text("The real ad plays here in release builds.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))

                Button(action: onReward) {
                    Label("Finish & get reward", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(GlowButtonStyle(color: settings.theme.lumen.color, prominent: true))

                Button(action: onSkip) {
                    Text("Close early (no reward)")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(32)
        }
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
