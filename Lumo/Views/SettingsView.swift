import Combine
import SwiftUI

/// Sürüm yazısının altındaki gizli kilit.
///
/// Dizi: **sekiz vuruş, beş saniye bekleme, iki vuruş daha.** Beklemesi
/// gereken yerde dokunan baştan başlıyor — sabırsızlık cezalandırılmıyor,
/// yalnızca geri sayıyor. İlk sekizin arası üç saniyeyi geçerse de sayaç
/// sıfırlanıyor: ayarlarda oyalanırken kazara açılmasın.
///
/// Kilit hiçbir yerde anlatılmıyor. Tarifi burada duruyor, çünkü altı ay
/// sonra bu ekranı açan kişinin sayıları koddan okuyabilmesi gerekiyor.
struct SecretKnock {
    enum Stage: Equatable { case idle, knocking, waiting, open }

    static let knocks = 8
    static let pause: TimeInterval = 5
    private static let knockGap: TimeInterval = 3    // vuruşlar arası üst sınır
    private static let window: TimeInterval = 12     // beklemenin başından itibaren
    private static let finalKnocks = 2

    private(set) var stage: Stage = .idle
    private var count = 0
    private var last: Date?
    private var waitStarted: Date?

    /// Zamanlayıcının dönmesi gerekiyor mu — dizi başlamadan hiçbir şey işlemiyor
    var isTiming: Bool { waitStarted != nil }

    /// Bir vuruş işler. Kilit AÇILDIYSA `true` döner.
    mutating func tap(at now: Date = Date()) -> Bool {
        switch stage {
        case .idle:
            stage = .knocking
            count = 1
            last = now

        case .knocking:
            if let last, now.timeIntervalSince(last) > Self.knockGap {
                count = 1
            } else {
                count += 1
            }
            self.last = now
            if count >= Self.knocks {
                stage = .waiting
                waitStarted = now
                count = 0
            }

        case .waiting:
            // Beklemesi gereken yerde dokundu: dizi baştan başlıyor
            reset()
            stage = .knocking
            count = 1
            last = now

        case .open:
            if let last, now.timeIntervalSince(last) > Self.knockGap {
                reset()
                stage = .knocking
                count = 1
                self.last = now
                return false
            }
            count += 1
            last = now
            if count >= Self.finalKnocks {
                reset()
                return true
            }
        }
        return false
    }

    /// Bekleme doldu mu, pencere kapandı mı — görünüm bunu saniyede iki kez sorar
    mutating func settle(at now: Date = Date()) {
        guard let started = waitStarted else { return }
        let waited = now.timeIntervalSince(started)
        if stage == .waiting, waited >= Self.pause {
            stage = .open
            count = 0
            last = nil
        } else if stage == .open, waited >= Self.window {
            reset()
        }
    }

    mutating func reset() {
        stage = .idle
        count = 0
        last = nil
        waitStarted = nil
    }
}

