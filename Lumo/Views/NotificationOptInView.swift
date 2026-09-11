import SwiftUI

/// İlk açılışta bildirimleri soran kart.
///
/// Bu kart iOS'un izin kutusu DEĞİL; onun önüne konan kendi sorumuz. Sebep
/// tek bir kurala dayanıyor: iOS izin kutusuna bir kez "İzin Verme" denirse
/// uygulama bir daha ASLA soramaz — tek yol kullanıcının kendi kendine iOS
/// Ayarları'na gitmesi ve kimse gitmiyor. Yani o kutu bir kerelik ve geri
/// dönüşsüz.
///
/// Bu kart ise geri dönüşlü. "Şimdi değil" diyen oyuncuya hiçbir şey
/// kaybettirmiyoruz: iOS izni hâlâ sorulmamış durumda kalıyor, ayarlardaki
/// anahtar duruyor, ilerideki bir sürümde yeniden sorulabiliyor. Yalnızca
/// "Aç" denince gerçek kutu çıkıyor — yani izin kutusunu görenler zaten
/// istediğini söylemiş kişiler oluyor ve kabul oranı buna bağlı olarak
/// yükseliyor.
///
/// Metin ne söylediğimizi tek tek sayıyor. "Bildirim gönderebilir miyiz?"
/// diye soran bir kutunun cevabı hayırdır; ne göndereceğini söyleyenin
/// cevabı belki olur.
struct NotificationOptInView: View {
    @EnvironmentObject private var settings: SettingsStore

    let onEnable: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 14) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(settings.theme.accent.color)

                Text("Want a heads-up?")
                    .font(.system(.title2, design: .rounded).bold())
                    .foregroundStyle(.white)

                Text("New levels, new characters, and a nudge before the weekly race closes. Nothing else.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)

                // Kapatma yolunun açıkça yazılması kabul oranını düşürmüyor,
                // yükseltiyor: geri alınabilir bir karar vermek kolaydır.
                Text("You can turn it off any time in Settings.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)

                Button(action: onEnable) {
                    Label("Turn on notifications", systemImage: "bell.fill")
                }
                .buttonStyle(GlowButtonStyle(color: settings.theme.accent.color, prominent: true))
                .padding(.top, 4)

                Button(action: onDismiss) {
                    Text("Not now")
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

/// Kartın ne zaman çıkacağını tutar.
///
/// Bir kez soruluyor. "Şimdi değil" diyene aynı kartı her açılışta göstermek,
/// bildirimleri açtırmaz — oyunu sildirir.
enum NotificationOptIn {
    private static let askedKey = "lumo.push.optInAsked"

    static var wasAsked: Bool {
        UserDefaults.standard.bool(forKey: askedKey)
    }

    /// `isUndecided`: iOS izni HENÜZ sorulmamış. Daha önce kabul ya da ret
    /// edilmişse kart çıkmıyor — kararını vermiş birine aynı soruyu sormak
    /// yalnızca rahatsız eder.
    static func shouldShow(isEnabled: Bool, isUndecided: Bool) -> Bool {
        !wasAsked && !isEnabled && isUndecided
    }

    static func markAsked() {
        UserDefaults.standard.set(true, forKey: askedKey)
    }
}
