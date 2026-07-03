import SwiftUI
import SpriteKit

struct GameContainerView: View {
    let levelID: Int?   // nil = sonsuz mod

    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var ads: AdsManager

    private enum Overlay: Equatable {
        case none, paused
        case won(stars: Int)
        case endlessOver(score: Int)
    }

    @State private var scene: GameScene?
    @State private var overlay: Overlay = .none
    @State private var lumenCount = 0
    @State private var endlessScore = 0
    @State private var sceneSize: CGSize = .zero

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
                }
            }
            .onAppear {
                sceneSize = geo.size
                if scene == nil { scene = makeScene(size: geo.size) }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: Sahne kurulumu

    private func makeScene(size: CGSize) -> GameScene {
        let mode: GameScene.Mode = levelID.map { .level($0) } ?? .endless
        let s = GameScene(size: size, mode: mode, theme: settings.theme)
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
        case .win(let stars):
            AudioEngine.shared.playWin()
            Haptics.shared.win()
            if let id = levelID {
                progress.complete(level: id, stars: stars)
            }
            overlay = .won(stars: stars)
        case .endlessScore(let score):
            endlessScore = score
        case .endlessGameOver(let score):
            progress.recordEndless(score: score)
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

                if let id = levelID {
                    Text("Level \(id)")
                        .font(.system(.headline, design: .rounded).bold())
                        .foregroundStyle(.white.opacity(0.9))
                } else {
                    Text("\(endlessScore)")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.3), value: endlessScore)
                }

                Spacer()

                if levelID != nil {
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(i < lumenCount ? settings.theme.lumen.color : Color.white.opacity(0.2))
                                .frame(width: 10, height: 10)
                                .shadow(color: i < lumenCount ? settings.theme.lumen.opacity(0.8) : .clear, radius: 5)
                        }
                    }
                    .frame(width: 42)
                } else {
                    Color.clear.frame(width: 42, height: 1)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 58)

            Spacer()
        }
        .allowsHitTesting(overlay == .none)
    }

    // MARK: Kaplamalar

    private var overlayScrim: some View {
        Color.black.opacity(0.6).ignoresSafeArea()
    }

    private var pauseOverlay: some View {
        ZStack {
            overlayScrim
            VStack(spacing: 14) {
                Text("Paused")
                    .font(.system(.largeTitle, design: .rounded).bold())
                    .foregroundStyle(.white)
                    .padding(.bottom, 12)

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
                Text("Level Complete!")
                    .font(.system(.largeTitle, design: .rounded).bold())
                    .foregroundStyle(.white)

                StarsView(count: stars, size: 34, color: settings.theme.lumen.color)
                    .padding(.vertical, 8)

                if let id = levelID {
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
        overlay = .none
        scene = makeScene(size: sceneSize)
    }
}