struct SettingsView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var tutorial: TutorialStore
    @EnvironmentObject private var player: PlayerStore
    @ObservedObject private var sounds = CustomSoundStore.shared
    @ObservedObject private var push = PushManager.shared

    @State private var feedback = ""
    @State private var sendingFeedback = false
    @State private var feedbackSent = false
    /// Bugün kalan gönderim hakkı. @State: gönderdikçe azalırken arayüz
    /// kendiliğinden tazelensin.
    @State private var feedbackLeft = Feedback.remainingToday
    @FocusState private var feedbackFocused: Bool

    /// Sürüm yazısındaki gizli kilit ve bulununca açılan kutlama
    @State private var knock = SecretKnock()
    @State private var showSecretReveal = false
    /// @State: görünüm struct'ı her yeniden kurulduğunda yeni bir
    /// zamanlayıcı doğmasın, abonelik de baştan kurulmasın
    @State private var knockTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

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

                        // Bildirim izni BURADA isteniyor, açılışta değil.
                        // Oyunu ilk açan birine sorulan izin çoğunlukla
                        // reddediliyor ve iOS bir daha sormuyor.
                        if PushManager.isAvailable {
                            Divider().overlay(.white.opacity(0.1))
                            notificationsRow
                        }
                    }
                    .padding(.vertical, 8)
                    .background {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.white.opacity(0.06))
                    }
                    .padding(.horizontal, 20)

                    // Kendi seslerin "Kişiselleştir" ekranına, kürelerin altına
                    // taşındı; premium'u alıp henüz hiç kayıt yapmamış olana
                    // yolu göster. Kayıt yapana ya da premium'u olmayana
                    // hiçbir şey çıkmaz.
                    if store.isPremium, sounds.recorded.isEmpty {
                        Button {
                            AudioEngine.shared.playTap()
                            app.route = .personalize
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "mic.fill")
                                    .foregroundStyle(settings.theme.lumen.color)
                                Text("Record your own sounds")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            .padding(16)
                            .background {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(settings.theme.lumen.opacity(0.10))
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(settings.theme.lumen.opacity(0.30), lineWidth: 1)
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // Görüş ve öneri
                    feedbackSection

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
                        //
                        // Aynı yazı gizli kilidin kapısı. Sekiz vuruştan
                        // sonra rengi ısınıyor, bekleme dolunca parlıyor:
                        // diziyi bilmeyen hiçbir şey görmüyor, bilen de
                        // karanlıkta el yordamıyla aramıyor.
                        Text(verbatim: "\(Self.appVersion)")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(versionTint)
                            .shadow(color: knock.stage == .open
                                    ? settings.theme.lumen.color : .clear, radius: 7)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 26)
                            .contentShape(Rectangle())
                            .onTapGesture { knockTapped() }
                            .animation(.easeInOut(duration: 0.25), value: knock.stage)
                        Text("Designed and built by Axium Dynamics. All rights reserved.")
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
        // Zamanlayıcı yalnızca dizi başladıktan sonra iş yapıyor: `settle`
        // @State'e yazdığı için her boş tık görünümü yeniden çizerdi.
        .onReceive(knockTimer) { _ in
            guard knock.isTiming else { return }
            knock.settle()
        }
        .onDisappear { knock.reset() }
        .overlay {
            if showSecretReveal {
                OrbRevealView(style: OrbStyle.secret, theme: settings.theme) {
                    settings.orbStyleID = OrbStyle.secretID
                    showSecretReveal = false
                } onClose: {
                    showSecretReveal = false
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showSecretReveal)
    }

    /// Kilit ilerledikçe sürüm yazısının rengi. Tek geri bildirim bu.
    private var versionTint: Color {
        switch knock.stage {
        case .idle, .knocking: return .white.opacity(0.4)
        case .waiting: return .white.opacity(0.7)
        case .open: return settings.theme.lumen.color
        }
    }

    /// Sürüm yazısına dokunuldu. Dizi tamamlandıysa gizli küre açılıyor;
    /// zaten açıksa kutlama yine gösteriliyor — bulduğunu yeniden görmek
    /// isteyene "bu sende zaten" demek gereksiz bir soğukluk olurdu.
    private func knockTapped() {
        guard knock.tap() else { return }
        progress.grantSecretOrb()
        showSecretReveal = true
    }

    /// Oyuncunun doğrudan yazabileceği tek yer. Mağaza yorumu bize ulaşmıyor,
    /// e-posta da kimsenin açmak istediği bir şey değil.
    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .foregroundStyle(settings.theme.accent.color)
                Text("Feedback")
                    .font(.system(.headline, design: .rounded).bold())
                    .foregroundStyle(.white.opacity(0.9))
            }

            Text("Something broken, something missing, an idea? Write it here and it comes straight to me.")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))

            // Günlük hak. Sayı gönderdikten SONRA değil, kutunun başında
            // duruyor: sınırı gönderdiğinde öğrenmek, sınır olmamasından
            // daha kötü.
            if feedbackLeft == 0 {
                Label("That is both of today's messages. The box opens again tomorrow.",
                      systemImage: "clock.fill")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(settings.theme.lumen.color)
            } else {
                Text("\(feedbackLeft) left today")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }

            ZStack(alignment: .topLeading) {
                if feedback.isEmpty {
                    Text("Your message…")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }
                TextEditor(text: $feedback)
                    .focused($feedbackFocused)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .frame(height: 96)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
            }
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.07))
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
            }

            HStack {
                // 1000 karakterde kesiliyor: gönderilen metin doğrudan
                // Firestore belgesine gidiyor, sınırsız bırakmak doğru olmaz
                Text(verbatim: "\(feedback.count)/1000")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.white.opacity(feedback.count > 1000 ? 0.9 : 0.35))
                Spacer()
                Button {
                    feedbackFocused = false
                    sendingFeedback = true
                    Task {
                        let ok = await Feedback.send(message: feedback,
                                                     playerID: player.playerID,
                                                     username: player.username)
                        sendingFeedback = false
                        if ok {
                            feedback = ""
                            feedbackSent = true
                            feedbackLeft = Feedback.remainingToday
                            AudioEngine.shared.playWin()
                            Haptics.shared.win()
                        }
                    }
                } label: {
                    if sendingFeedback {
                        ProgressView().tint(.black)
                            .frame(width: 60, height: 18)
                    } else {
                        Text("Send")
                            .font(.system(.subheadline, design: .rounded).bold())
                            .foregroundStyle(.black)
                            .frame(width: 60, height: 18)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Capsule().fill(settings.theme.accent.color))
                .disabled(!canSendFeedback)
                .opacity(canSendFeedback ? 1 : 0.4)
            }

            if feedbackSent {
                Label("Thanks — I read every one of these.", systemImage: "checkmark.circle.fill")
                    .font(.system(.caption, design: .rounded).bold())
                    .foregroundStyle(settings.theme.gate.color)
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.06))
        }
        .padding(.horizontal, 20)
    }

    private var canSendFeedback: Bool {
        let trimmed = feedback.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 4 && trimmed.count <= 1000
            && !sendingFeedback && feedbackLeft > 0
    }

    /// Bildirimler. Kendi satırı var çünkü anahtar doğrudan bir ayarı değil,
    /// iOS izin akışını tetikliyor: açarken izin kutusu çıkıyor, reddedilirse
    /// tek yol iOS Ayarları'ndan geçiyor.
    private var notificationsRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: Binding(
                get: { push.isEnabled },
                set: { on in Task { await push.setEnabled(on) } }
            )) {
                Label {
                    Text("Notifications")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.white)
                } icon: {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(settings.theme.accent.color)
                }
            }
            .tint(settings.theme.accent.color)
            .disabled(push.isWorking)

            if push.isDenied {
                Button {
                    AudioEngine.shared.playTap()
                    push.openSystemSettings()
                } label: {
                    Text("Notifications are off for Orbeon. Turn them on in iOS Settings.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(settings.theme.hazard.color)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
            } else {
                Text("New levels, new characters and a nudge before the weekly board resets. Nothing else.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
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
