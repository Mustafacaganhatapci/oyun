import SwiftUI

/// Yıldız eşiği geçilince açılan yeni karakterin kutlama ekranı.
///
/// Küreler artık satın alınmıyor: yıldız biriktirmek tek başına ilerleme ve
/// her eşik bir ödül. Ödülün hissedilmesi için açılışın GÖRÜLMESİ gerekiyor —
/// mağazaya girip fark etmesini beklemek, ödülü ödül olmaktan çıkarıyordu.
struct OrbRevealView: View {
    let style: OrbStyle
    let theme: Theme
    let onEquip: () -> Void
    let onClose: () -> Void

    @State private var appeared = false
    @State private var haloSpin = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()

            VStack(spacing: 20) {
                Text("New character unlocked")
                    .font(.system(.subheadline, design: .rounded).bold())
                    .foregroundStyle(theme.lumen.color)
                    .kerning(1.5)
                    .textCase(.uppercase)

                ZStack {
                    // Arkadan açılan ışık havuzu
                    Circle()
                        .fill(RadialGradient(colors: [theme.lumen.opacity(0.30), .clear],
                                             center: .center, startRadius: 4, endRadius: 96))
                        .frame(width: 200, height: 200)
                        .scaleEffect(appeared ? 1.0 : 0.4)

                    // Yavaşça dönen kesikli çember — kürenin "sunulduğu" his
                    Circle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [7, 11]))
                        .foregroundStyle(theme.lumen.opacity(0.5))
                        .frame(width: 148, height: 148)
                        .rotationEffect(.degrees(haloSpin ? 360 : 0))

                    CharacterPreview(kind: style.kind, theme: theme)
                        .frame(width: 108, height: 108)
                        .scaleEffect(appeared ? 1.0 : 0.2)
                        .opacity(appeared ? 1 : 0)
                }
                .frame(height: 200)

                Text(style.localizedName)
                    .font(.system(.title, design: .rounded).bold())
                    .foregroundStyle(.white)
                    .opacity(appeared ? 1 : 0)

                if let cost = style.starCost {
                    HStack(spacing: 5) {
                        Image(systemName: "star.fill").font(.system(size: 12))
                        Text("\(cost)")
                            .font(.system(.subheadline, design: .rounded).bold())
                    }
                    .foregroundStyle(.white.opacity(0.5))
                } else if style.unlock == .secret {
                    // Yeteneği olan tek küre. Bulan kişi ne bulduğunu burada
                    // öğreniyor; başka hiçbir yerde anlatılmıyor.
                    Text("Hold to slow time. The line shows where you land.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                VStack(spacing: 10) {
                    Button {
                        AudioEngine.shared.playTap()
                        onEquip()
                    } label: {
                        Label("Equip", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(GlowButtonStyle(color: theme.lumen.color, prominent: true))

                    Button {
                        AudioEngine.shared.playTap()
                        onClose()
                    } label: {
                        Text("Later")
                            .font(.system(.subheadline, design: .rounded).bold())
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                .padding(.top, 4)
            }
            .padding(28)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.black.opacity(0.55))
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(theme.lumen.opacity(0.35), lineWidth: 1.5)
            }
            .padding(.horizontal, 34)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) { appeared = true }
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) { haloSpin = true }
            AudioEngine.shared.playWin()
            Haptics.shared.win()
        }
    }
}
