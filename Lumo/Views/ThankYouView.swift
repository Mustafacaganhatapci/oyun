import SwiftUI

/// Satın alma sonrası çıkan, adına seslenen teşekkür kartı.
///
/// Bir bahşiş bırakan kişi para karşılığı bir şey almıyor; verdiği şeyin
/// karşılığı ancak bu olabilir. Sıradan bir "işlem başarılı" bildirimi bu işi
/// görmüyordu.
struct ThankYouView: View {
    let isTip: Bool
    let username: String
    let theme: Theme
    let onClose: () -> Void

    @State private var appeared = false
    @State private var glow = false

    private var accent: Color { theme.lumen.color }

    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [accent.opacity(0.35), .clear],
                                             center: .center, startRadius: 4, endRadius: 90))
                        .frame(width: 180, height: 180)
                        .scaleEffect(glow ? 1.1 : 0.9)

                    Image(systemName: isTip ? "heart.fill" : "crown.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(
                            LinearGradient(colors: [.white, accent],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .scaleEffect(appeared ? 1 : 0.3)
                }
                .frame(height: 150)

                // Adı varsa ona seslen. Yoksa ad istemeyi seçmiş biri demektir,
                // zorlamak yerine adsız hâli kullanılır.
                Group {
                    if username.isEmpty {
                        Text("Thank you!")
                    } else {
                        Text("Thank you, \(username)!")
                    }
                }
                .font(.system(.title, design: .rounded).bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

                Text(isTip
                     ? "I make Orbeon on my own, and someone choosing to chip in is what makes the next update worth writing. Premium is yours as well — consider it the least I can do. It follows your iCloud account, so it's there on your other devices too."
                     : "The ads are off from today. I make Orbeon on my own, and this goes straight into the next levels, characters and music.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)

                if isTip {
                    Label("Premium unlocked", systemImage: "checkmark.seal.fill")
                        .font(.system(.subheadline, design: .rounded).bold())
                        .foregroundStyle(theme.gate.color)
                }

                Button(action: onClose) {
                    Text("Back to the game")
                }
                .buttonStyle(GlowButtonStyle(color: theme.accent.color, prominent: true))
                .padding(.top, 4)
            }
            .padding(26)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(theme.bgBottom.color.opacity(0.96))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(accent.opacity(0.25), lineWidth: 1)
                    }
            }
            .padding(.horizontal, 26)
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { appeared = true }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { glow = true }
        }
    }
}
