import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var gameCenter: GameCenterService

    @State private var orbPulse = false

    var body: some View {
        ZStack {
            AnimatedBackground(theme: settings.theme)

            // Dünya sıralaması — sağ üst köşe
            VStack {
                HStack {
                    Spacer()
                    Button {
                        gameCenter.showLeaderboards()
                    } label: {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(settings.theme.lumen.color)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.white.opacity(0.1)))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                Spacer()
            }

            // Küçük ekranlarda taşmasın diye kaydırılabilir; büyük ekranda ortalanır
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: 28)

                        logo
                            .padding(.top, 8)

                        Text("LUMO")
                            .font(.system(size: 54, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .kerning(14)
                            .shadow(color: settings.theme.accent.opacity(0.8), radius: 20)
                            .padding(.top, 6)

                        Text("the journey of light")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .kerning(4)

                        if progress.totalStars > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(settings.theme.lumen.color)
                                Text("\(progress.totalStars) / \(LevelLibrary.count * 3)")
                                    .font(.system(.subheadline, design: .rounded).bold())
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .padding(.top, 12)
                        }

                        Spacer(minLength: 24)

                        actions
                            .padding(.horizontal, 28)
                            .padding(.bottom, 28)
                    }
                    .frame(minHeight: geo.size.height)
                }
            }
        }
    }

    private var logo: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [settings.theme.accent.opacity(0.55), .clear],
                                     center: .center, startRadius: 4, endRadius: 62))
                .frame(width: 124, height: 124)
                .scaleEffect(orbPulse ? 1.12 : 0.92)
            Circle()
                .fill(settings.theme.orb.color)
                .frame(width: 24, height: 24)
                .shadow(color: settings.theme.accent.color, radius: 16)
            Circle()
                .strokeBorder(settings.theme.ring.opacity(0.8), lineWidth: 3)
                .frame(width: 78, height: 78)
                .scaleEffect(orbPulse ? 1.05 : 0.97)
        }
        .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: orbPulse)
        .onAppear { orbPulse = true }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                AudioEngine.shared.playTap()
                app.route = .game(progress.highestUnlocked)
            } label: {
                if progress.completedCount == 0 {
                    Label("Play", systemImage: "play.fill")
                } else {
                    Label("Continue — Level \(progress.highestUnlocked)", systemImage: "play.fill")
                }
            }
            .buttonStyle(GlowButtonStyle(color: settings.theme.accent.color, prominent: true))

            Button {
                AudioEngine.shared.playTap()
                app.route = .levels
            } label: {
                Label("Levels", systemImage: "circle.grid.3x3.fill")
            }
            .buttonStyle(GlowButtonStyle(color: settings.theme.ring.color))

            Button {
                AudioEngine.shared.playTap()
                if progress.endlessUnlocked { app.route = .endless }
            } label: {
                HStack(spacing: 0) {
                    Label("Endless Mode", systemImage: "infinity")
                    Spacer(minLength: 8)
                    if !progress.endlessUnlocked {
                        Label("Level \(LevelLibrary.adFreeLevels)", systemImage: "lock.fill")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                    } else if progress.endlessBest > 0 {
                        Text("Best: \(progress.endlessBest)")
                            .font(.system(.footnote, design: .rounded).bold())
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 2)
            }
            .buttonStyle(GlowButtonStyle(color: settings.theme.gate.color))
            .opacity(progress.endlessUnlocked ? 1 : 0.55)

            Button {
                AudioEngine.shared.playTap()
                if progress.endlessUnlocked { app.route = .speedrun }
            } label: {
                HStack(spacing: 0) {
                    Label("Speed Run", systemImage: "stopwatch.fill")
                    Spacer(minLength: 8)
                    if !progress.endlessUnlocked {
                        Label("Level \(LevelLibrary.adFreeLevels)", systemImage: "lock.fill")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                    } else if progress.speedrunBest > 0 {
                        Text(GameContainerView.formatTime(progress.speedrunBest))
                            .font(.system(.footnote, design: .rounded).bold())
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 2)
            }
            .buttonStyle(GlowButtonStyle(color: settings.theme.hazard.color))
            .opacity(progress.endlessUnlocked ? 1 : 0.55)

            HStack(spacing: 12) {
                Button {
                    AudioEngine.shared.playTap()
                    app.route = .shop
                } label: {
                    if store.isPremium {
                        Label("Premium ✓", systemImage: "crown.fill")
                    } else {
                        Label("Shop", systemImage: "crown.fill")
                    }
                }
                .buttonStyle(GlowButtonStyle(color: settings.theme.lumen.color))

                Button {
                    AudioEngine.shared.playTap()
                    app.route = .settings
                } label: {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .buttonStyle(GlowButtonStyle(color: Color.white.opacity(0.7)))
            }
        }
    }
}
