import SwiftUI
import StoreKit

/// Premium teklifi — tek işi olan tek ekran.
///
/// Faydalar madde madde YAZILMIYOR, GÖSTERİLİYOR: sekiz tema kendi renkleriyle,
/// foto küre gerçek önizlemesiyle, kendi seslerin yükselen bir dalga olarak.
/// "8 exclusive themes" cümlesi neyi aldığını anlatmıyordu.
struct PremiumView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var progress: ProgressStore

    @State private var codeInput = ""
    @State private var codeState: CodeState = .idle
    @State private var checkingCode = false
    @FocusState private var codeFocused: Bool
    @State private var shimmer = false
    @State private var crownPulse = false

    private enum CodeState { case idle, success, failure, bonusGranted }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BackButton { app.route = .menu }
                Spacer()
                Text("Orbeon Premium")
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

                    if !store.isPremium {
                        starPathCard
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

                    if let status = store.statusMessage { statusBanner(status) }

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
        .onAppear {
            // Tek geçiş: ekran otursun diye kısa bir gecikme, sonra soldan
            // sağa bir tarama ve bitiş
            withAnimation(.easeInOut(duration: 1.15).delay(0.25)) { shimmer = true }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { crownPulse = true }
        }
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

            VStack(spacing: 12) {
                benefit("rectangle.slash", "All ads removed forever") { EmptyView() }

                benefit("mic.fill", "Your own recorded sounds") {
                    // Yükselen dalga: kaydın komboyla tizleşmesinin görüntüsü
                    HStack(spacing: 3) {
                        ForEach(0..<6, id: \.self) { i in
                            Capsule()
                                .fill(settings.theme.accent.color)
                                .frame(width: 3, height: 6 + CGFloat(i) * 4)
                        }
                    }
                }

                benefit("heart.circle.fill", "An extra life in every endless run") {
                    Text(verbatim: "♥")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(settings.theme.hazard.color)
                }

                benefit("paintpalette.fill", "8 exclusive themes") {
                    // Temaların kendi renkleri — hangi sekizi aldığını görüyorsun
                    HStack(spacing: -6) {
                        ForEach(Theme.all.filter(\.isPremium).prefix(8)) { theme in
                            Circle()
                                .fill(LinearGradient(colors: [theme.bgTop.color, theme.accent.color],
                                                     startPoint: .top, endPoint: .bottom))
                                .frame(width: 18, height: 18)
                                .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                        }
                    }
                }

                benefit("circle.hexagongrid.circle", "Your own photo inside the orb") {
                    CharacterPreview(kind: .photo, theme: settings.theme)
                        .frame(width: 30, height: 30)
                }

                benefit("heart.fill", "Direct support for an independent developer") { EmptyView() }
            }
            .padding(.vertical, 6)

            if store.isPremium {
                Label("Thank you! Premium is active", systemImage: "checkmark.circle.fill")
                    .font(.system(.headline, design: .rounded).bold())
                    .foregroundStyle(settings.theme.gate.color)
                    .padding(.vertical, 10)
            } else if let product = store.premiumProduct {
                if store.isPriceHoldActive { priceHoldBadge }
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
                // yerine kullanıcıya yol göster — kodu olan kod alanını kullanır.
                Text("Premium is coming soon to the App Store. Have a code? Enter it below.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 10)
            } else {
                ProgressView().tint(.white).padding(.vertical, 10)
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

            // Kart açılırken yüzeyinden BİR KEZ geçen ışık.
            //
            // Eskiden sonsuza kadar dönüyordu ve `repeatForever` her turun
            // sonunda parlamayı tek karede başa sıçratıyordu; üstelik bant
            // sabit ±220 punto gidip geldiği için kartın kenarından hiç
            // çıkmıyordu. İkisi birden hareketi yarım bırakılmış gösteriyordu.
            // Şimdi bant kartın soluna tamamen dışarıdan giriyor, sağından
            // tamamen çıkıyor ve bir daha dönmüyor: bir kez bakılan bir şey,
            // sürekli kıpırdayan bir şey değil.
            GeometryReader { geo in
                let w = geo.size.width
                let band = w * 0.42
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, .white.opacity(0.22), .clear],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: band)
                    .rotationEffect(.degrees(16))
                    .scaleEffect(y: 1.7)   // eğik bant köşeleri de süpürsün
                    .position(x: shimmer ? w + band : -band,
                              y: geo.size.height / 2)
            }
            .mask(shape)
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

    /// 2.0 ile gelen her şey fiyata dokunmadan geldi — söylenecek olan bu.
    /// Rozetin kendi bitiş tarihi var (`StoreManager.priceHoldEnds`); "bu ay"
    /// diyen bir cümle bir ay sonra kendiliğinden kaybolmalı.
    private var priceHoldBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "tag.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(settings.theme.gate.color)
            VStack(alignment: .leading, spacing: 2) {
                Text("Same price this month")
                    .font(.system(.subheadline, design: .rounded).bold())
                    .foregroundStyle(.white)
                Text("Everything new in 2.0 is included and the price did not go up.")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(settings.theme.gate.opacity(0.12))
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(settings.theme.gate.opacity(0.35), lineWidth: 1)
        }
        .padding(.bottom, 4)
    }

    /// Ödemeden gelen yol.
    ///
    /// Teklifi zayıflatmıyor: eşik kampanyanın verdiği yıldızın üç katından
    /// fazla, yani bu yolu seçen gerçekten oynuyor. Ama yazılı bir söz olarak
    /// duruyor — "parası olmayan asla alamaz" demeyen bir oyun, ödeyenin de
    /// gözünde daha dürüst.
    private var starPathCard: some View {
        let total = progress.totalStars
        let goal = StoreManager.starPremiumThreshold
        let remaining = max(0, goal - total)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .foregroundStyle(settings.theme.lumen.color)
                Text("Or earn it")
                    .font(.system(.headline, design: .rounded).bold())
                    .foregroundStyle(.white.opacity(0.9))
                Spacer(minLength: 8)
                Text(verbatim: "\(total) / \(goal)")
                    .font(.system(.subheadline, design: .rounded).bold())
                    .monospacedDigit()
                    .foregroundStyle(settings.theme.lumen.color)
            }

            ProgressView(value: store.starProgress(totalStars: total))
                .tint(settings.theme.lumen.color)

            Text("Premium unlocks by itself when you get there. Nothing is spent — every star stays yours.")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)

            if remaining > 0 {
                Text("\(remaining) more stars")
                    .font(.system(.caption, design: .rounded).bold())
                    .foregroundStyle(settings.theme.lumen.color)
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.05))
        }
        .padding(.horizontal, 20)
    }

    /// Solda ikon rozeti, ortada ad, sağda O ŞEYİN KENDİSİ.
    private func benefit<T: View>(_ icon: String, _ text: LocalizedStringKey,
                                  @ViewBuilder trailing: () -> T) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(settings.theme.accent.opacity(0.16))
                Circle().strokeBorder(settings.theme.accent.opacity(0.35), lineWidth: 1)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(settings.theme.accent.color)
            }
            .frame(width: 30, height: 30)

            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)
            trailing()
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
                    // Kod artık Firestore'a da sorulduğu için anında dönmüyor;
                    // beklerken düğmenin yerinde bir çember dönüyor.
                    checkingCode = true
                    Task {
                        let accepted = await store.redeem(code: codeInput)
                        checkingCode = false
                        if accepted {
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
                    }
                } label: {
                    Group {
                        if checkingCode {
                            ProgressView().tint(.black)
                        } else {
                            Text("Redeem")
                                .font(.system(.subheadline, design: .rounded).bold())
                                .foregroundStyle(.black)
                        }
                    }
                    .frame(minWidth: 64)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Capsule().fill(settings.theme.accent.color))
                }
                .disabled(codeInput.isEmpty || checkingCode)
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
                // Bahşiş tüketilebilir bir üründür ve Apple onu geri yüklemez.
                // Bahşiş bırakmış biri "hiçbir şey bulunamadı" görüp haklı
                // olarak kızıyordu; hakkı iCloud taşıyor, o yüzden yol orası.
                return ("Nothing to restore on this Apple Account. Tips carry over through iCloud — make sure iCloud Drive is on and you're signed in with the same account.",
                        "info.circle.fill", .white.opacity(0.7))
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
    private var tipSection: some View {
        VStack(spacing: 12) {
            Text("Tip Jar")
                .font(.system(.headline, design: .rounded).bold())
                .foregroundStyle(.white.opacity(0.9))
            // Bahşişin premium açtığı BİLEREK yazmıyor. Yazdığı sürece
            // bahşiş bahşiş olmaktan çıkıp indirimli bir satın alma oluyordu;
            // "ısmarla, premium da senin olsun" pazarlık cümlesiydi. Açılış
            // sürpriz kalsın: karşılık bekleyerek verilen şey hediye değil.
            Text("If you'd like to support the developer.")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))

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
