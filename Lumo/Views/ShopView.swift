import SwiftUI
import StoreKit

struct ShopView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var progress: ProgressStore

    @State private var codeInput = ""
    @State private var codeState: CodeState = .idle
    @FocusState private var codeFocused: Bool

    private enum CodeState { case idle, success, failure }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BackButton { app.route = .menu }
                Spacer()
                Text("Shop")
                    .font(.system(.title2, design: .rounded).bold())
                    .foregroundStyle(.white)
                Spacer()
                // Yıldız bakiyesi
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.footnote)
                        .foregroundStyle(settings.theme.lumen.color)
                    Text("\(progress.availableStars)")
                        .font(.system(.subheadline, design: .rounded).bold())
                        .foregroundStyle(.white)
                }
                .frame(minWidth: 44)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            ScrollView {
                VStack(spacing: 20) {
                    charactersSection

                    premiumCard

                    if !store.isPremium {
                        redeemSection
                    }

                    // Dürüstlük ilkesi — açıkça söylüyoruz
                    Label("No purchase gives a gameplay advantage. There is no pay-to-win in LUMO.",
                          systemImage: "checkmark.shield.fill")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)

                    tipSection

                    Button {
                        Task { await store.restore() }
                    } label: {
                        Text("Restore Purchases")
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

    // MARK: Tanıdık kodu (premium'u ücretsiz açar)

    private var redeemSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Have a code?", systemImage: "ticket.fill")
                .font(.system(.subheadline, design: .rounded).bold())
                .foregroundStyle(.white.opacity(0.85))

            HStack(spacing: 10) {
                TextField("", text: $codeInput, prompt: Text("Enter code").foregroundStyle(.white.opacity(0.35)))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($codeFocused)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.white.opacity(0.08))
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                    }
                    .onChange(of: codeInput) { _, _ in codeState = .idle }

                Button {
                    codeFocused = false
                    if store.redeem(code: codeInput) {
                        codeState = .success
                        AudioEngine.shared.playWin()
                        Haptics.shared.win()
                    } else {
                        codeState = .failure
                        AudioEngine.shared.playFail()
                    }
                } label: {
                    Text("Redeem")
                        .font(.system(.subheadline, design: .rounded).bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Capsule().fill(settings.theme.accent.color))
                }
                .disabled(codeInput.isEmpty)
                .opacity(codeInput.isEmpty ? 0.5 : 1)
            }

            switch codeState {
            case .success:
                Label("Code accepted — Premium unlocked!", systemImage: "checkmark.circle.fill")
                    .font(.system(.caption, design: .rounded).bold())
                    .foregroundStyle(settings.theme.gate.color)
            case .failure:
                Label("Invalid code", systemImage: "xmark.circle.fill")
                    .font(.system(.caption, design: .rounded).bold())
                    .foregroundStyle(settings.theme.hazard.color)
            case .idle:
                EmptyView()
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.05))
        }
        .padding(.horizontal, 20)
    }

    // MARK: Yıldızla alınan karakterler (küre stilleri)

    private var charactersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Characters")
                    .font(.system(.headline, design: .rounded).bold())
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text("Unlock with stars ★")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }

            ForEach(OrbStyle.starPurchasable) { style in
                characterRow(style)
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.05))
        }
        .padding(.horizontal, 20)
    }

    private func characterRow(_ style: OrbStyle) -> some View {
        // Premium sahibi tüm karakterlere sahiptir; yoksa yıldızla açılmış olmalı
        let owned = store.isPremium || progress.isOrbUnlocked(style)
        let equipped = settings.orbStyleID == style.id
        let cost = style.starCost ?? 0
        return HStack(spacing: 14) {
            CharacterPreview(kind: style.kind, theme: settings.theme)
                .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 2) {
                Text(style.localizedName)
                    .font(.system(.body, design: .rounded).bold())
                    .foregroundStyle(.white)
                if !owned {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill").font(.system(size: 10))
                        Text("\(cost)").font(.system(.subheadline, design: .rounded).bold())
                    }
                    .foregroundStyle(settings.theme.lumen.color)
                }
            }

            Spacer()

            if equipped {
                Label("Equipped", systemImage: "checkmark.circle.fill")
                    .font(.system(.subheadline, design: .rounded).bold())
                    .foregroundStyle(settings.theme.gate.color)
            } else if owned {
                Button {
                    AudioEngine.shared.playTap()
                    settings.orbStyleID = style.id
                } label: {
                    Text("Equip")
                        .font(.system(.subheadline, design: .rounded).bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Capsule().fill(settings.theme.accent.color))
                }
            } else {
                Button {
                    if progress.purchaseOrb(style) {
                        AudioEngine.shared.playWin()
                        settings.orbStyleID = style.id   // alınca hemen kuşan
                    } else {
                        AudioEngine.shared.playFail()
                    }
                } label: {
                    Text("Buy")
                        .font(.system(.subheadline, design: .rounded).bold())
                        .foregroundStyle(progress.canAfford(style) ? .black : .white.opacity(0.4))
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Capsule().fill(progress.canAfford(style)
                                                   ? settings.theme.lumen.color
                                                   : Color.white.opacity(0.1)))
                }
                .disabled(!progress.canAfford(style))
            }
        }
        .padding(.vertical, 4)
    }

    private var premiumCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "crown.fill")
                .font(.system(size: 40))
                .foregroundStyle(settings.theme.lumen.color)
                .shadow(color: settings.theme.lumen.opacity(0.8), radius: 14)

            Text("Orbeon Premium")
                .font(.system(.title, design: .rounded).bold())
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 10) {
                benefit("rectangle.slash", "All ads removed forever")
                benefit("paintpalette.fill", "4 exclusive themes: Dawn, Forest, Coral, Aurora")
                benefit("circle.hexagongrid.circle", "4 exclusive orb styles — even your own photo in the orb")
                benefit("heart.fill", "Direct support for an independent developer")
            }
            .padding(.vertical, 6)

            if store.isPremium {
                Label("Thank you! Premium is active", systemImage: "checkmark.circle.fill")
                    .font(.system(.headline, design: .rounded).bold())
                    .foregroundStyle(settings.theme.gate.color)
                    .padding(.vertical, 10)
            } else if let product = store.premiumProduct {
                Button {
                    Task { await store.purchase(product) }
                } label: {
                    HStack {
                        Text("Go Premium")
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

    private func benefit(_ icon: String, _ text: LocalizedStringKey) -> some View {
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
            Text("Tip Jar")
                .font(.system(.headline, design: .rounded).bold())
                .foregroundStyle(.white.opacity(0.9))
            Text("If you love the game, you can buy the developer a coffee ☕️")
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
                Label("Thank you for your support!", systemImage: "heart.fill")
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

/// Mağaza/ayarlarda küre stilinin küçük önizlemesi
struct CharacterPreview: View {
    let kind: OrbStyle.Kind
    let theme: Theme

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [theme.bgTop.color, theme.bgBottom.color],
                                     startPoint: .top, endPoint: .bottom))
            content
        }
        .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1))
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .classic:
            Circle().fill(theme.orb.color).frame(width: 16, height: 16)
                .shadow(color: theme.accent.color, radius: 6)
        case .star:
            Image(systemName: "star.fill").font(.system(size: 18))
                .foregroundStyle(theme.lumen.color).shadow(color: theme.lumen.color, radius: 6)
        case .crystal:
            Image(systemName: "hexagon.fill").font(.system(size: 18))
                .foregroundStyle(theme.gate.color).shadow(color: theme.gate.color, radius: 6)
        case .comet:
            HStack(spacing: 0) {
                Capsule().fill(LinearGradient(colors: [.clear, theme.accent.color],
                                              startPoint: .leading, endPoint: .trailing))
                    .frame(width: 18, height: 4)
                Circle().fill(.white).frame(width: 11, height: 11)
            }
            .shadow(color: theme.accent.color, radius: 6)
        case .rainbow:
            Circle()
                .fill(AngularGradient(colors: [.red, .yellow, .green, .cyan, .purple, .red], center: .center))
                .frame(width: 16, height: 16)
        case .ring:
            Circle().strokeBorder(theme.orb.color, lineWidth: 3).frame(width: 18, height: 18)
        case .diamond:
            Image(systemName: "suit.diamond.fill").font(.system(size: 18)).foregroundStyle(theme.accent.color)
        case .flame:
            Image(systemName: "flame.fill").font(.system(size: 18)).foregroundStyle(theme.hazard.color)
        case .pixel:
            RoundedRectangle(cornerRadius: 2).fill(theme.gate.color).frame(width: 15, height: 15)
        case .photo:
            if let image = OrbPhotoStore.load() {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: 22, height: 22).clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle").font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }
}
