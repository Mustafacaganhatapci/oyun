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
    @EnvironmentObject private var gameCenter: GameCenterService

    private enum Overlay: Equatable {
        case none, paused
        case won(stars: Int)
        case endlessOver(score: Int)
        case speedrunDone(time: Double, isRecord: Bool)
    }

    @State private var scene: GameScene?
    @State private var overlay: Overlay = .none
    @State private var lumenCount = 0
    @State private var endlessScore = 0
    @State private var bonusRemaining = 0
    @State private var sceneSize: CGSize = .zero

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

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let scene {
                    SpriteView(scene: scene, isPaused: overlay == .paused)
                        .ignoresSafeArea()
                }

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
            }
            .onAppear {
                sceneSize = geo.size
                if scene == nil {
                    if case .speedrun = playMode { speedStart = Date() }
                    scene = makeScene(size: geo.size)
                }
            }
        }
        .ignoresSafeArea()
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
                          orbStyle: settings.orbStyle, orbPhoto: photo)
        s.onEvent = { event in handle(event) }
        return s
    }

    private func handle(_ event: GameEvent) {
        switch event {
        case .hop(let combo):
            AudioEngine.shared.playHop(combo: max(combo, 1))
            Haptics.shared.hop()
            progress.recordHop()

        case .collect(let total):
            lumenCount = total
            AudioEngine.shared.playCollect()
            Haptics.shared.collect()

        case .fail:
            AudioEngine.shared.playFail()
            Haptics.shared.fail()
            if case .speedrun = playMode { speedPenalty += 2 }

        case .bonusTick(let remaining):
            bonusRemaining = remaining

        case .win(let stars):
            AudioEngine.shared.playWin()
            Haptics.shared.win()
            switch playMode {
            case .level(let id):
                progress.complete(level: id, stars: stars)
                overlay = .won(stars: stars)
            case .speedrun:
                if speedIndex < LevelLibrary.speedrunLevels.count - 1 {
                    speedIndex += 1
                    lumenCount = 0
                    scene = makeScene(size: sceneSize)
                } else {
                    let total = Date().timeIntervalSince(speedStart) + speedPenalty
                    let isRecord = progress.recordSpeedrun(time: total)
                    gameCenter.submitSpeedrun(seconds: total)
                    overlay = .speedrunDone(time: total, isRecord: isRecord)
                }
            case .endless:
                break
            }

        case .endlessScore(let score):
            endlessScore = score

        case .endlessGameOver(let score):
            progress.recordEndless(score: score)
            gameCenter.submitEndless(score: score)
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
        .allowsHitTesting(overlay == .none)
    }

    @ViewBuilder
    private var centerHUD: some View {
        switch playMode {
        case .level(let id):
            if isBonusLevel {
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
        if isBonusLevel {
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
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(i < lumenCount ? settings.theme.lumen.color : Color.white.opacity(0.2))
                        .frame(width: 10, height: 10)
                        .shadow(color: i < lumenCount ? settings.theme.lumen.opacity(0.8) : .clear, radius: 5)
                }
            }
            .frame(width: 56)
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
                Text(isBonusLevel ? "Bonus Complete!" : "Level Complete!")
                    .font(.system(.largeTitle, design: .rounded).bold())
                    .foregroundStyle(.white)

                if isBonusLevel {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkle")
                            .foregroundStyle(settings.theme.lumen.color)
                        Text("\(lumenCount)/\(scene?.lumenTotal ?? 9)")
                            .font(.system(.title3, design: .rounded).bold())
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }

                StarsView(count: stars, size: 34, color: settings.theme.lumen.color)
                    .padding(.vertical, 8)

                if case .level(let id) = playMode {
                    if id < LevelLibrary.count {
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

                    Button { restart() } label: {
                        Label("Play Again", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(GlowButtonStyle(color: settings.theme.ring.color))
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

                Button {
                    _ = ads.endlessEnded(isPremium: store.isPremium,
                                         endlessUnlocked: progress.endlessUnlocked) {
                        restart()
                    }
                } label: {
                    Label("Try Again", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(GlowButtonStyle(color: settings.theme.accent.color, prominent: true))
                .padding(.top, 10)

                Button { gameCenter.showLeaderboards() } label: {
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

                Button { gameCenter.showLeaderboards() } label: {
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

    private func restart() {
        lumenCount = 0
        endlessScore = 0
        bonusRemaining = 0
        speedIndex = 0
        speedPenalty = 0
        speedStart = Date()
        overlay = .none
        scene = makeScene(size: sceneSize)
    }

    static func formatTime(_ t: Double) -> String {
        let minutes = Int(t) / 60
        let seconds = Int(t) % 60
        let hundredths = Int((t - floor(t)) * 100)
        return String(format: "%d:%02d.%02d", minutes, seconds, hundredths)
    }
}
