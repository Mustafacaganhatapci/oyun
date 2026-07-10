import SwiftUI

/// Açılış ekranı — AXIUM DYNAMICS stüdyo imzası.
/// Oyunun kimliğiyle uyumlu: bir halka çizilir, küre yörüngeyi tamamlar,
/// ardından stüdyo adı belirir. Dokununca atlanabilir.
struct SplashView: View {
    let onFinished: () -> Void

    @State private var ringProgress: CGFloat = 0
    @State private var orbAngle: Double = 0
    @State private var orbVisible = false
    @State private var showName = false
    @State private var glow = false
    @State private var finished = false

    private let accent = Color(red: 0.35, green: 0.85, blue: 1.0)   // buz mavisi

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 34) {
                // Logo: çizilen halka + yörüngeyi dolaşan küre + merkezde A
                ZStack {
                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(
                            AngularGradient(colors: [accent.opacity(0.15), accent],
                                            center: .center,
                                            startAngle: .degrees(-90),
                                            endAngle: .degrees(270)),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 104, height: 104)
                        .shadow(color: accent.opacity(glow ? 0.6 : 0.15), radius: glow ? 18 : 6)

                    Text(verbatim: "A")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .opacity(showName ? 1 : 0)
                        .scaleEffect(showName ? 1 : 0.6)

                    if orbVisible {
                        Circle()
                            .fill(.white)
                            .frame(width: 11, height: 11)
                            .shadow(color: accent, radius: glow ? 12 : 6)
                            .offset(y: -52)
                            .rotationEffect(.degrees(orbAngle))
                    }
                }

                VStack(spacing: 8) {
                    Text(verbatim: "AXIUM")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .kerning(12)
                        .padding(.leading, 12)   // kerning son harf sonrası boşluğu dengeler
                        .foregroundStyle(.white)
                    Text(verbatim: "DYNAMICS")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .kerning(8)
                        .padding(.leading, 8)
                        .foregroundStyle(accent.opacity(0.9))
                }
                .opacity(showName ? 1 : 0)
                .offset(y: showName ? 0 : 12)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { finish() }   // dokununca atla
        .task {
            // 1) Halka çizilir, küre yörüngeyi dolaşır
            orbVisible = true
            withAnimation(.easeInOut(duration: 1.0)) {
                ringProgress = 1
                orbAngle = 360
            }
            try? await Task.sleep(for: .seconds(0.75))

            // 2) İsim belirir, parlar
            withAnimation(.spring(duration: 0.6)) { showName = true }
            withAnimation(.easeInOut(duration: 0.8)) { glow = true }

            // 3) Kısa bekleyip menüye geç
            try? await Task.sleep(for: .seconds(1.6))
            finish()
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onFinished()
    }
}
