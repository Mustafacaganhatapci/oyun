import SwiftUI
import SpriteKit

enum PlayMode: Equatable {
    case level(Int)
    case endless
    case speedrun
}

struct GameContainerView: View {
    let playMode: PlayMode

    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var ads: AdsManager
    @EnvironmentObject private var player: PlayerStore
    @EnvironmentObject private var leaderboard: LeaderboardService
    @EnvironmentObject private var tutorial: TutorialStore
    @EnvironmentObject private var missions: MissionStore

    /// Etkileşimli öğretici koçu: oynatarak öğretir — oyuncu adımı
    /// gerçekten yapmadan (dokunup fırlatmadan) bir sonrakine geçmez.
    private enum CoachStep: Equatable {
        case hazardIntro, hazardTiming, hazardCleared   // kırmızı şerit: dondur → anlat → yaptır
        case movingIntro, movingTiming                  // hareketli halka
        case timedIntro                                 // süreli bölüm tanıtımı
        case boundsIntro                                // "kaçırmak artık elenmek" tanıtımı
    }
    @State private var coach: CoachStep?
    private var coachIsBlocking: Bool {
        coach == .hazardIntro || coach == .movingIntro || coach == .timedIntro || coach == .boundsIntro
    }

    private enum Overlay: Equatable {
        case none, paused
        case won(stars: Int)
        case endlessOver(score: Int)
        case speedrunDone(time: Double, isRecord: Bool)
    }

    @State private var scene: GameScene?
    @State private var sceneID = 0          // her yeni sahnede artar; SpriteView'i yenilemeye zorlar
    @State private var sceneCover = true    // yeni sahne kurulurken siyah kaplama (beyaz kareyi örter)
    @State private var overlay: Overlay = .none
    @State private var lumenCount = 0
    @State private var deathsThisLevel = 0
    @State private var revivedThisRun = false
    @State private var reviveFailed = false
    @State private var endlessScore = 0
    /// Premium'un sonsuz modda kalan can hakkı (HUD'da sağ üstte)
    @State private var extraLives = 0
    @State private var bonusRemaining = 0
    @State private var timeRemaining = -1      // süreli bölüm geri sayımı (-1: süresiz)
    @State private var sceneSize: CGSize = .zero
    @State private var tutorialHops = 0        // antrenman bölümünde kaç atlayış yapıldı
    @State private var celebrationKey: String? // 3 yıldız kutlama başlığı (rastgele seçilir)
    @State private var levelIntroVisible = false  // bölüm başındaki "Level X — Zorluk" kartı
    /// Yıldız eşiği geçilip açılan, henüz gösterilmemiş karakter
    @State private var orbReveal: OrbStyle?

    /// 3/3 yıldız için rastgele seçilen tebrik başlıkları (yerelleştirme anahtarları)
    private static let celebrations = ["Bravo!", "Perfect!", "Flawless!", "Spectacular!", "Legendary!"]

    // Speed run durumu
    @State private var speedIndex = 0                 // speedrunLevels içindeki sıra
    @State private var speedStart = Date()
    @State private var speedPenalty: Double = 0

    private var currentLevelID: Int? {
        switch playMode {
        case .level(let id): return id
        case .speedrun: return LevelLibrary.speedrunLevels[speedIndex]
        case .endless: return nil
        }
    }

    private var isBonusLevel: Bool {
        if case .level(let id) = playMode { return LevelLibrary.isBonus(id) }
        return false
    }

    /// İlk açılışta oynanan "nasıl oynanır" antrenman bölümü mü?
    private var isTutorialLevel: Bool {
        if case .level(let id) = playMode { return id == LevelLibrary.tutorialID }
        return false
    }

