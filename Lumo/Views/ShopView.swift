import SwiftUI
import StoreKit

struct ShopView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var ads: AdsManager

    @State private var codeInput = ""
    @State private var codeState: CodeState = .idle
    @FocusState private var codeFocused: Bool
    @State private var shimmer = false
    @State private var crownPulse = false
    @State private var starsJustEarned = false

    private enum CodeState { case idle, success, failure, bonusGranted }

    /// Premium kartının kaydırma çıpası
    private let premiumAnchor = "premium"

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

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        if !store.isPremium {
                            freeStarsCard
                        }

                        charactersSection

                        premiumCard
                            .id(premiumAnchor)

                        if !store.isPremium {
                            redeemSection
                        }

                        // Dürüstlük ilkesi — açıkça söylüyoruz
                        Label("No purchase gives a gameplay advantage. There is no pay-to-win in Orbeon.",
                              systemImage: "checkmark.shield.fill")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)

                        tipSection

                        if let status = store.statusMessage {
                            statusBanner(status)
                        }

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
                .onAppear {
                    // Premium zaten alınmışsa yukarıda kalsın; değilse teklifi
                    // görsün diye kart yumuşakça ekrana kaydırılır.
                    guard !store.isPremium else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        withAnimation(.easeInOut(duration: 0.7)) {
                            proxy.scrollTo(premiumAnchor, anchor: .center)
                        }
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                shimmer = true
            }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                crownPulse = true
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
                    } else if store.recordFailedPromoAttempt() {
                        progress.grantBonusStars(StoreManager.promoFailBonusStars)
                        codeState = .bonusGranted
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
            case .bonusGranted:
                Label("That code wasn't right, but here — 100 stars on the house!",
                      systemImage: "star.circle.fill")
                    .font(.system(.caption, design: .rounded).bold())
                    .foregroundStyle(settings.theme.lumen.color)
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

    // MARK: Satın alma sonucu bildirimi

    @ViewBuilder
    private func statusBanner(_ status: StoreManager.StatusMessage) -> some View {
        let (text, icon, color): (LocalizedStringKey, String, Color) = {
            switch status {
            case .success:
                return ("Purchase complete — thank you!", "checkmark.circle.fill", settings.theme.gate.color)
            case .restored:
                return ("Purchases restored", "checkmark.circle.fill", settings.theme.gate.color)
            case .nothingToRestore:
                return ("No previous purchases found on this Apple Account", "info.circle.fill", .white.opacity(0.7))
            case .pending:
                return ("Waiting for approval — you'll get it once it's approved", "clock.fill", settings.theme.lumen.color)
            case .failed:
                return ("Purchase didn't go through. Nothing was charged.", "exclamationmark.triangle.fill", settings.theme.hazard.color)
            }
        }()

        Label(text, systemImage: icon)
            .font(.system(.footnote, design: .rounded).bold())
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 30)
            .onTapGesture { store.statusMessage = nil }
    }

    // MARK: Ödüllü reklamla bedava yıldız

    private var freeStarsCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(settings.theme.lumen.opacity(0.16))
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(settings.theme.lumen.color)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Free stars")
                        .font(.system(.headline, design: .rounded).bold())
                        .foregroundStyle(.white)
                    Text("Watch a short ad for \(StoreManager.rewardedStarGrant) stars")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer(minLength: 0)
            }

            Button {
                AudioEngine.shared.playTap()
                ads.showRewarded { earned in
                    guard earned else { return }
                    progress.grantBonusStars(StoreManager.rewardedStarGrant)
                    AudioEngine.shared.playWin()
                    Haptics.shared.win()
                    starsJustEarned = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { starsJustEarned = false }
                }
            } label: {
                Label(starsJustEarned ? "Nice! Stars added" : "Watch & earn",
                      systemImage: starsJustEarned ? "checkmark.circle.fill" : "star.fill")
            }
            .buttonStyle(GlowButtonStyle(color: settings.theme.lumen.color))
            .disabled(starsJustEarned)

            if let notice = ads.rewardNotice {
                Label(notice == .unavailable
                      ? "No ad available right now — try again in a bit"
                      : "Ad closed early — no stars this time",
                      systemImage: "info.circle.fill")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .onTapGesture { ads.dismissRewardNotice() }
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

            // Şampiyon küresi listede DURUR ama satın alınamaz. Gizlemek,
            // kazanılabileceğini kimsenin bilmemesi demek olurdu.
            championRow
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.05))
        }
        .padding(.horizontal, 20)
    }

    /// Yalnızca haftalık ilk üçe girerek kazanılan küre. Kazanıldıysa
    /// seçilebilir, kazanılmadıysa nasıl alınacağını söyler.
    private var championRow: some View {
        let style = OrbStyle.champion
        let owned = progress.isOrbUnlocked(style)
        let selected = settings.orbStyleID == style.id
        return HStack(spacing: 14) {
            CharacterPreview(kind: style.kind, theme: settings.theme)
                .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 2) {
                Text(style.localizedName)
                    .font(.system(.body, design: .rounded).bold())
                    .foregroundStyle(.white)
                Text(owned ? "Won on the weekly board"
                           : "Finish in the weekly top 3 to win it")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer(minLength: 0)

            if owned {
                Button {
                    AudioEngine.shared.playTap()
                    settings.orbStyleID = style.id
                } label: {
                    Text(selected ? "Selected" : "Select")
                        .font(.system(.caption, design: .rounded).bold())
                        .foregroundStyle(selected ? .black.opacity(0.8) : .white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background {
                            Capsule().fill(selected
                                           ? AnyShapeStyle(settings.theme.lumen.color)
                                           : AnyShapeStyle(Color.white.opacity(0.14)))
                        }
                }
                .disabled(selected)
            } else {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .padding(.vertical, 4)
    }

    private func characterRow(_ style: OrbStyle) -> some View {
        // Yıldızlı karakterler premium'da bile yıldızla alınır — yıldız
        // toplamanın anlamı korunur; premium yalnızca foto küreyi açar
        let owned = progress.isOrbUnlocked(style)
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
            ZStack {
                // Tacın arkasındaki yumuşak ışık havuzu
                Circle()
                    .fill(RadialGradient(colors: [settings.theme.lumen.opacity(0.45), .clear],
                                         center: .center, startRadius: 2, endRadius: 52))
                    .frame(width: 104, height: 104)
                    .scaleEffect(crownPulse ? 1.12 : 0.92)

                Image(systemName: "crown.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(
                        LinearGradient(colors: [.white, settings.theme.lumen.color],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: settings.theme.lumen.opacity(0.9), radius: crownPulse ? 18 : 10)
                    .scaleEffect(crownPulse ? 1.05 : 1.0)
            }
            .frame(height: 76)

            Text("Orbeon Premium")
                .font(.system(.title, design: .rounded).bold())
                .foregroundStyle(
                    LinearGradient(colors: [.white, settings.theme.lumen.opacity(0.75)],
                                   startPoint: .leading, endPoint: .trailing)
                )

            VStack(alignment: .leading, spacing: 10) {
                benefit("rectangle.slash", "All ads removed forever")
                benefit("paintpalette.fill", "8 exclusive themes — Neon, Carbon, Royal, Sakura and more")
                benefit("circle.hexagongrid.circle", "Your own photo inside the orb")
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
            } else if store.productsLoaded {
                // Ürün mağazadan gelmedi (henüz yayında değil): sonsuz spinner
                // yerine kullanıcıya yol göster — koddu olan kod alanını kullanır.
                Text("Premium is coming soon to the App Store. Have a code? Enter it below.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 10)
            } else {
                ProgressView()
                    .tint(.white)
                    .padding(.vertical, 10)
            }
        }
        .padding(24)
        .background {
            let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

            // Derinlik veren çift katmanlı zemin
            shape.fill(
                LinearGradient(colors: [settings.theme.lumen.opacity(0.18),
                                        settings.theme.lumen.opacity(0.06)],
                               startPoint: .top, endPoint: .bottom)
            )

            // Kart yüzeyinde yavaşça süzülen ışık
            shape.fill(
                LinearGradient(colors: [.clear, .white.opacity(0.14), .clear],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .mask(shape)
            .offset(x: shimmer ? 220 : -220)
            .allowsHitTesting(false)

            shape.strokeBorder(
                LinearGradient(colors: [settings.theme.lumen.opacity(0.85),
                                        settings.theme.accent.opacity(0.35),
                                        settings.theme.lumen.opacity(0.7)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 1.5
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: settings.theme.lumen.opacity(0.22), radius: 18, y: 6)
        .padding(.horizontal, 20)
    }

    private func benefit(_ icon: String, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            // İkonu yuvarlak bir rozetin içine alarak listeye ritim veriyoruz
            ZStack {
                Circle()
                    .fill(settings.theme.accent.opacity(0.16))
                Circle()
                    .strokeBorder(settings.theme.accent.opacity(0.35), lineWidth: 1)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(settings.theme.accent.color)
            }
            .frame(width: 30, height: 30)

            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
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
                            // Küçük bahşişin iki olası kimliği var (eski ve yeni);
                            // hangisi mağazadan dönerse dönsün aynı görünsün
                            Text(StoreManager.tipSmallIDs.contains(product.id) ? "🏠☕️" : "🥐☕️")
                                .font(.title2)
                            Text(StoreManager.tipSmallIDs.contains(product.id)
                                 ? "Coffee at home" : "Coffee at a café")
                                .font(.system(.caption, design: .rounded).bold())
                                .foregroundStyle(.white.opacity(0.85))
                            Text(product.displayPrice)
                                .font(.system(.subheadline, design: .rounded).bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    LinearGradient(colors: [.white.opacity(0.13), .white.opacity(0.05)],
                                                   startPoint: .top, endPoint: .bottom)
                                )
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(colors: [.white.opacity(0.32), .white.opacity(0.12)],
                                                   startPoint: .top, endPoint: .bottom),
                                    lineWidth: 1
                                )
                        }
                        .foregroundStyle(.white)
                    }
                    .disabled(store.purchaseInProgress)
                }
            }

            Text("Same coffee — the café just charges for the chairs 😄")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)

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
        case .bubble:
            Circle().strokeBorder(.white.opacity(0.85), lineWidth: 1.5)
                .background(Circle().fill(.white.opacity(0.25)))
                .frame(width: 18, height: 18)
        case .heart:
            Image(systemName: "heart.fill").font(.system(size: 18))
                .foregroundStyle(Color.pink).shadow(color: .pink, radius: 6)
        case .firefly:
            Image(systemName: "sparkle").font(.system(size: 18))
                .foregroundStyle(Color(red: 0.75, green: 1.0, blue: 0.4))
                .shadow(color: Color(red: 0.75, green: 1.0, blue: 0.4), radius: 6)
        case .cloud:
            Image(systemName: "cloud.fill").font(.system(size: 18))
                .foregroundStyle(.white)
        case .champion:
            Image(systemName: "crown.fill").font(.system(size: 18))
                .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.35))
                .shadow(color: Color(red: 1.0, green: 0.82, blue: 0.35), radius: 7)
        }
    }
}
