import SwiftUI
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var progress: ProgressStore

    @State private var photoItem: PhotosPickerItem?

    /// Bir küre stili şu an kuşanılabilir mi?
    /// Premium sahibi TÜM karakterleri kullanabilir (yıldızlı olanlar dahil).
    private func isAvailable(_ style: OrbStyle) -> Bool {
        if store.isPremium { return true }
        switch style.unlock {
        case .free: return true
        case .stars: return progress.isOrbUnlocked(style)
        case .premium: return false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BackButton { app.route = .menu }
                Spacer()
                Text("Settings")
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
                        toggleRow("music.note", "Music", $settings.musicOn)
                        Divider().overlay(.white.opacity(0.1))
                        toggleRow("speaker.wave.2.fill", "Sound Effects", $settings.sfxOn)
                        Divider().overlay(.white.opacity(0.1))
                        toggleRow("iphone.radiowaves.left.and.right", "Haptics", $settings.hapticsOn)
                    }
                    .padding(.vertical, 8)
                    .background {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.white.opacity(0.06))
                    }
                    .padding(.horizontal, 20)

                    // Temalar
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Theme")
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

                    // Küre stilleri — oyuncunun "karakteri"
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Orb Style")
                            .font(.system(.headline, design: .rounded).bold())
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 24)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(OrbStyle.all) { style in
                                    let available = isAvailable(style)
                                    OrbSwatch(style: style,
                                              theme: settings.theme,
                                              selected: settings.orbStyleID == style.id,
                                              locked: !available,
                                              photoVersion: settings.orbPhotoVersion) {
                                        if available {
                                            AudioEngine.shared.playTap()
                                            settings.orbStyleID = style.id
                                        } else {
                                            // Kilitli: mağazada yıldızla/premium ile alınır
                                            app.route = .shop
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        Text("Buy more characters with stars in the Shop.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.horizontal, 24)

                        // Fotoğraflı küre seçiliyse fotoğraf seçme düğmesi
                        if settings.orbStyleID == "photo", store.isPremium {
                            PhotosPicker(selection: $photoItem, matching: .images) {
                                Label(OrbPhotoStore.exists ? "Change Photo" : "Choose Photo",
                                      systemImage: "photo.circle.fill")
                                    .font(.system(.subheadline, design: .rounded).bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 10)
                                    .background(Capsule().fill(settings.theme.accent.opacity(0.3)))
                            }
                            .padding(.horizontal, 24)
                            .onChange(of: photoItem) { _, item in
                                guard let item else { return }
                                Task {
                                    if let data = try? await item.loadTransferable(type: Data.self),
                                       let image = UIImage(data: data) {
                                        OrbPhotoStore.save(image)
                                        settings.orbPhotoVersion += 1
                                    }
                                }
                            }
                            Text("Your photo stays on your device only.")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.white.opacity(0.4))
                                .padding(.horizontal, 24)
                        }
                    }

                    // Hakkında
                    VStack(spacing: 6) {
                        Text("LUMO")
                            .font(.system(.headline, design: .rounded).bold())
                            .foregroundStyle(.white.opacity(0.8))
                        Text("Version 1.0")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                        Text("All music and sounds are synthesized in real time on your device.")
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

    private func toggleRow(_ icon: String, _ title: LocalizedStringKey, _ binding: Binding<Bool>) -> some View {
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

private struct OrbSwatch: View {
    let style: OrbStyle
    let theme: Theme
    let selected: Bool
    let locked: Bool
    let photoVersion: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [theme.bgTop.color, theme.bgBottom.color],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 72, height: 72)

                    orbPreview

                    if locked {
                        Color.black.opacity(0.45).clipShape(Circle()).frame(width: 72, height: 72)
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .overlay {
                    Circle()
                        .strokeBorder(selected ? theme.accent.color : .white.opacity(0.15),
                                      lineWidth: selected ? 2.5 : 1)
                }

                HStack(spacing: 3) {
                    if style.isPremium {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(theme.lumen.color)
                    }
                    Text(style.localizedName)
                        .font(.system(.caption, design: .rounded).bold())
                        .foregroundStyle(selected ? .white : .white.opacity(0.6))
                }
            }
        }
    }

    @ViewBuilder
    private var orbPreview: some View {
        switch style.kind {
        case .classic:
            Circle().fill(theme.orb.color).frame(width: 18, height: 18)
                .shadow(color: theme.accent.color, radius: 8)
        case .star:
            Image(systemName: "star.fill")
                .font(.system(size: 20))
                .foregroundStyle(theme.lumen.color)
                .shadow(color: theme.lumen.color, radius: 8)
        case .crystal:
            Image(systemName: "hexagon.fill")
                .font(.system(size: 20))
                .foregroundStyle(theme.gate.color)
                .shadow(color: theme.gate.color, radius: 8)
        case .comet:
            HStack(spacing: 0) {
                Capsule().fill(LinearGradient(colors: [.clear, theme.accent.color],
                                              startPoint: .leading, endPoint: .trailing))
                    .frame(width: 22, height: 5)
                Circle().fill(.white).frame(width: 13, height: 13)
            }
            .shadow(color: theme.accent.color, radius: 8)
        case .rainbow:
            Circle()
                .fill(AngularGradient(colors: [.red, .yellow, .green, .cyan, .purple, .red], center: .center))
                .frame(width: 18, height: 18)
                .shadow(color: .white.opacity(0.6), radius: 8)
        case .photo:
            if photoVersion >= 0, let image = OrbPhotoStore.load() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 26, height: 26)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
            } else {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
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
                    Text(theme.localizedName)
                        .font(.system(.caption, design: .rounded).bold())
                        .foregroundStyle(selected ? .white : .white.opacity(0.6))
                }
            }
        }
    }
}
