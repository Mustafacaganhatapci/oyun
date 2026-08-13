import SwiftUI

/// Dünya sıralaması. Firebase bağlıysa küresel ilk 50; değilse yerel en iyi + kurulum ipucu.
struct WorldRankingView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var player: PlayerStore
    @EnvironmentObject private var leaderboard: LeaderboardService

    @State private var mode: LeaderboardMode = .endless

    private var entries: [LeaderboardEntry] {
        mode == .endless ? leaderboard.endlessEntries : leaderboard.speedrunEntries
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            // Mod seçici
            Picker("", selection: $mode) {
                Text("Endless").tag(LeaderboardMode.endless)
                Text("Speed Run").tag(LeaderboardMode.speedrun)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .onChange(of: mode) { _, _ in load() }

            if !leaderboard.isAvailable {
                notConnected
            } else if leaderboard.isLoading && entries.isEmpty {
                Spacer()
                ProgressView().tint(.white)
                Spacer()
            } else if entries.isEmpty {
                Spacer()
                Text("No scores yet — be the first!")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
            } else {
                list
            }
        }
        .onAppear(perform: load)
    }

    private var header: some View {
        HStack {
            BackButton { app.route = .menu }
            Spacer()
            Text("World Ranking")
                .font(.system(.title2, design: .rounded).bold())
                .foregroundStyle(.white)
            Spacer()
            Button { app.openUsername() } label: {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.white.opacity(0.12)))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    HStack(spacing: 14) {
                        Text("\(index + 1)")
                            .font(.system(.headline, design: .rounded).bold())
                            .foregroundStyle(rankColor(index))
                            .frame(width: 34, alignment: .center)

                        Text(entry.username)
                            .font(.system(.body, design: .rounded).bold())
                            .foregroundStyle(entry.isMe ? settings.theme.accent.color : .white)
                            .lineLimit(1)
                        if entry.isMe {
                            Text("you")
                                .font(.system(.caption2, design: .rounded).bold())
                                .foregroundStyle(settings.theme.accent.color)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(settings.theme.accent.opacity(0.2)))
                        }

                        Spacer()

                        Text(valueText(entry.value))
                            .font(.system(.body, design: .rounded).bold())
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(entry.isMe ? settings.theme.accent.opacity(0.12) : .white.opacity(0.05))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 30)
        }
    }

    private var notConnected: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "globe.badge.chevron.backward")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.5))
            Text("Global ranking not connected")
                .font(.system(.headline, design: .rounded).bold())
                .foregroundStyle(.white)
            Text("Add Firebase to enable the world ranking (see README). Your local best is shown below.")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 4) {
                Text("Your best")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                Text(localBestText)
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(settings.theme.accent.color)
            }
            .padding(.top, 10)
            Spacer()
            Spacer()
        }
    }

    private var localBestText: String {
        if mode == .endless {
            return "\(progress.endlessBest)"
        } else {
            return progress.speedrunBest > 0 ? GameContainerView.formatTime(progress.speedrunBest) : "—"
        }
    }

    private func valueText(_ v: Double) -> String {
        mode == .endless ? "\(Int(v))" : GameContainerView.formatTime(v)
    }

    private func rankColor(_ index: Int) -> Color {
        switch index {
        case 0: return settings.theme.lumen.color
        case 1: return .white.opacity(0.85)
        case 2: return Color(red: 0.8, green: 0.5, blue: 0.3)
        default: return .white.opacity(0.5)
        }
    }

    /// Kendi en iyi skorunu gönder + tabloyu getir
    private func load() {
        guard leaderboard.isAvailable else { return }
        if player.hasUsername {
            let best: Double = mode == .endless ? Double(progress.endlessBest) : progress.speedrunBest
            if best > 0 {
                leaderboard.submit(mode: mode, value: best,
                                   username: player.username, playerID: player.playerID)
            }
        }
        leaderboard.refresh(mode: mode, myPlayerID: player.playerID)
    }
}
