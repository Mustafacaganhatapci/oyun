import SwiftUI

/// 10. bölüm bitince bir kez çıkan duyuru: sonsuz mod ve hız turu açıldı.
///
/// İki mod menüde baştan görünüyor ama soluk duruyordu; ne zaman açıldıklarını
/// ve neye yaradıklarını hiçbir yer söylemiyordu. Haftalık tabloya davet de
/// burada — sıralamaya girmek oyunun en uzun soluklu tarafı.
struct ModesUnlockedView: View {
    let theme: Theme
    let onClose: () -> Void
    let onPlay: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(spacing: 18) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(colors: [.white, theme.lumen.color],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: theme.lumen.opacity(0.8), radius: 16)
                    .scaleEffect(appeared ? 1 : 0.4)

                Text("Two new modes")
                    .font(.system(.title, design: .rounded).bold())
                    .foregroundStyle(.white)

                VStack(spacing: 12) {
                    modeRow("infinity", "Endless Mode",
                            "Climb as high as you can. The rings get smaller and faster.",
                            theme.gate.color)
                    modeRow("stopwatch.fill", "Speed Run",
                            "Five levels, one clock. Fastest time wins.",
                            theme.hazard.color)
                }

                Text("Both go on the weekly board, and it resets every Monday. See if you can take a place in the top three.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)

                Button(action: onPlay) {
                    Label("Try Endless Mode", systemImage: "infinity")
                }
                .buttonStyle(GlowButtonStyle(color: theme.gate.color, prominent: true))
                .padding(.top, 2)

                Button(action: onClose) {
                    Text("Later")
                        .font(.system(.footnote, design: .rounded).bold())
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(26)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(theme.bgBottom.color.opacity(0.96))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(theme.lumen.opacity(0.25), lineWidth: 1)
                    }
            }
            .padding(.horizontal, 26)
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { appeared = true }
        }
    }

    private func modeRow(_ icon: String, _ title: LocalizedStringKey,
                         _ body: LocalizedStringKey, _ color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.16))
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(color)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).bold())
                    .foregroundStyle(.white)
                Text(body)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
