import SwiftUI

struct LevelSelectView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var settings: SettingsStore

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 4)

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BackButton { app.route = .menu }
                Spacer()
                Text("Levels")
                    .font(.system(.title2, design: .rounded).bold())
                    .foregroundStyle(.white)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.footnote)
                        .foregroundStyle(settings.theme.lumen.color)
                    Text("\(progress.totalStars)")
                        .font(.system(.subheadline, design: .rounded).bold())
                        .foregroundStyle(.white.opacity(0.85))
                }
                .frame(width: 44)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            ScrollView {
                // İlk 10 bölüm reklamsız — oyuncuya bunu gururla söylüyoruz
                Label("The first \(LevelLibrary.adFreeLevels) levels are completely ad-free", systemImage: "sparkles")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 14)

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(1...LevelLibrary.count, id: \.self) { id in
                        LevelCell(id: id,
                                  stars: progress.stars[id] ?? 0,
                                  unlocked: progress.isUnlocked(id),
                                  theme: settings.theme) {
                            AudioEngine.shared.playTap()
                            app.route = .game(id)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 40)
            }
        }
    }
}

private struct LevelCell: View {
    let id: Int
    let stars: Int
    let unlocked: Bool
    let theme: Theme
    let action: () -> Void

    var body: some View {
        Button {
            if unlocked { action() }
        } label: {
            VStack(spacing: 6) {
                if unlocked {
                    Text("\(id)")
                        .font(.system(.title2, design: .rounded).bold())
                        .foregroundStyle(.white)
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: i < stars ? "star.fill" : "star")
                                .font(.system(size: 8))
                                .foregroundStyle(i < stars ? theme.lumen.color : .white.opacity(0.25))
                        }
                    }
                } else {
                    Image(systemName: "lock.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 74)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(unlocked ? theme.ring.opacity(0.16) : Color.white.opacity(0.05))
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(unlocked
                                  ? (stars == 3 ? theme.lumen.opacity(0.7) : theme.ring.opacity(0.45))
                                  : Color.white.opacity(0.08),
                                  lineWidth: 1.5)
            }
        }
        .disabled(!unlocked)
    }
}
