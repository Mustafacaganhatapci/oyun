import SwiftUI
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var tutorial: TutorialStore
    @ObservedObject private var sounds = CustomSoundStore.shared

    @State private var photoItem: PhotosPickerItem?

    /// Bir küre stili şu an kuşanılabilir mi?
    /// Premium yalnızca premium'a özel stilleri (foto küre) açar;
    /// yıldızlı karakterler herkes için yıldız biriktirerek alınır.
    private func isAvailable(_ style: OrbStyle) -> Bool {
        switch style.unlock {
        case .free: return true
        // Şampiyon küresi de kazanıldıysa kuşanılabilir; premium ya da yıldız
        // onu açmaz, tek yolu haftalık ilk üçe girmek.
        case .stars, .champion: return progress.isOrbUnlocked(style)
        case .premium: return store.isPremium
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
                        Divider().overlay(.white.opacity(0.1))
                        toggleRow("eye.fill", "Colorblind Mode", $settings.colorBlindOn)
                        Text("Uses a palette that stays distinct for every kind of color blindness, and marks hazards with notches as well as color.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.horizontal, 20)
                            .padding(.bottom, 6)
                    }
                    .padding(.vertical, 8)
                    .background {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.white.opacity(0.06))
                    }
                    .padding(.horizontal, 20)

                    // Mağaza ana menüden kaldırıldı (menü kalabalıktı);
                    // arka planlar, bahşiş ve premium oraya taşındı
                    Button {
                        AudioEngine.shared.playTap()
                        app.route = .shop
                    } label: {
                        Label("Shop", systemImage: "bag.fill")
                    }
                    .buttonStyle(GlowButtonStyle(color: settings.theme.lumen.color))
                    .padding(.horizontal, 20)

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

                        Text("New characters unlock as you collect stars.")
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

                    // Premium: kendi seslerin
                    customSoundsSection

                    // Öğreticiyi baştan izlemek isteyenler için
                    Button {
                        AudioEngine.shared.playTap()
                        tutorial.reset()
                        app.route = .game(LevelLibrary.tutorialID)
                    } label: {
                        Label("Show tutorial again", systemImage: "graduationcap.fill")
                            .font(.system(.subheadline, design: .rounded).bold())
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(.white.opacity(0.10)))
                    }
                    .padding(.top, 6)

                    // Hakkında
                    VStack(spacing: 6) {
                        Text("ORBEON")
                            .font(.system(.headline, design: .rounded).bold())
                            .foregroundStyle(.white.opacity(0.8))
                            .kerning(2)
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

    // MARK: Premium — kendi kaydettiğin sesler

    /// Oyuncu kendi sesini kaydeder; oyun onu sentetik efektin yerine çalar.
    /// "Hop" ayrıca komboyla birlikte hızlandırılıp inceltilir — melodinin
    /// yerini oyuncunun kendi sesi alır.
    @ViewBuilder
    private var customSoundsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .foregroundStyle(settings.theme.lumen.color)
                Text("Your Own Sounds")
                    .font(.system(.headline, design: .rounded).bold())
                    .foregroundStyle(.white.opacity(0.9))
                if !store.isPremium {
                    Text("PREMIUM")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .kerning(1)
                        .foregroundStyle(settings.theme.lumen.color)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Capsule().fill(settings.theme.lumen.color.opacity(0.18)))
                }
            }
            .padding(.horizontal, 24)

            Text("Record your own hop, death, life-lost and level-complete sounds. The hop rises in pitch with your combo, just like the built-in one. Recordings never leave your device.")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 24)

            if store.isPremium {
                VStack(spacing: 4) {
                    toggleRow("waveform", "Use my recordings", $sounds.enabled)
                    ForEach(CustomSoundSlot.allCases) { slot in
                        Divider().overlay(.white.opacity(0.1))
                        soundRow(slot)
                    }
                }
                .padding(.vertical, 8)
                .background {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.white.opacity(0.06))
                }
                .padding(.horizontal, 20)

                if sounds.micDenied {
                    Text("Microphone access is off. Turn it on in iOS Settings to record.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(settings.theme.hazard.color)
                        .padding(.horizontal, 24)
                }
            } else {
                Button {
                    AudioEngine.shared.playTap()
                    app.route = .shop
                } label: {
                    Label("Go Premium", systemImage: "crown.fill")
                }
                .buttonStyle(GlowButtonStyle(color: settings.theme.lumen.color))
                .padding(.horizontal, 20)
            }
        }
    }

    private func soundRow(_ slot: CustomSoundSlot) -> some View {
        let isRecording = sounds.recording == slot
        let has = sounds.hasRecording(slot)
        return HStack(spacing: 12) {
            Image(systemName: slot.icon)
                .foregroundStyle(settings.theme.accent.color)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(LocalizedStringKey(slot.title))
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.white)
                Text(LocalizedStringKey(isRecording ? "Recording…" : slot.hint))
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(isRecording
                                     ? settings.theme.hazard.color
                                     : .white.opacity(0.45))
            }

            Spacer(minLength: 4)

            if has, !isRecording {
                iconButton("play.fill") { sounds.preview(slot) }
                iconButton("trash") {
                    AudioEngine.shared.playTap()
                    sounds.delete(slot)
                }
            }

            iconButton(isRecording ? "stop.fill" : "mic.fill",
                       tint: isRecording ? settings.theme.hazard.color : .white) {
                if isRecording {
                    sounds.stopRecording()
                } else {
                    AudioEngine.shared.playTap()
                    sounds.startRecording(slot)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .animation(.easeInOut(duration: 0.2), value: isRecording)
    }

    private func iconButton(_ icon: String, tint: Color = .white,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint.opacity(0.9))
                .frame(width: 34, height: 34)
                .background(Circle().fill(.white.opacity(0.10)))
        }
        .buttonStyle(.plain)
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

                    // Kilitli karakter BULANIK: ne kazanacağını merak etsin,
                    // ama ne olduğunu görmesin
                    orbPreview
                        .blur(radius: locked ? 8 : 0)

                    if locked {
                        Color.black.opacity(0.35).clipShape(Circle()).frame(width: 72, height: 72)
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
                    Text(locked ? "???" : style.localizedName)
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
        case .ring:
            Circle().strokeBorder(theme.orb.color, lineWidth: 3)
                .frame(width: 20, height: 20).shadow(color: theme.orb.color, radius: 6)
        case .diamond:
            Image(systemName: "suit.diamond.fill").font(.system(size: 20))
                .foregroundStyle(theme.accent.color).shadow(color: theme.accent.color, radius: 8)
        case .flame:
            Image(systemName: "flame.fill").font(.system(size: 20))
                .foregroundStyle(theme.hazard.color).shadow(color: theme.hazard.color, radius: 8)
        case .pixel:
            RoundedRectangle(cornerRadius: 2).fill(theme.gate.color)
                .frame(width: 17, height: 17).shadow(color: theme.gate.color, radius: 6)
        case .bubble:
            Circle().strokeBorder(.white.opacity(0.85), lineWidth: 1.5)
                .background(Circle().fill(.white.opacity(0.25)))
                .frame(width: 20, height: 20)
                .shadow(color: .white.opacity(0.6), radius: 6)
        case .heart:
            Image(systemName: "heart.fill").font(.system(size: 20))
                .foregroundStyle(Color.pink).shadow(color: .pink, radius: 8)
        case .firefly:
            Image(systemName: "sparkle").font(.system(size: 20))
                .foregroundStyle(Color(red: 0.75, green: 1.0, blue: 0.4))
                .shadow(color: Color(red: 0.75, green: 1.0, blue: 0.4), radius: 8)
        case .cloud:
            Image(systemName: "cloud.fill").font(.system(size: 20))
                .foregroundStyle(.white).shadow(color: .white.opacity(0.7), radius: 6)
        case .champion:
            Image(systemName: "crown.fill").font(.system(size: 20))
                .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.35))
                .shadow(color: Color(red: 1.0, green: 0.82, blue: 0.35), radius: 8)
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

/// Arka plan kartı. Mağaza da kullanıyor (temalar oraya taşındı), bu yüzden
/// dosyaya özel değil.
struct ThemeSwatch: View {
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