    /// Bu bölümden alınabilecek azami yıldız. "Büyük yıldız" bölümlerinde 4,
    /// diğerlerinde 3 — kutlama ve yıldız göstergeleri buna bakar.
    private var maxStarsForCurrentLevel: Int {
        if case .level(let id) = playMode { return LevelLibrary.maxStars(for: id) }
        return 3
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // SpriteView bir an geç çizerse arkada temanın koyu rengi görünsün
                // (varsayılan açık gri yerine)
                settings.theme.bgBottom.color.ignoresSafeArea()

                if let scene {
                    // Kendi yönettiğimiz TEK SKView: hiç yeniden yaratılmaz
                    // (Metal katmanının beyaz ilk karesi = yok). Sahne değişimi
                    // presentScene ile fade geçişli; HUD güncellemesinde sahne
                    // aynı kaldığından yeniden sunulmaz (top yapışmaz).
                    GameSKView(scene: scene, isPaused: overlay == .paused)
                        .ignoresSafeArea()
                }

                // Yeni sahne kurulurken (SpriteView yeniden yaratılırken Metal
                // katmanı bir kare BEYAZ oluyordu) kısa bir siyah kaplama:
                // sahne hazır olunca yumuşakça açılır. Dokunuşları engellemez,
                // oynanışa dokunmaz — yalnızca beyaz kareyi örter.
                Color.black
                    .ignoresSafeArea()
                    .opacity(sceneCover ? 1 : 0)
                    .allowsHitTesting(false)

                hud

                switch overlay {
                case .none:
                    EmptyView()
                case .paused:
                    pauseOverlay
                case .won(let stars):
                    winOverlay(stars: stars)
                case .endlessOver(let score):
                    endlessOverlay(score: score)
                case .speedrunDone(let time, let isRecord):
                    speedrunOverlay(time: time, isRecord: isRecord)
                }

                // Etkileşimli öğretici: engelleyen tanıtım kartı ya da
                // dokunuşu oyuna bırakan yönlendirme şeridi
                if overlay == .none, let step = coach {
                    if coachIsBlocking {
                        coachIntroOverlay(step)
                    } else {
                        coachBanner(step)
                    }
                }

                // Antrenman bölümü: altta adım adım yönlendiren, engellemeyen yazı
                if overlay == .none, isTutorialLevel, coach == nil {
                    tutorialCaption
                }

                // Bölüm başı kartı: "Level X" + zorluk etiketi, kısa süre görünüp söner
                if levelIntroVisible, overlay == .none {
                    levelIntro
                }

                // Yeni karakter kutlaması — bitiş ekranının da ÜSTÜNDE durur
                if let style = orbReveal {
                    OrbRevealView(style: style, theme: settings.theme) {
                        settings.orbStyleID = style.id
                        progress.markOrbRevealed(style)
                        orbReveal = progress.pendingOrbReveal()
                    } onClose: {
                        progress.markOrbRevealed(style)
                        orbReveal = progress.pendingOrbReveal()
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: coach)
            .onAppear { ensureScene(size: geo.size) }
            .onChange(of: geo.size) { _, newSize in ensureScene(size: newSize) }
            // Bölüm değişti (görünüm sabit kaldı, kaplama hep mount'ta):
            // sahneyi yenile — siyah kaplama beyaz ilk kareyi örter.
            .onChange(of: playMode) { _, _ in rebuildForLevelChange() }
        }
        .ignoresSafeArea()
    }

    /// "Next Level" ile bölüm değişince (görünüm sabit kimlikli olduğu için
    /// yıkılmaz) sahneyi yeniden kurar. installScene siyah kaplamayı önce
    /// açar; yeni SpriteView'in beyaz ilk karesi görünmez.
    private func rebuildForLevelChange() {
        lumenCount = 0
        deathsThisLevel = 0
        bonusRemaining = 0
        timeRemaining = -1
        tutorialHops = 0
        celebrationKey = nil
        overlay = .none
        coach = nil
        guard sceneSize.width > 1, sceneSize.height > 1 else { return }
        installScene(makeScene(size: sceneSize))
        showLevelIntroIfNeeded()
        startCoachIfNeeded()
    }

    /// Bu kadarlık bir boyut oynaması düzenin oturması sayılır, cihazın
    /// değişmesi değil. Eşik 1pt iken tam ekran reklam açılıp kapanırken
    /// düşen bir kaç puntoluk fark sahneyi baştan kurduruyordu.
    private static let resizeTolerance: CGFloat = 24

    /// Sahneyi yalnızca geçerli bir boyutta oluşturur. Splash→oyun geçişi
    /// sırasında düzen henüz oturmadan boyut 0 gelebiliyor; o an sahne
    /// kurulursa gri kalırdı. Boyut sonradan düzelirse sahne yeniden kurulur.
    private func ensureScene(size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        if scene == nil {
            sceneSize = size
            if case .speedrun = playMode { speedStart = Date() }
            installScene(makeScene(size: size))
            showLevelIntroIfNeeded()
            startCoachIfNeeded()
        } else if abs(sceneSize.width - size.width) > Self.resizeTolerance
                    || abs(sceneSize.height - size.height) > Self.resizeTolerance {
            // Sahne hatalı/eski boyutta kurulmuşsa (ör. geçiş anı) taze kur.
            //
            // Ama bir kaplama açıkken ASLA yeniden kurma. Tam ekran bir reklam
            // sunulup kapanırken düzen bir kare oynuyor ve buraya küçük bir
            // boyut değişimi düşüyordu; eski hâlinde bu, sonsuz mod turunu
            // silip sıfırdan sahne kuruyor ve `overlay = .none` ile bitiş
            // ekranını da kaldırıyordu. Oyuncu ödüllü reklamı izledikten sonra
            // ne turuna dönebiliyor ne de bir düğme görebiliyordu.
            guard overlay == .none else {
                sceneSize = size
                return
            }
            sceneSize = size
            coach = nil
            installScene(makeScene(size: size))
            showLevelIntroIfNeeded()
            startCoachIfNeeded()
        }
    }

