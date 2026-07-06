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

            VStack(spacing: 0) {
                Spacer(minLength: 40)

                // Logo: başlığın üstünde nefes alan ışık küresi
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [settings.theme.accent.opacity(0.55), .clear],
                                             center: .center, startRadius: 4, endRadius: 70))
                        .frame(width: 140, height: 140)
                        .scaleEffect(orbPulse ? 1.12 : 0.92)
                    Circle()
                        .fill(settings.theme.orb.color)
                        .frame(width: 26, height: 26)
                        .shadow(color: settings.theme.accent.color, radius: 16)
                    Circle()
                        .strokeBorder(settings.theme.ring.opacity(0.8), lineWidth: 3)
                        .frame(width: 86, height: 86)
                        .scaleEffect(orbPulse ? 1.05 : 0.97)
                }
                .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: orbPulse)
                .onAppear { orbPulse = true }

                Text("LUMO")
                    .font(.system(size: 58, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .kerning(14)
                    .shadow(color: settings.theme.accent.opacity(0.8), radius: 20)
                    .padding(.top, 8)

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
                    .padding(.top, 14)
                }

                Spacer(minLength: 30)

                // Ana eylemler — tek elle erişim için ekranın alt yarısında
                VStack(spacing: 14) {
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
                        HStack {
                            Label("Endless Mode", systemImage: "infinity")
                            if !progress.endlessUnlocked {
                                Spacer()
                                Label("Level \(LevelLibrary.adFreeLevels)", systemImage: "lock.fill")
                                    .font(.system(.footnote, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.45))
                            } else if progress.endlessBest > 0 {
                                Spacer()
                                Text("Best: \(progress.endlessBest)")
                                    .font(.system(.footnote, design: .rounded).bold())
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                    }
                    .buttonStyle(GlowButtonStyle(color: settings.theme.gate.color))
                    .opacity(progress.endlessUnlocked ? 1 : 0.55)

                    Button {
                        AudioEngine.shared.playTap()
                        if progress.endlessUnlocked { app.route = .speedrun }
                    } label: {
                        HStack {
                            Label("Speed Run", systemImage: "stopwatch.fill")
                            if !progress.endlessUnlocked {
                                Spacer()
                                Label("Level \(LevelLibrary.adFreeLevels)", systemImage: "lock.fill")
                                    .font(.system(.footnote, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.45))
                            } else if progress.speedrunBest > 0 {
                                Spacer()
                                Text(GameContainerView.formatTime(progress.speedrunBest))
                                    .font(.system(.footnote, design: .rounded).bold())
                                    .monospacedDigit()
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                    }
                    .buttonStyle(GlowButtonStyle(color: settings.theme.hazard.color))
                    .opacity(progress.endlessUnlocked ? 1 : 0.55)

                    HStack(spacing: 14) {
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
                .padding(.horizontal, 28)
                .padding(.bottom, 36)
            }
        }
    }
}
