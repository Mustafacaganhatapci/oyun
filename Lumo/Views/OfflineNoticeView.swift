import SwiftUI

/// İnterneti kapalı oynayan oyuncuya bir kez gösterilen nazik not.
///
/// Bağlantı yokken reklam sunulamaz; bazı oyuncular bunu bilerek yapıyor.
/// Bunu engellemeye çalışmıyoruz — oyun çevrimdışı tam sürümüyle çalışır.
/// Yalnızca premium'un ne kadar olduğunu ve ne getirdiğini bir kez söyleyip
/// oyuncuyu rahat bırakıyoruz. Kırıcı bir dil ya da tekrar tekrar çıkan bir
/// uyarı, kazandıracağından çok kaybettirir.
struct OfflineNoticeView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var store: StoreManager

    let onPremium: () -> Void
    let onClose: () -> Void

    private var accent: Color { settings.theme.lumen.color }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(spacing: 14) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.75))

                Text("Playing offline?")
                    .font(.system(.title2, design: .rounded).bold())
                    .foregroundStyle(.white)

                Text("No problem — Orbeon works fully offline. The campaign, endless mode and your stars all keep going; only the weekly board needs a connection. And with no connection there are no ads, so feel free to keep playing exactly like this.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)

                // Fiyat mağazadan gelir (çevrimdışıysa son bilinen fiyattan).
                // Hiç bilinmiyorsa fiyatsız cümleye düşeriz — koda sabit bir
                // rakam yazmayız, kampanya ya da bölge değişince yanlış olur.
                if let price = store.premiumPriceText {
                    Text("If you ever want it, Premium is \(price): no ads online either, an extra life every endless run, 8 exclusive themes, your own recorded sounds and your photo in the orb.")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                } else {
                    Text("If you ever want it, Premium removes the ads online too, and adds an extra life every endless run, 8 exclusive themes, your own recorded sounds and your photo in the orb.")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }

                Text("Have fun!")
                    .font(.system(.subheadline, design: .rounded).bold())
                    .foregroundStyle(accent)
                    .padding(.top, 2)

                Button(action: onClose) {
                    Label("Keep playing", systemImage: "play.fill")
                }
                .buttonStyle(GlowButtonStyle(color: settings.theme.accent.color, prominent: true))
                .padding(.top, 4)

                Button(action: onPremium) {
                    Text("See Premium")
                        .font(.system(.footnote, design: .rounded).bold())
                        .foregroundStyle(.white.opacity(0.55))
                        .underline()
                }
            }
            .padding(24)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(settings.theme.bgBottom.color.opacity(0.96))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                    }
            }
            .padding(.horizontal, 28)
        }
    }
}

/// Notun ne zaman gösterileceğini tutar: çevrimdışı, premium değil ve son
/// gösterimden bu yana en az bir hafta geçmişse. Oyuncuyu her açılışta
/// karşılamaz.
enum OfflineNotice {
    private static let key = "lumo.offlineNoticeAt"
    private static let interval: TimeInterval = 7 * 24 * 3600

    static func shouldShow(isOnline: Bool, isPremium: Bool, totalStars: Int) -> Bool {
        guard !isOnline, !isPremium else { return false }
        // Yeni başlayan oyuncuyu ilk dakikasında satın almayla karşılamayalım
        guard totalStars >= 3 else { return false }
        let last = UserDefaults.standard.double(forKey: key)
        return Date().timeIntervalSince1970 - last > interval
    }

    static func markShown() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: key)
    }
}