    /// Yeni sahneyi kurar ve beyaz-kareyi örtmek için kısa siyah kaplamayı
    /// tetikler (sahne hazır olunca yumuşakça açılır).
    private func installScene(_ newScene: GameScene) {
        scene = newScene
        // Can hakkı sahnenin kendi kararı (mod + premium); burada tekrar
        // hesaplamak yerine ondan okunuyor
        extraLives = newScene.extraLives
        sceneID += 1
        sceneCover = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
            withAnimation(.easeOut(duration: 0.22)) { sceneCover = false }
        }
    }

    /// Bölüm başı kartı yalnızca normal bölüm modunda (öğretici hariç) gösterilir
    private func showLevelIntroIfNeeded() {
        if case .level = playMode, !isTutorialLevel { levelIntroVisible = true }
    }

    // MARK: Sahne kurulumu

    private func makeScene(size: CGSize) -> GameScene {
        let mode: GameScene.Mode
        switch playMode {
        case .level(let id): mode = .level(id)
        case .speedrun: mode = .level(LevelLibrary.speedrunLevels[speedIndex])
        case .endless: mode = .endless
        }
        let photo = settings.orbStyle.kind == .photo ? OrbPhotoStore.load() : nil
        let s = GameScene(size: size, mode: mode, theme: settings.theme,
                          orbStyle: settings.orbStyle, orbPhoto: photo,
                          isPremium: store.isPremium,
                          requiresAllLumens: playMode == .speedrun)
        s.onEvent = { event in handle(event) }
        return s
    }

    private func handle(_ event: GameEvent) {
        switch event {
        case .hop(let combo):
            AudioEngine.shared.playHop(combo: max(combo, 1))
            Haptics.shared.hop()
            progress.recordHop()
            missions.recordHops(1)
            advanceCoachAfterHop()

        case .attached(let hasHazard, let isMoving):
            if isTutorialLevel { tutorialHops += 1 }
            // Yeni mekanikli halkaya İLK kez konunca: oyunu dondur, öğret
            guard case .level = playMode, coach == nil else { break }
            if hasHazard, tutorial.shouldShow(.hazard) {
                scene?.coachFrozen = true
                coach = .hazardIntro
            } else if isMoving, tutorial.shouldShow(.moving) {
                scene?.coachFrozen = true
                coach = .movingIntro
            }

        case .collect(let total):
            lumenCount = total
            AudioEngine.shared.playCollect()
            Haptics.shared.collect()

        case .gateUnlocked:
            AudioEngine.shared.playWin()
            Haptics.shared.win()

        case .fail:
            AudioEngine.shared.playFail()
            Haptics.shared.fail()
            deathsThisLevel += 1
            if case .speedrun = playMode { speedPenalty += 2 }

        case .bonusTick(let remaining):
            bonusRemaining = remaining

        case .timeTick(let remaining):
            timeRemaining = remaining

        case .win(let stars):
            if coach == .hazardTiming || coach == .hazardCleared {
                tutorial.markShown(.hazard)
            }
            coach = nil
            // 3/3 yıldız: kutlama başlığı rastgele seçilir (Bravo!, Mükemmel!, ...)
            celebrationKey = (stars >= maxStarsForCurrentLevel && !isTutorialLevel)
                ? Self.celebrations.randomElement() : nil
            AudioEngine.shared.playWin()
            Haptics.shared.win()
            switch playMode {
            case .level(let id):
                if id == LevelLibrary.tutorialID {
                    // Antrenman bölümü: ilerlemeye yazılmaz; bir daha gösterilmez
                    tutorial.markShown(.launch)
                    tutorial.markShown(.gate)
                } else {
                    progress.complete(level: id, stars: stars)
                    missions.recordLevelCleared(deathless: deathsThisLevel == 0, starsEarned: stars)
                    missions.recordLumens(lumenCount)
                    // Oyuncunun en iyi hissettiği an: kusursuz bir bölüm
                    if stars >= maxStarsForCurrentLevel {
                        ReviewPrompt.requestAfterGreatRun(completedLevels: progress.completedCount)
                    }
                    // Bu bölümün yıldızları bir eşiği geçtiyse yeni karakter
                    // AÇILDIĞI ANDA gösterilsin; mağazada tesadüfen fark
                    // edilmeyi beklemek ödülü ödül olmaktan çıkarıyor.
                    orbReveal = progress.pendingOrbReveal()
                }
                overlay = .won(stars: stars)
            case .speedrun:
                if speedIndex < LevelLibrary.speedrunLevels.count - 1 {
                    speedIndex += 1
                    lumenCount = 0
                    installScene(makeScene(size: sceneSize))
                } else {
                    let total = Date().timeIntervalSince(speedStart) + speedPenalty
                    let isRecord = progress.recordSpeedrun(time: total)
                    if player.hasUsername {
                        leaderboard.submit(mode: .speedrun, value: total,
                                           username: player.username, playerID: player.playerID)
                    }
                    overlay = .speedrunDone(time: total, isRecord: isRecord)
                }
            case .endless:
                break
            }

        case .endlessScore(let score):
            endlessScore = score

        case .extraLifeUsed(let remaining):
            extraLives = remaining
            AudioEngine.shared.playWin()
            Haptics.shared.win()

        case .endlessGameOver(let score):
            progress.recordEndless(score: score)
            if player.hasUsername {
                leaderboard.submit(mode: .endless, value: Double(score),
                                   username: player.username, playerID: player.playerID)
            }
            AudioEngine.shared.playFail()
            overlay = .endlessOver(score: score)
        }
    }

    // MARK: HUD

    private var hud: some View {
        VStack {
            HStack {
                Button {
                    if overlay == .none { overlay = .paused }
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(.white.opacity(0.12)))
                }

                Spacer()

                centerHUD

                Spacer()

                trailingHUD
            }
            .padding(.horizontal, 20)
            .padding(.top, 58)

            Spacer()
        }
        .allowsHitTesting(overlay == .none && !coachIsBlocking)
    }

    @ViewBuilder
    private var centerHUD: some View {
        switch playMode {
        case .level(let id):
            if isTutorialLevel {
                Text("How to play")
                    .font(.system(.headline, design: .rounded).bold())
                    .foregroundStyle(.white.opacity(0.9))
            } else if isBonusLevel {
                VStack(spacing: 0) {
                    Text("Bonus!")
                        .font(.system(.caption, design: .rounded).bold())
                        .foregroundStyle(settings.theme.lumen.color)
                    Text("\(bonusRemaining)")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(bonusRemaining <= 5 ? settings.theme.hazard.color : .white)
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.3), value: bonusRemaining)
                }
            } else if LevelLibrary.hasTimer(id) {
                VStack(spacing: 0) {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.system(size: 11, weight: .bold))
                        Text("Level \(id)")
                            .font(.system(.caption, design: .rounded).bold())
                    }
                    .foregroundStyle(.white.opacity(0.7))
                    Text("\(max(timeRemaining, 0))")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(timeRemaining <= 5 ? settings.theme.hazard.color : .white)
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.3), value: timeRemaining)
                }
            } else {
                Text("Level \(id)")
                    .font(.system(.headline, design: .rounded).bold())
                    .foregroundStyle(.white.opacity(0.9))
            }
        case .speedrun:
            VStack(spacing: 0) {
                TimelineView(.periodic(from: .now, by: 0.05)) { _ in
                    Text(Self.formatTime(Date().timeIntervalSince(speedStart) + speedPenalty))
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
                Text("Level \(speedIndex + 1)/\(LevelLibrary.speedrunLevels.count)")
                    .font(.system(.caption, design: .rounded).bold())
                    .foregroundStyle(.white.opacity(0.6))
            }
        case .endless:
            Text("\(endlessScore)")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.3), value: endlessScore)
        }
    }

    @ViewBuilder
    private var trailingHUD: some View {
        if isTutorialLevel {
            Button {
                AudioEngine.shared.playTap()
                tutorial.markShown(.launch)
                tutorial.markShown(.gate)
                app.route = .game(1)
            } label: {
                Text("Skip")
                    .font(.system(.subheadline, design: .rounded).bold())
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.white.opacity(0.12)))
            }
        } else if isBonusLevel {
            HStack(spacing: 4) {
                Image(systemName: "sparkle")
                    .font(.caption)
                    .foregroundStyle(settings.theme.lumen.color)
                Text("\(lumenCount)/\(scene?.lumenTotal ?? 9)")
                    .font(.system(.subheadline, design: .rounded).bold())
                    .foregroundStyle(.white)
            }
            .frame(width: 56)
        } else if currentLevelID != nil {
            HStack(spacing: 4) {
                ForEach(0..<maxStarsForCurrentLevel, id: \.self) { i in
                    Circle()
                        .fill(i < lumenCount ? settings.theme.lumen.color : Color.white.opacity(0.2))
                        .frame(width: 10, height: 10)
                        .shadow(color: i < lumenCount ? settings.theme.lumen.opacity(0.8) : .clear, radius: 5)
                }
            }
            .frame(width: 56)
        } else if playMode == .endless && extraLives > 0 {
            // Premium oyuncular reklam izlemiyor; onun yerine tek kullanımlık
            // bir can hakları var. Kalpten kaç tane kaldığını burada gösteriyoruz.
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(settings.theme.hazard.color)
                    .shadow(color: settings.theme.hazard.opacity(0.7), radius: 6)
                Text("\(extraLives)")
                    .font(.system(.subheadline, design: .rounded).bold())
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            .frame(width: 56)
            .animation(.spring(duration: 0.3), value: extraLives)
        } else {
            Color.clear.frame(width: 56, height: 1)
        }
    }

    // MARK: Kaplamalar

    private var overlayScrim: some View {
        Color.black.opacity(0.6).ignoresSafeArea()
    }

    /// Duraklatma menüsündeki hızlı ses/titreşim düğmeleri —
    /// oyun sırasında ayarlara dönmeden kontrol edilebilir
    private var quickSettings: some View {
        HStack(spacing: 16) {
            quickToggle(icon: settings.musicOn ? "music.note" : "music.note.slash" ) {
                settings.musicOn.toggle()
            }
            quickToggle(icon: settings.sfxOn ? "speaker.wave.2.fill" : "speaker.slash.fill") {
                settings.sfxOn.toggle()
            }
            quickToggle(icon: settings.hapticsOn ? "iphone.radiowaves.left.and.right" : "iphone.slash") {
                settings.hapticsOn.toggle()
            }
        }
        .padding(.top, 6)
    }

    private func quickToggle(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 54, height: 54)
                .background(Circle().fill(.white.opacity(0.12)))
                .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1))
        }
    }

    private var pauseOverlay: some View {
        ZStack {
            overlayScrim
            VStack(spacing: 14) {
                Text("Paused")
                    .font(.system(.largeTitle, design: .rounded).bold())
                    .foregroundStyle(.white)

                quickSettings
                    .padding(.bottom, 10)

                Button { overlay = .none } label: {
                    Label("Resume", systemImage: "play.fill")
                }
                .buttonStyle(GlowButtonStyle(color: settings.theme.accent.color, prominent: true))

                Button { restart() } label: {
                    Label("Restart", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(GlowButtonStyle(color: settings.theme.ring.color))

                Button { app.route = .menu } label: {
                    Label("Main Menu", systemImage: "house.fill")
                }
                .buttonStyle(GlowButtonStyle(color: Color.white.opacity(0.7)))
            }
            .padding(.horizontal, 40)
        }
    }

    private func winOverlay(stars: Int) -> some View {
        ZStack {
            overlayScrim
            VStack(spacing: 18) {
                if let celebration = celebrationKey {
                    // 3/3 yıldız: coşkulu, altın parlaklı tebrik başlığı
                    VStack(spacing: 6) {
                        Text(LocalizedStringKey(celebration))
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundStyle(settings.theme.lumen.color)
                            .shadow(color: settings.theme.lumen.opacity(0.9), radius: 18)
                        Text(isBonusLevel ? "Bonus Complete!" : "Level Complete!")
                            .font(.system(.subheadline, design: .rounded).bold())
                            .foregroundStyle(.white.opacity(0.75))
                    }
                } else {
                    Text(isTutorialLevel ? "You're ready!"
                         : isBonusLevel ? "Bonus Complete!" : "Level Complete!")
                        .font(.system(.largeTitle, design: .rounded).bold())
                        .foregroundStyle(.white)
                }

                if isBonusLevel {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkle")
                            .foregroundStyle(settings.theme.lumen.color)
                        Text("\(lumenCount)/\(scene?.lumenTotal ?? 9)")
                            .font(.system(.title3, design: .rounded).bold())
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }

                if !isTutorialLevel {   // antrenmanda yıldız yok
                    StarsView(count: stars, total: maxStarsForCurrentLevel,
                              size: 34, color: settings.theme.lumen.color)
                        .padding(.vertical, 8)
                }

                if case .level(let id) = playMode {
                    if id == LevelLibrary.tutorialID {
                        // Antrenman bitti → doğrudan 1. bölüme (reklamsız geçiş)
                        Button { app.route = .game(1) } label: {
                            Label("Next Level", systemImage: "play.fill")
                        }
                        .buttonStyle(GlowButtonStyle(color: settings.theme.accent.color, prominent: true))
                    } else if id < LevelLibrary.count {
                        Button {
                            _ = ads.levelCompleted(level: id, isPremium: store.isPremium) {
                                app.route = .game(id + 1)
                            }
                        } label: {
                            Label("Next Level", systemImage: "arrow.right")
                        }
                        .buttonStyle(GlowButtonStyle(color: settings.theme.accent.color, prominent: true))
                    } else {
                        Text("You finished all levels! 🎉")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(settings.theme.lumen.color)
                        Button {
                            _ = ads.levelCompleted(level: id, isPremium: store.isPremium) {
                                app.route = .endless
                            }
                        } label: {
                            Label("Enter Endless Mode", systemImage: "infinity")
                        }
                        .buttonStyle(GlowButtonStyle(color: settings.theme.gate.color, prominent: true))
                    }

                    // Bonus turlar bir kere oynanır — tekrar oynatma yok
                    if !isBonusLevel {
                        Button { restart() } label: {
                            Label("Play Again", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(GlowButtonStyle(color: settings.theme.ring.color))
                    }
                }

                Button { app.route = .menu } label: {
                    Label("Main Menu", systemImage: "house.fill")
                }
                .buttonStyle(GlowButtonStyle(color: Color.white.opacity(0.7)))
            }
            .padding(.horizontal, 40)
        }
    }

    private func endlessOverlay(score: Int) -> some View {
        ZStack {
            overlayScrim
            VStack(spacing: 14) {
                Text("Game Over")
                    .font(.system(.largeTitle, design: .rounded).bold())
                    .foregroundStyle(.white)

                Text("\(score)")
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundStyle(settings.theme.accent.color)
                    .shadow(color: settings.theme.accent.opacity(0.7), radius: 18)

                if score >= progress.endlessBest && score > 0 {
                    Label("New Record!", systemImage: "trophy.fill")
                        .font(.system(.headline, design: .rounded).bold())
                        .foregroundStyle(settings.theme.lumen.color)
                } else {
                    Text("Best: \(progress.endlessBest)")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }

                // Koşu başına bir kez: reklam izleyip skoru koruyarak devam et
                if !revivedThisRun, !store.isPremium {
                    Button {
                        AudioEngine.shared.playTap()
                        ads.showRewarded { earned in
                            guard earned else { return }
                            // Bitiş ekranı YALNIZCA canlanma gerçekten
                            // tuttuysa kapanır. Önce kapatıp sonra canlandırmak,
                            // canlanma tutmadığında oyuncuyu düğmesiz ve ölü bir
                            // ekranda bırakıyordu.
                            guard let scene, scene.reviveEndless() else {
                                reviveFailed = true
                                return
                            }
                            revivedThisRun = true
                            overlay = .none
                            reviveFailed = false
                            Haptics.shared.win()
                        }
                    } label: {
                        Label("Continue — watch an ad", systemImage: "play.rectangle.fill")
                    }
                    .buttonStyle(GlowButtonStyle(color: settings.theme.lumen.color, prominent: true))
                    .padding(.top, 10)

                    if reviveFailed {
                        Label("Couldn't bring you back — tap Try Again",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    // Reklam gelmediyse ya da ödül kazanılmadıysa düğme sessizce
                    // hiçbir şey yapmış gibi görünüyordu; sebebi burada söylenir.
                    if let notice = ads.rewardNotice {
                        Label(notice == .unavailable
                              ? "No ad available right now — try again in a bit"
                              : "Ad closed early — no extra life this time",
                              systemImage: "info.circle.fill")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .onTapGesture { ads.dismissRewardNotice() }
                    }
                }

                Button {
                    _ = ads.endlessEnded(isPremium: store.isPremium,
                                         endlessUnlocked: progress.endlessUnlocked) {
                        restart()
                    }
                } label: {
                    Label("Try Again", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(GlowButtonStyle(color: settings.theme.accent.color,
                                             prominent: revivedThisRun || store.isPremium))
                .padding(.top, revivedThisRun || store.isPremium ? 10 : 0)

                Button { player.hasUsername ? (app.route = .ranking) : app.openUsername() } label: {
                    Label("World Ranking", systemImage: "globe")
                }
                .buttonStyle(GlowButtonStyle(color: settings.theme.gate.color))

                Button { app.route = .menu } label: {
                    Label("Main Menu", systemImage: "house.fill")
                }
                .buttonStyle(GlowButtonStyle(color: Color.white.opacity(0.7)))
            }
            .padding(.horizontal, 40)
        }
    }

    private func speedrunOverlay(time: Double, isRecord: Bool) -> some View {
        ZStack {
            overlayScrim
            VStack(spacing: 14) {
                Text("Speed Run")
                    .font(.system(.largeTitle, design: .rounded).bold())
                    .foregroundStyle(.white)

                Text(Self.formatTime(time))
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(settings.theme.gate.color)
                    .shadow(color: settings.theme.gate.opacity(0.7), radius: 18)

                if isRecord {
                    Label("New Record!", systemImage: "trophy.fill")
                        .font(.system(.headline, design: .rounded).bold())
                        .foregroundStyle(settings.theme.lumen.color)
                } else {
                    Text("Best Time: \(Self.formatTime(progress.speedrunBest))")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }

                if speedPenalty > 0 {
                    Text("+\(Int(speedPenalty))s")
                        .font(.system(.footnote, design: .rounded).bold())
                        .foregroundStyle(settings.theme.hazard.color)
                }

                Button { restart() } label: {
                    Label("Try Again", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(GlowButtonStyle(color: settings.theme.accent.color, prominent: true))
                .padding(.top, 10)

                Button { player.hasUsername ? (app.route = .ranking) : app.openUsername() } label: {
                    Label("World Ranking", systemImage: "globe")
                }
                .buttonStyle(GlowButtonStyle(color: settings.theme.gate.color))

                Button { app.route = .menu } label: {
                    Label("Main Menu", systemImage: "house.fill")
                }
                .buttonStyle(GlowButtonStyle(color: Color.white.opacity(0.7)))
            }
            .padding(.horizontal, 40)
        }
    }

    // MARK: Etkileşimli öğretici koçu

    /// İlk süreli bölümde oyunu dondurup geri sayımı tanıt.
    /// (Temel mekanik antrenman bölümünde YAZISIZ öğretilir: nişan çizgisi +
    /// dokunuş ipucu sahnenin kendi içindedir.)
    private func startCoachIfNeeded() {
        guard case .level(let id) = playMode else { return }
        if !LevelLibrary.isForgiving(id), tutorial.shouldShow(.bounds) {
            // İlk katı bölüm: artık ekrandan çıkmak = elenmek — bir kez tanıt
            scene?.coachFrozen = true
            coach = .boundsIntro
        } else if LevelLibrary.hasTimer(id), tutorial.shouldShow(.timed) {
            scene?.coachFrozen = true
            coach = .timedIntro
        }
    }

    /// Oyuncu gerçekten fırlatıp yeni halkaya geçince koç bir adım ilerler
    private func advanceCoachAfterHop() {
        switch coach {
        case .hazardTiming:
            coach = .hazardCleared
            tutorial.markShown(.hazard)
            Task {
                try? await Task.sleep(for: .seconds(1.8))
                if coach == .hazardCleared { coach = nil }
            }
        case .movingTiming:
            coach = nil
            tutorial.markShown(.moving)
        default:
            break
        }
    }

    /// Engelleyen tanıtım kartı kapatılınca oyun çözülür, yaptırma adımı başlar
    private func dismissCoachIntro() {
        AudioEngine.shared.playTap()
        switch coach {
        case .hazardIntro:
            scene?.coachFrozen = false
            coach = .hazardTiming
        case .movingIntro:
            scene?.coachFrozen = false
            coach = .movingTiming
        case .timedIntro:
            scene?.coachFrozen = false
            coach = nil
            tutorial.markShown(.timed)
        case .boundsIntro:
            tutorial.markShown(.bounds)
            // Aynı bölüm süreliyse sıradaki kartı göster (dondurma sürsün)
            if case .level(let id) = playMode, LevelLibrary.hasTimer(id), tutorial.shouldShow(.timed) {
                coach = .timedIntro
            } else {
                scene?.coachFrozen = false
                coach = nil
            }
        default: break
        }
    }

    /// Oyunu donduran tanıtım kartı (kırmızı şerit / hareketli halka / süreli bölüm ilk kez)
    private func coachIntroOverlay(_ step: CoachStep) -> some View {
        let hint: TutorialHint
        let color: Color
        switch step {
        case .hazardIntro: hint = .hazard; color = settings.theme.hazard.color
        case .timedIntro:  hint = .timed;  color = settings.theme.lumen.color
        case .boundsIntro: hint = .bounds; color = settings.theme.hazard.color
        default:           hint = .moving; color = settings.theme.accent.color
        }
        return ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: hint.systemImage)
                    .font(.system(size: 52))
                    .foregroundStyle(color)
                    .shadow(color: color.opacity(0.7), radius: 16)

                Text(LocalizedStringKey(hint.titleKey))
                    .font(.system(.title, design: .rounded).bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(LocalizedStringKey(hint.bodyKey))
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Label("Tap to continue", systemImage: "hand.tap.fill")
                    .font(.system(.subheadline, design: .rounded).bold())
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 10)
                    .symbolEffect(.pulse, options: .repeating)
            }
            .padding(.horizontal, 32)
        }
        .contentShape(Rectangle())
        .onTapGesture { dismissCoachIntro() }
        .transition(.opacity)
    }

    /// Dokunuşu oyuna bırakan yönlendirme şeridi — oyuncu adımı yapana dek kalır
    private func coachBanner(_ step: CoachStep) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                Image(systemName: bannerIcon(step))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(bannerColor(step))
                    .symbolEffect(.pulse, options: .repeating)
                Text(bannerText(step))
                    .font(.system(.subheadline, design: .rounded).bold())
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.black.opacity(0.55))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(bannerColor(step).opacity(0.5), lineWidth: 1)
                    }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 48)
        }
        .allowsHitTesting(false)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    /// Bölüm zorluk etiketi (yerelleştirme anahtarı). Öğretici/bonus için yok.
    static func difficultyKey(for id: Int) -> String? {
        guard id != LevelLibrary.tutorialID, !LevelLibrary.isBonus(id) else { return nil }
        // 100 normal bölüme dengeli dağılım (zorluk eğrisiyle uyumlu)
        switch LevelLibrary.normalIndex(id) {
        case ..<6:  return "Easy"
        case ..<20: return "Medium"
        case ..<45: return "Hard"
        case ..<75: return "Very Hard"
        default:    return "Extreme"
        }
    }

    private func difficultyColor(for id: Int) -> Color {
        switch Self.difficultyKey(for: id) {
        case "Easy":   return settings.theme.gate.color
        case "Medium": return settings.theme.accent.color
        case "Hard":   return settings.theme.lumen.color
        default:       return settings.theme.hazard.color
        }
    }

    /// Bölüm başında ~1,6 sn görünen tanıtım kartı: bölüm numarası + zorluk rozeti
    @ViewBuilder
    private var levelIntro: some View {
        if case .level(let id) = playMode, !isTutorialLevel {
            VStack(spacing: 10) {
                Text(LevelLibrary.isBonus(id) ? "Bonus!" : "Level \(id)")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: settings.theme.accent.opacity(0.8), radius: 16)
                if let key = Self.difficultyKey(for: id) {
                    Text(LocalizedStringKey(key))
                        .font(.system(.subheadline, design: .rounded).bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(difficultyColor(for: id)))
                }
            }
            .padding(.vertical, 26)
            .padding(.horizontal, 40)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.black.opacity(0.45))
            }
            .allowsHitTesting(false)
            .transition(.opacity)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    withAnimation(.easeOut(duration: 0.4)) { levelIntroVisible = false }
                }
            }
        }
    }

    /// Antrenman bölümünde altta beliren, adım adım yönlendiren yazı.
    /// Engellemez (dokunuşları oyuna geçirir); atlayış sayısına göre değişir.
    private var tutorialCaption: some View {
        let text: LocalizedStringKey = tutorialHops == 0
            ? "Tap anywhere — launch the orb toward the next ring"
            : "Collect the yellow stars and reach the green gate ✨"
        return VStack {
            Spacer()
            Text(text)
                .font(.system(.subheadline, design: .rounded).bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.black.opacity(0.5))
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 44)
                .id(tutorialHops)   // metin değişince yumuşak geçiş
                .transition(.opacity)
        }
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.3), value: tutorialHops)
    }

    private func bannerText(_ step: CoachStep) -> LocalizedStringKey {
        switch step {
        case .hazardTiming:  return "Wait for the red arc to move away… then tap!"
        case .hazardCleared: return "Perfect! You passed the red arc."
        case .movingTiming:  return "This ring drifts — time your jump!"
        default:             return ""
        }
    }

    private func bannerIcon(_ step: CoachStep) -> String {
        switch step {
        case .hazardTiming:  return "exclamationmark.triangle.fill"
        case .hazardCleared: return "checkmark.circle.fill"
        case .movingTiming:  return "arrow.left.and.right"
        default:             return "hand.tap.fill"
        }
    }

    private func bannerColor(_ step: CoachStep) -> Color {
        switch step {
        case .hazardTiming:  return settings.theme.hazard.color
        case .hazardCleared: return settings.theme.gate.color
        default:             return settings.theme.accent.color
        }
    }

    private func restart() {
        lumenCount = 0
        deathsThisLevel = 0
        revivedThisRun = false
        reviveFailed = false
        endlessScore = 0
        extraLives = store.isPremium && playMode == .endless ? 1 : 0
        bonusRemaining = 0
        timeRemaining = -1
        speedIndex = 0
        speedPenalty = 0
        speedStart = Date()
        tutorialHops = 0
        celebrationKey = nil
        overlay = .none
        coach = nil
        installScene(makeScene(size: sceneSize))
        showLevelIntroIfNeeded()
        startCoachIfNeeded()
    }

    static func formatTime(_ t: Double) -> String {
        let minutes = Int(t) / 60
        let seconds = Int(t) % 60
        let hundredths = Int((t - floor(t)) * 100)
        return String(format: "%d:%02d.%02d", minutes, seconds, hundredths)
    }
}

