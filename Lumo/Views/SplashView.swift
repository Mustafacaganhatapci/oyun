import SwiftUI

/// Açılış ekranı — AXIUM DYNAMICS stüdyo imzası + Orbeon marka işareti.
///
/// İşaret oyunun kendisi: nötr bir halka, üstünde tek kırmızı yay, çemberin
/// üstünde dolanan beyaz küre. Animasyon da oyunun kendisi: halka çizilir,
/// küre yörüngeyi tamamlar, sonra kırmızı yay yerine PATLAR. Stüdyo adı
/// yukarıda, üst şerit gibi durur — sahne markanın.
///
/// Dokununca atlanabilir.
struct SplashView: View {
    let onFinished: () -> Void

    @State private var ringProgress: CGFloat = 0
    @State private var orbAngle: Double = -90
    @State private var orbVisible = false
    @State private var showName = false
    @State private var hazardIn = false      // kırmızı yay yerine oturdu
    @State private var burst: CGFloat = 0    // 0...1 patlama ilerlemesi
    @State private var finished = false

    private let ringColor = Color(red: 0.503, green: 0.499, blue: 0.540)
    private let hazardColor = Color(red: 0.820, green: 0.286, blue: 0.357)

    /// Kırmızı yayın orta açısı — patlama parçacıkları oradan savrulur
    private let hazardMidAngle: Double = -78

    /// İçinde bulunulan yıl — telif satırı her yıl elle güncellenmesin
    private static var copyrightYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    var body: some View {
        ZStack {
            Color(red: 0.048, green: 0.047, blue: 0.061).ignoresSafeArea()

            VStack(spacing: 0) {
                // Stüdyo imzası en üstte
                VStack(spacing: 7) {
                    Text(verbatim: "AXIUM")
                        .font(.system(size: 26, weight: .light))
                        .kerning(13)
                        .padding(.leading, 13)   // kerning son harf sonrası boşluğu dengeler
                        .foregroundStyle(.white.opacity(0.92))
                    Text(verbatim: "DYNAMICS")
                        .font(.system(size: 12, weight: .regular))
                        .kerning(7)
                        .padding(.leading, 7)
                        .foregroundStyle(.white.opacity(0.42))
                }
                .padding(.top, 78)
                .opacity(showName ? 1 : 0)
                .offset(y: showName ? 0 : -10)

                Spacer()

                mark
                    .frame(width: 190, height: 190)

                Spacer()
                Spacer()
            }

            // Telif satırı en altta, stüdyo imzasıyla birlikte belirir
            VStack {
                Spacer()
                VStack(spacing: 3) {
                    Text(verbatim: "© \(Self.copyrightYear) Axium Dynamics")
                    Text("All rights reserved")
                }
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.white.opacity(0.28))
                .opacity(showName ? 1 : 0)
                .padding(.bottom, 26)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { finish() }   // dokununca atla
        .task { await run() }
    }

    // MARK: Marka işareti

    private var mark: some View {
        ZStack {
            // 1) Halka çizilir
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 118, height: 118)

            // 2) Kırmızı yay yerine oturur: dışarıdan içeri çöker
            Circle()
                .trim(from: 0.06, to: 0.32)
                .stroke(hazardColor, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                .frame(width: 118, height: 118)
                .rotationEffect(.degrees(-125))
                .scaleEffect(hazardIn ? 1 : 1.45)
                .opacity(hazardIn ? 1 : 0)

            // 3) Patlama: yayın ortasından savrulan parçacıklar
            ForEach(0..<12, id: \.self) { i in
                let spread = Double(i - 6) * 7.0        // yay boyunca yelpaze
                let angle = Angle.degrees(hazardMidAngle + spread)
                Circle()
                    .fill(hazardColor)
                    .frame(width: 4.5, height: 4.5)
                    .offset(x: cos(angle.radians) * (59 + burst * 46),
                            y: sin(angle.radians) * (59 + burst * 46))
                    .opacity(burst == 0 ? 0 : 1 - burst)
                    .scaleEffect(1 - burst * 0.55)
            }

            // 4) Küre yörüngede dolanır
            if orbVisible {
                Circle()
                    .fill(.white)
                    .frame(width: 19, height: 19)
                    .offset(y: 59)
                    .rotationEffect(.degrees(orbAngle))
            }
        }
    }

    // MARK: Zamanlama

    private func run() async {
        orbVisible = true
        // Halka çizilirken küre onu tam bir tur dolaşır
        withAnimation(.easeInOut(duration: 1.05)) {
            ringProgress = 1
            orbAngle = 270
        }
        try? await Task.sleep(for: .seconds(0.95))

        // Kırmızı yay çöker ve aynı anda patlar
        withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) { hazardIn = true }
        withAnimation(.easeOut(duration: 0.55)) { burst = 1 }
        Haptics.shared.hop()

        try? await Task.sleep(for: .seconds(0.22))
        withAnimation(.easeOut(duration: 0.55)) { showName = true }

        try? await Task.sleep(for: .seconds(1.5))
        finish()
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onFinished()
    }
}
