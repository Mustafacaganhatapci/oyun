import SwiftUI

/// Bölüm haritası: kıvrılan (yılan şeklinde) bir patika üzerinde ilerlenir.
/// 1. bölüm en altta başlar, yukarı doğru tırmanılır; bonus turlar altın rengidir.
struct LevelSelectView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var settings: SettingsStore

    private let nodeSpacing: CGFloat = 96
    private let topPadding: CGFloat = 60
    private let bottomPadding: CGFloat = 80

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

            GeometryReader { geo in
                let width = geo.size.width
                let contentHeight = CGFloat(LevelLibrary.count) * nodeSpacing + topPadding + bottomPadding

                ScrollView {
                    ZStack(alignment: .topLeading) {
                        // Patika çizgisi — düğümleri birbirine bağlar
                        Canvas { context, _ in
                            var path = Path()
                            let points = (1...LevelLibrary.count).map { position(for: $0, width: width, contentHeight: contentHeight) }
                            guard let first = points.first else { return }
                            path.move(to: first)
                            for i in 1..<points.count {
                                let prev = points[i - 1]
                                let cur = points[i]
                                let mid = CGPoint(x: (prev.x + cur.x) / 2, y: (prev.y + cur.y) / 2)
                                path.addQuadCurve(to: mid,
                                                  control: CGPoint(x: prev.x, y: (prev.y + mid.y) / 2))
                                path.addQuadCurve(to: cur,
                                                  control: CGPoint(x: cur.x, y: (mid.y + cur.y) / 2))
                            }
                            context.stroke(path,
                                           with: .color(settings.theme.ring.opacity(0.28)),
                                           style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [1, 12]))
                        }
                        .frame(width: width, height: contentHeight)

                        ForEach(1...LevelLibrary.count, id: \.self) { id in
                            LevelNode(id: id,
                                      stars: progress.stars[id] ?? 0,
                                      unlocked: progress.isUnlocked(id),
                                      isCurrent: id == progress.highestUnlocked && (progress.stars[id] ?? 0) == 0,
                                      isBonus: LevelLibrary.isBonus(id),
                                      theme: settings.theme) {
                                AudioEngine.shared.playTap()
                                app.route = .game(id)
                            }
                            .position(position(for: id, width: width, contentHeight: contentHeight))
                        }
                    }
                    .frame(width: width, height: contentHeight)

                    Label("The first \(LevelLibrary.adFreeLevels) levels are completely ad-free", systemImage: "sparkles")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.bottom, 24)
                }
                .defaultScrollAnchor(initialAnchor(viewport: geo.size, contentHeight: contentHeight))
            }
        }
    }

    /// Yılan patikası: 1. bölüm altta, sinüs dalgasıyla sağa-sola kıvrılarak yükselir
    private func position(for id: Int, width: CGFloat, contentHeight: CGFloat) -> CGPoint {
        let index = CGFloat(id - 1)
        let y = contentHeight - bottomPadding - index * nodeSpacing
        let x = width * (0.5 + 0.30 * sin(Double(index) * 0.85))
        return CGPoint(x: x, y: y)
    }

    /// Açılışta harita, oyuncunun kaldığı bölüm ekranın ortasına gelecek şekilde kaydırılır
    private func initialAnchor(viewport: CGSize, contentHeight: CGFloat) -> UnitPoint {
        let current = min(max(progress.highestUnlocked, 1), LevelLibrary.count)
        let y = contentHeight - bottomPadding - CGFloat(current - 1) * nodeSpacing
        let denom = max(contentHeight - viewport.height, 1)
        let fraction = (y - viewport.height / 2) / denom
        return UnitPoint(x: 0.5, y: min(max(fraction, 0), 1))
    }
}

private struct LevelNode: View {
    let id: Int
    let stars: Int
    let unlocked: Bool
    let isCurrent: Bool
    let isBonus: Bool
    let theme: Theme
    let action: () -> Void

    @State private var pulse = false

    private var accent: Color { isBonus ? theme.lumen.color : theme.ring.color }

    var body: some View {
        Button {
            if unlocked { action() }
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    if isCurrent {
                        Circle()
                            .fill(accent.opacity(0.3))
                            .frame(width: 76, height: 76)
                            .scaleEffect(pulse ? 1.15 : 0.9)
                            .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)
                            .onAppear { pulse = true }
                    }

                    Circle()
                        .fill(unlocked ? accent.opacity(isBonus ? 0.28 : 0.18) : Color.white.opacity(0.06))
                        .frame(width: 58, height: 58)

                    Circle()
                        .strokeBorder(unlocked
                                      ? (stars == 3 ? theme.lumen.color : accent.opacity(0.7))
                                      : Color.white.opacity(0.12),
                                      style: isBonus
                                      ? StrokeStyle(lineWidth: 2, dash: [5, 4])
                                      : StrokeStyle(lineWidth: 2))
                        .frame(width: 58, height: 58)

                    if unlocked {
                        if isBonus {
                            VStack(spacing: 0) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(theme.lumen.color)
                                Text("\(id)")
                                    .font(.system(.caption2, design: .rounded).bold())
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        } else {
                            Text("\(id)")
                                .font(.system(.title3, design: .rounded).bold())
                                .foregroundStyle(.white)
                        }
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }

                if unlocked {
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: i < stars ? "star.fill" : "star")
                                .font(.system(size: 8))
                                .foregroundStyle(i < stars ? theme.lumen.color : .white.opacity(0.25))
                        }
                    }
                }
            }
        }
        .disabled(!unlocked)
    }
}
