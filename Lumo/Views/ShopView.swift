import SwiftUI
import StoreKit

struct ShopView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var store: StoreManager

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BackButton { app.route = .menu }
                Spacer()
                Text("Mağaza")
                    .font(.system(.title2, design: .rounded).bold())
                    .foregroundStyle(.white)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            ScrollView {
                VStack(spacing: 20) {
                    premiumCard

                    // Dürüstlük ilkesi — açıkça söylüyoruz
                    Label("Hiçbir satın alma oyun avantajı vermez. LUMO'da pay-to-win yoktur.",
                          systemImage: "checkmark.shield.fill")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)

                    tipSection

                    Button {
                        Task { await store.restore() }
                    } label: {
                        Text("Satın Alımları Geri Yükle")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                            .underline()
                    }
                    .padding(.bottom, 40)
                }
                .padding(.top, 20)
            }
        }
    }

    private var premiumCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "crown.fill")
                .font(.system(size: 40))
                .foregroundStyle(settings.theme.lumen.color)
                .shadow(color: settings.theme.lumen.opacity(0.8), radius: 14)

            Text("LUMO Premium")
                .font(.system(.title, design: .rounded).bold())
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 10) {
                benefit("rectangle.slash", "Tüm reklamlar sonsuza dek kalkar")
                benefit("paintpalette.fill", "4 özel tema: Şafak, Orman, Mercan, Aurora")
                benefit("heart.fill", "Bağımsız geliştiriciye doğrudan destek")
            }
            .padding(.vertical, 6)

            if store.isPremium {
                Label("Teşekkürler! Premium aktif", systemImage: "checkmark.circle.fill")
                    .font(.system(.headline, design: .rounded).bold())
                    .foregroundStyle(settings.theme.gate.color)
                    .padding(.vertical, 10)
            } else if let product = store.premiumProduct {
                Button {
                    Task { await store.purchase(product) }
                } label: {
                    HStack {
                        Text("Premium'a Geç")
                        Spacer()
                        Text(product.displayPrice).bold()
                    }
                    .padding(.horizontal, 8)
                }
                .buttonStyle(GlowButtonStyle(color: settings.theme.lumen.color, prominent: true))
                .disabled(store.purchaseInProgress)
            } else {
                ProgressView()
                    .tint(.white)
                    .padding(.vertical, 10)
            }
        }
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(settings.theme.lumen.opacity(0.10))
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(settings.theme.lumen.opacity(0.5), lineWidth: 1.5)
        }
        .padding(.horizontal, 20)
    }

    private func benefit(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(settings.theme.accent.color)
                .frame(width: 24)
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            Spacer(minLength: 0)
        }
    }

    private var tipSection: some View {
        VStack(spacing: 12) {
            Text("Bahşiş Kavanozu")
                .font(.system(.headline, design: .rounded).bold())
                .foregroundStyle(.white.opacity(0.9))
            Text("Oyunu sevdiysen bir kahve ısmarlayabilirsin ☕️")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))

            HStack(spacing: 12) {
                ForEach(store.tipProducts, id: \.id) { product in
                    Button {
                        Task { await store.purchase(product) }
                    } label: {
                        VStack(spacing: 4) {
                            Text(product.id == StoreManager.tipSmallID ? "☕️" : "🌟")
                                .font(.title2)
                            Text(product.displayPrice)
                                .font(.system(.subheadline, design: .rounded).bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.white.opacity(0.08))
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                        }
                        .foregroundStyle(.white)
                    }
                    .disabled(store.purchaseInProgress)
                }
            }

            if store.isSupporter {
                Label("Desteğin için teşekkürler!", systemImage: "heart.fill")
                    .font(.system(.footnote, design: .rounded).bold())
                    .foregroundStyle(Color(red: 1, green: 0.4, blue: 0.5))
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.05))
        }
        .padding(.horizontal, 20)
    }
}
