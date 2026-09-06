import SwiftUI

/// Açılış ekranı — AXIUM DYNAMICS stüdyo imzası + Orbeon marka işareti.
///
/// İşaret oyunun kendisi: nötr bir halka, üstünde tek kırmızı yay, çemberin
/// üstünde dolanan beyaz küre. Animasyon da oyunun kendisi: halka çizilir,
/// küre yörüngeyi tamamlar, kırmızı yay yerine PATLAR — sonra halka küçülerek
/// sola süzülür ve ORBEON'un O'sunun yerine oturur. Yani açılış, markanın
/// nereden geldiğini gösteriyor: işaret ayrı bir amblem değil, kelimenin bir
/// harfi.
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
    @State private var composed = false      // halka O'nun yerine geçti
    @State private var lettersIn = false     // RBEON açıldı
    @State private var finished = false

    private let ringColor = Color(red: 0.503, green: 0.499, blue: 0.540)
    private let hazardColor = Color(red: 0.820, green: 0.286, blue: 0.357)

    /// Kırmızı yayın orta açısı — patlama parçacıkları oradan savrulur
    private let hazardMidAngle: Double = -78

    // MARK: Ölçüler
    //
    // Halka büyükken 118, kelimenin içindeyken 38 punto. Oran ikisi arasında
    // tek bir `scaleEffect` ile kuruluyor; harflerin puntosu ile halkanın çapı
    // ayrı ayrı ayarlanmıyor ki ikisi asla birbirinden kaymasın.
    private static let markFrame: CGFloat = 190
    private static let ringBig: CGFloat = 118
    private static let ringFinal: CGFloat = 38
    private static let letterSize: CGFloat = 42
    private static let letterKerning: CGFloat = 13
    private static let ringGap: CGFloat = 9
    /// Halka harflerin optik ortasına oturmuyordu: yazı kutusunun ortası
    /// alt uzantılar yüzünden harflerin göründüğü ortadan aşağıda kalıyor.
    private static let ringOpticalLift: CGFloat = 3

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

                // Kelime işareti kendi yerinde duruyor; içindeki halka boşluğu
                // ölçülüp yukarıdaki katmana bildiriliyor. Yükseklik marka
                // büyükken de aynı: halka küçülürken sayfa yerinden oynamıyor.
                lockup
                    .frame(height: Self.markFrame)
                    .overlay { tagline.offset(y: 47) }

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
        // Marka işareti TEK katman: büyük hâliyle ortada duran şeyle O'nun
        // yerine geçen şey aynı görünüm. İki ayrı görünüm arasında geçiş
        // yapılsaydı, birinin sönüp öbürünün belirdiği bir kare olurdu.
        .overlayPreferenceValue(RingSlotKey.self) { anchor in
            GeometryReader { proxy in
                markLayer(slot: anchor.map { proxy[$0] }, in: proxy.size)
            }
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { finish() }   // dokununca atla
        .task { await run() }
    }

    // MARK: Kelime işareti
    //
    // Halkanın yeri BOŞ bırakılıyor. Gerçek halka üstteki katmanda ve oraya
    // uçuyor; buradaki şeffaf kutu yalnızca O'nun nerede duracağını söylüyor.

    private var lockup: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: Self.ringFinal, height: Self.ringFinal)
                .anchorPreference(key: RingSlotKey.self, value: .bounds) { $0 }

            Text(verbatim: "RBEON")
                .font(.system(size: Self.letterSize, weight: .light))
                .kerning(Self.letterKerning)
                // kerning son harften SONRA da boşluk bırakıyor; kelime
                // işaretinin sola kaymaması için o boşluk geri alınıyor
                .padding(.trailing, -Self.letterKerning)
                .padding(.leading, Self.ringGap)
                .foregroundStyle(.white)
                .opacity(lettersIn ? 1 : 0)
                // Harfler halkanın ardından, soldan açılıyor
                .offset(x: lettersIn ? 0 : -14)
        }
    }

    private var tagline: some View {
        Text("the journey of light")
            .font(.system(size: 13, weight: .regular, design: .rounded))
            .kerning(4)
            .padding(.leading, 4)
            .foregroundStyle(.white.opacity(0.45))
            .opacity(lettersIn ? 1 : 0)
    }

    /// Halkanın kendisi. `slot` kelime işaretindeki O boşluğu — ölçü henüz
    /// alınmadıysa ekranın ortasında kalıyor.
    private func markLayer(slot: CGRect?, in size: CGSize) -> some View {
        let midY = slot?.midY ?? size.height / 2
        let home = CGPoint(x: size.width / 2, y: midY)
        let target = CGPoint(x: slot?.midX ?? home.x, y: midY - Self.ringOpticalLift)

        return mark
            .frame(width: Self.markFrame, height: Self.markFrame)
            .scaleEffect(composed ? Self.ringFinal / Self.ringBig : 1)
            .position(composed ? target : home)
    }

    // MARK: Marka işareti

    private var mark: some View {
        ZStack {
            // 1) Halka çizilir
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: Self.ringBig, height: Self.ringBig)

            // 2) Kırmızı yay yerine oturur: dışarıdan içeri çöker
            Circle()
                .trim(from: 0.06, to: 0.32)
                .stroke(hazardColor, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                .frame(width: Self.ringBig, height: Self.ringBig)
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

        // İşaret küçülerek sola süzülür ve O'nun yerine oturur. Küre son
        // çeyreği de dönüp sol alta yerleşiyor: kelimenin içindeki halka
        // duran bir amblem değil, hâlâ oyunun bir karesi.
        try? await Task.sleep(for: .seconds(0.5))
        withAnimation(.spring(response: 0.62, dampingFraction: 0.86)) {
            composed = true
            orbAngle = 315
        }

        // Harfler işaretin ardından açılıyor: önce yer değiştirme okunsun,
        // kelime sonra kurulsun
        try? await Task.sleep(for: .seconds(0.3))
        withAnimation(.easeOut(duration: 0.45)) { lettersIn = true }

        try? await Task.sleep(for: .seconds(1.15))
        finish()
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onFinished()
    }
}

/// Kelime işaretindeki O boşluğunun yeri. Marka katmanı buraya uçuyor.
private struct RingSlotKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}
