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
                // Genişlik SABİT 44'tü. Toplam üç haneye çıkınca ("806") sayı
                // yıldızın yanına sığmayıp altına kayıyor, sayaç iki satır
                // olup köşeye yapışıyordu. Alt sınır 44 (geri düğmesiyle
                // simetri), üstü serbest; satır da tek.
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.footnote)
                        .foregroundStyle(settings.theme.lumen.color)
                    Text("\(progress.totalStars)")
                        .font(.system(.subheadline, design: .rounded).bold())
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                        .fixedSize()
                }
                .frame(minWidth: 44, alignment: .trailing)
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
                                      // Bonus turlar bir kere oynanır — tamamlandıysa harita üzerinden bir daha açılmaz
                                      isBonusCompleted: LevelLibrary.isBonus(id) && progress.stars[id] != nil,
                                      isTimed: LevelLibrary.hasTimer(id),
                                      isCollect: LevelLibrary.isCollect(id),
                                      maxStars: LevelLibrary.maxStars(for: id),
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

/// Altıgen. Topla-bitir bölümlerinin silueti bu — oyundaki kapı da altıgen
/// bir ızgarayla çiziliyor, harita ile oynanış aynı dili konuşsun.
private struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        for i in 0..<6 {
            // -90°'den başla: düz kenar değil, sivri uç yukarı baksın
            let a = CGFloat(i) * .pi / 3 - .pi / 2
            let p = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }
}

private struct LevelNode: View {
    let id: Int
    let stars: Int
    let unlocked: Bool
    let isCurrent: Bool
    let isBonus: Bool
    let isBonusCompleted: Bool
    let isTimed: Bool
    let isCollect: Bool
    let maxStars: Int
    let theme: Theme
    let action: () -> Void

    @State private var pulse = false

    private var accent: Color { isBonus ? theme.lumen.color : theme.ring.color }

    /// Topla-bitir bölümü altıgen, gerisi daire
    private var nodeShape: AnyShape {
        isCollect ? AnyShape(Hexagon()) : AnyShape(Circle())
    }
    private var playable: Bool { unlocked && !isBonusCompleted }

    var body: some View {
        Button {
            if playable { action() }
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

                    // Siluet bölümün türünü söylüyor: topla-bitir altıgen,
                    // gerisi daire. Rozet küçük kalıyordu; şekil uzaktan
                    // okunuyor ve haritada bakışta ayrışıyor.
                    nodeShape
                        .fill(unlocked ? accent.opacity(isBonus ? 0.28 : 0.18) : Color.white.opacity(0.06))
                        .frame(width: 58, height: 58)
                        .opacity(isBonusCompleted ? 0.5 : 1)

                    nodeShape
                        .stroke(unlocked
                                ? (stars >= maxStars ? theme.lumen.color : accent.opacity(0.7))
                                : Color.white.opacity(0.12),
                                style: isBonus
                                ? StrokeStyle(lineWidth: 2, dash: [5, 4])
                                : StrokeStyle(lineWidth: 2))
                        .frame(width: 58, height: 58)
                        .opacity(isBonusCompleted ? 0.5 : 1)

                    // Süreli bölüm: dışta bir kronometre kadranı. Üç çeyrek
                    // çizilmiş halka "süre işliyor" demenin en kısa yolu.
                    if isTimed, unlocked, !isCollect {
                        Circle()
                            .trim(from: 0, to: 0.72)
                            .stroke(theme.hazard.opacity(0.85),
                                    style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 68, height: 68)
                    }

                    if isBonusCompleted {
                        VStack(spacing: 0) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white.opacity(0.5))
                            Text("\(id)")
                                .font(.system(.caption2, design: .rounded).bold())
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    } else if unlocked {
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

                    // Süreli bölüm rozeti
                    if isTimed, unlocked {
                        Image(systemName: "timer")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(theme.hazard.color)
                            .padding(4)
                            .background(Circle().fill(.black.opacity(0.55)))
                            .offset(x: 22, y: -22)
                    }

                }

                if unlocked {
                    HStack(spacing: 2) {
                        ForEach(0..<maxStars, id: \.self) { i in
                            Image(systemName: i < stars ? "star.fill" : "star")
                                .font(.system(size: 8))
                                .foregroundStyle(i < stars ? theme.lumen.color : .white.opacity(0.25))
                        }
                    }
                }
            }
        }
        .disabled(!playable)
    }
}
