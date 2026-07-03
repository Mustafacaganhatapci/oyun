import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var store: StoreManager

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BackButton { app.route = .menu }
                Spacer()
                Text("Ayarlar")
                    .font(.system(.title2, design: .rounded).bold())
                    .foregroundStyle(.white)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            ScrollView {
                VStack(spacing: 24) {
                    // Ses & titreşim
                    VStack(spacing: 4) {
                        toggleRow("music.note", "Müzik", $settings.musicOn)
                        Divider().overlay(.white.opacity(0.1))
                        toggleRow("speaker.wave.2.fill", "Ses Efektleri", $settings.sfxOn)
                        Divider().overlay(.white.opacity(0.1))
                        toggleRow("iphone.radiowaves.left.and.right", "Titreşim", $settings.hapticsOn)
                    }
                    .padding(.vertical, 8)
                    .background {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.white.opacity(0.06))
                    }
                    .padding(.horizontal, 20)

                    // Temalar
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tema")
                            .font(.system(.headline, design: .rounded).bold())
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 24)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(Theme.all) { theme in
                                    ThemeSwatch(theme: theme,
                                                selected: settings.themeID == theme.id,
                                                locked: theme.isPremium && !store.isPremium) {
                                        if theme.isPremium && !store.isPremium {
                                            app.route = .shop
                                        } else {
                                            AudioEngine.shared.playTap()
                                            settings.themeID = theme.id
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }

                    // Hakkında
                    VStack(spacing: 6) {
                        Text("LUMO")
                            .font(.system(.headline, design: .rounded).bold())
                            .foregroundStyle(.white.opacity(0.8))
                        Text("Sürüm 1.0")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                        Text("Tüm müzik ve sesler cihazında gerçek zamanlı sentezlenir.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.white.opacity(0.35))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 40)
                }
                .padding(.top, 20)
            }
        }
    }

    private func toggleRow(_ icon: String, _ title: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            Label {
                Text(title)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.white)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(settings.theme.accent.color)
            }
        }
        .tint(settings.theme.accent.color)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}

private struct ThemeSwatch: View {
    let theme: Theme
    let selected: Bool
    let locked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(colors: [theme.bgTop.color, theme.bgBottom.color],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 84, height: 110)

                    Circle()
                        .strokeBorder(theme.ring.color, lineWidth: 2.5)
                        .frame(width: 34, height: 34)
                    Circle()
                        .fill(theme.orb.color)
                        .frame(width: 9, height: 9)
                        .offset(x: 17)
                        .shadow(color: theme.accent.color, radius: 4)

                    if locked {
                        Color.black.opacity(0.45)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(selected ? theme.accent.color : .white.opacity(0.15),
                                      lineWidth: selected ? 2.5 : 1)
                }

                HStack(spacing: 3) {
                    if theme.isPremium {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(theme.lumen.color)
                    }
                    Text(theme.name)
                        .font(.system(.caption, design: .rounded).bold())
                        .foregroundStyle(selected ? .white : .white.opacity(0.6))
                }
            }
        }
    }
}
