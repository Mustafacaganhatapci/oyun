import SwiftUI

// MARK: - Parlayan büyük menü düğmesi

struct GlowButtonStyle: ButtonStyle {
    var color: Color
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.title3, design: .rounded).weight(.bold))
            .foregroundStyle(prominent ? Color.black.opacity(0.85) : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(prominent ? AnyShapeStyle(color) : AnyShapeStyle(color.opacity(0.16)))
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(color.opacity(prominent ? 0 : 0.55), lineWidth: 1.5)
            }
            .shadow(color: color.opacity(prominent ? 0.55 : 0.25), radius: prominent ? 18 : 10, y: 4)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Yıldız satırı (bölüm sonucu / bölüm seçimi)

struct StarsView: View {
    let count: Int
    var size: CGFloat = 28
    var color: Color = Color(red: 1.0, green: 0.83, blue: 0.35)

    var body: some View {
        HStack(spacing: size * 0.25) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < count ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(i < count ? color : Color.white.opacity(0.25))
                    .shadow(color: i < count ? color.opacity(0.7) : .clear, radius: 8)
            }
        }
    }
}

// MARK: - Canlı menü arka planı: süzülen ışık küreleri

struct AnimatedBackground: View {
    let theme: Theme

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                for i in 0..<7 {
                    let fi = Double(i)
                    let x = size.width * (0.5 + 0.42 * sin(t * 0.11 + fi * 2.1))
                    let y = size.height * (0.5 + 0.44 * cos(t * 0.09 + fi * 1.7))
                    let r = 30.0 + 26.0 * sin(t * 0.2 + fi)
                    let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                    let color = i % 2 == 0 ? theme.ring.color : theme.accent.color
                    context.fill(Circle().path(in: rect),
                                 with: .radialGradient(Gradient(colors: [color.opacity(0.16), .clear]),
                                                       center: CGPoint(x: x, y: y),
                                                       startRadius: 0, endRadius: r))
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Tema arka plan degradesi

struct ThemeGradient: View {
    let theme: Theme
    var body: some View {
        LinearGradient(colors: [theme.bgTop.color, theme.bgBottom.color],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

// MARK: - Geri düğmesi

struct BackButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.white.opacity(0.12)))
        }
    }
}

// MARK: - Yer tutucu reklam (yalnızca DEBUG — gerçek SDK eklenince görünmez)

struct AdPlaceholderView: View {
    let onClose: () -> Void
    @State private var secondsLeft = 3

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "megaphone.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(.white.opacity(0.7))
                Text("Reklam")
                    .font(.system(.largeTitle, design: .rounded).bold())
                    .foregroundStyle(.white)
                Text("Gerçek sürümde burada geçiş reklamı gösterilir.\nPremium ile tüm reklamlar kalkar.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                if secondsLeft > 0 {
                    Text("\(secondsLeft)")
                        .font(.system(.title, design: .rounded).bold())
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.bottom, 40)
                } else {
                    Button(action: onClose) {
                        Label("Kapat", systemImage: "xmark")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(.white))
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .task {
            for _ in 0..<3 {
                try? await Task.sleep(for: .seconds(1))
                secondsLeft -= 1
            }
        }
    }
}
