import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var store: StoreManager

    @State private var orbPulse = false

    var body: some View {
        ZStack {
            AnimatedBackground(theme: settings.theme)

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

                Text("ışığın yolculuğu")
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
                        Label(progress.completedCount == 0 ? "Oyna" : "Devam Et — Bölüm \(progress.highestUnlocked)",
                              systemImage: "play.fill")
                    }
                    .buttonStyle(GlowButtonStyle(color: settings.theme.accent.color, prominent: true))

                    Button {
                        AudioEngine.shared.playTap()
                        app.route = .levels
                    } label: {
                        Label("Bölümler", systemImage: "circle.grid.3x3.fill")
                    }
                    .buttonStyle(GlowButtonStyle(color: settings.theme.ring.color))

                    Button {
                        AudioEngine.shared.playTap()
                        if progress.endlessUnlocked { app.route = .endless }
                    } label: {
                        HStack {
                            Label("Sonsuz Mod", systemImage: "infinity")
                            if !progress.endlessUnlocked {
                                Spacer()
                                Label("Bölüm 10", systemImage: "lock.fill")
                                    .font(.system(.footnote, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.45))
                            } else if progress.endlessBest > 0 {
                                Spacer()
                                Text("Rekor: \(progress.endlessBest)")
                                    .font(.system(.footnote, design: .rounded).bold())
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                    }
                    .buttonStyle(GlowButtonStyle(color: settings.theme.gate.color))
                    .opacity(progress.endlessUnlocked ? 1 : 0.55)

                    HStack(spacing: 14) {
                        Button {
                            AudioEngine.shared.playTap()
                            app.route = .shop
                        } label: {
                            Label(store.isPremium ? "Premium ✓" : "Mağaza", systemImage: "crown.fill")
                        }
                        .buttonStyle(GlowButtonStyle(color: settings.theme.lumen.color))

                        Button {
                            AudioEngine.shared.playTap()
                            app.route = .settings
                        } label: {
                            Label("Ayarlar", systemImage: "gearshape.fill")
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