/// Kendi yönettiğimiz tek SKView. SwiftUI'nin SpriteView'i her sahne
/// değişiminde Metal katmanını (SKView/MTKView) yeniden yaratıyor ve ilk kare
/// BEYAZ oluyordu. Burada SKView bir kez oluşturulur, hiç yıkılmaz; sahneler
/// içine presentScene ile sunulur — beyaz kare imkânsız.
///
/// Sahne YALNIZCA gerçekten değiştiğinde (kimlik kontrolü) yeniden sunulur;
/// HUD güncellemesinde (yıldız/süre) updateUIView çağrılsa da sahne aynı
/// kaldığından yeniden sunulmaz — top başlangıca dönüp "yapışmaz".
private struct GameSKView: UIViewRepresentable {
    let scene: GameScene
    let isPaused: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SKView {
        // ÖNEMLİ: SKView'i sahne boyutuyla başlat. Sıfır çerçeveli bir view'e
        // sunulursa resizeFill sahneyi sıfıra küçültür, didMove halkaları/topu
        // sıfır boyutta kurar ve "eksik/görünmez" olurlar.
        let view = SKView(frame: CGRect(origin: .zero, size: scene.size))
        view.ignoresSiblingOrder = true
        view.backgroundColor = .black          // hiçbir anda beyaz görünmez
        view.isPaused = isPaused
        view.presentScene(scene)
        context.coordinator.presentedScene = scene
        return view
    }

    func updateUIView(_ view: SKView, context: Context) {
        // Sahne yalnızca gerçekten değiştiyse (yeni bölüm) yeniden sunulur;
        // view geçerli bir boyuta sahipse fade ile, değilse (henüz düzen
        // oturmadıysa) doğrudan — böylece halkalar/top her zaman doğru boyutta.
        if context.coordinator.presentedScene !== scene {
            context.coordinator.presentedScene = scene
            if view.bounds.width > 1, view.bounds.height > 1 {
                view.presentScene(scene, transition: .fade(with: UIColor.black, duration: 0.28))
            } else {
                view.presentScene(scene)
            }
        }
        view.isPaused = isPaused
    }

    final class Coordinator {
        weak var presentedScene: GameScene?
    }
}
