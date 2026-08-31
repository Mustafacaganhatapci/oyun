import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var tutorial: TutorialStore
    @ObservedObject private var sounds = CustomSoundStore.shared

    /// Info.plist'ten okunur — sürüm yükseltirken burayı düzeltmek unutulmasın
    private static var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return "\(String(localized: "Version")) \(short ?? "—")"
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
                        // Sürüm elle yazılıydı ve 1.0'da kalmıştı; artık
                        // derlemenin kendi numarasını gösteriyor.
                        Text(verbatim: "\(Self.appVersion)")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                        Text("All audio is created on your device — nothing is streamed or uploaded.")
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
                    app.route = .premium
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
