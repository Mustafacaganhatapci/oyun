import SwiftUI
import PhotosUI

/// Sahip olduklarını düzenlediğin ekran: karakterler, arka planlar, fotoğraflı
/// küre. Burada hiçbir şey satılmıyor.
///
/// Eskiden bunlar premium teklifiyle aynı sayfadaydı ve hangisinin yıldızla,
/// hangisinin parayla açıldığı birbirine karışıyordu.
struct PersonalizeView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var ads: AdsManager

    @State private var starsJustEarned = false
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BackButton { app.route = .menu }
                Spacer()
                Text("Personalize")
                    .font(.system(.title2, design: .rounded).bold())
                    .foregroundStyle(.white)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.footnote)
                        .foregroundStyle(settings.theme.lumen.color)
                    Text("\(progress.totalStars)")
                        .font(.system(.subheadline, design: .rounded).bold())
                        .foregroundStyle(.white)
                }
                .frame(minWidth: 44)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            ScrollView {
                VStack(spacing: 20) {
                    if !store.isPremium { freeStarsCard }

                    charactersSection

                    backgroundsSection

                    // Premium'a giden tek yol burada: kilitli tema ya da foto küre
                    if !store.isPremium {
                        Button {
                            AudioEngine.shared.playTap()
                            app.route = .premium
                        } label: {
                            Label("See Premium", systemImage: "crown.fill")
                        }
                        .buttonStyle(GlowButtonStyle(color: settings.theme.lumen.color))
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: Arka planlar

    /// Temalar ayarlardan buraya taşındı: sekizi premium'a dahil olduğu için
    /// asıl yeri satın alma ekranı, ayarlar da böylece sadeleşti.
    private var backgroundsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Backgrounds")
                .font(.system(.headline, design: .rounded).bold())
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Theme.all) { theme in
                        let locked = theme.isPremium && !store.isPremium
                        ThemeSwatch(theme: theme,
                                    selected: settings.themeID == theme.id,
                                    locked: locked) {
                            AudioEngine.shared.playTap()
                            // Kilitli tema = premium teklifi; doğrudan o ekrana
                            if locked { app.route = .premium } else { settings.themeID = theme.id }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
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
                Text("Unlocks as you collect stars ★")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }

            ForEach(OrbStyle.starLadder) { style in
                characterRow(style)
            }

            // Şampiyon küresi listede DURUR ama satın alınamaz. Gizlemek,
            // kazanılabileceğini kimsenin bilmemesi demek olurdu.
            championRow

            // "Yüzünü küreye koy" premium'un kendi vaadi; fotoğraf seçme de
            // bu yüzden burada duruyor
            if store.isPremium {
                photoOrbRow
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.05))
        }
        .padding(.horizontal, 20)
    }

    /// Fotoğraflı küre — premium'un en görünür ayrıcalığı. Stili kuşandırır
    /// ve fotoğrafı buradan seçtirir; ayarlara gitmeye gerek kalmıyor.
    private var photoOrbRow: some View {
        let style = OrbStyle.style(id: "photo")
        let selected = settings.orbStyleID == style.id
        // Tema kapanışların DIŞINDA bir kez okunur. SettingsStore @MainActor;
        // PhotosPicker'ın etiket kapanışı içinden okunduğunda derleyici onu
        // aktörden kaçan bir erişim sayıyor.
        let theme = settings.theme
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                CharacterPreview(kind: style.kind, theme: theme)
                    .frame(width: 46, height: 46)
                    .id(settings.orbPhotoVersion)

                VStack(alignment: .leading, spacing: 2) {
                    Text(style.localizedName)
                        .font(.system(.body, design: .rounded).bold())
                        .foregroundStyle(.white)
                    Text("Your photo stays on your device only.")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                }

                Spacer()

                Button {
                    AudioEngine.shared.playTap()
                    settings.orbStyleID = style.id
                } label: {
                    Text(selected ? "Selected" : "Select")
                        .font(.system(.caption, design: .rounded).bold())
                        .foregroundStyle(selected ? .white.opacity(0.5) : .black)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(selected ? .white.opacity(0.12)
                                                            : theme.lumen.color))
                }
                .disabled(selected)
            }

            PhotosPicker(selection: $photoItem, matching: .images) {
                Label(OrbPhotoStore.exists ? "Change Photo" : "Choose Photo",
                      systemImage: "photo.circle.fill")
                    .font(.system(.subheadline, design: .rounded).bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(theme.accent.opacity(0.3)))
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        OrbPhotoStore.save(image)
                        settings.orbPhotoVersion += 1
                    }
                }
            }
        }
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
        // Küreler artık satın alınmıyor: yıldız eşiği geçilince kendiliğinden
        // açılıyor. Kilitliyken önizleme BULANIK ve adı gizli — ne kazanacağını
        // merak etsin, ama ne olduğunu görmesin.
        let owned = progress.isOrbUnlocked(style)
        let equipped = settings.orbStyleID == style.id
        let cost = style.starCost ?? 0
        let remaining = max(0, cost - progress.totalStars)
        return HStack(spacing: 14) {
            CharacterPreview(kind: style.kind, theme: settings.theme)
                .frame(width: 46, height: 46)
                .blur(radius: owned ? 0 : 7)
                .overlay {
                    if !owned {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(owned ? style.localizedName : "???")
                    .font(.system(.body, design: .rounded).bold())
                    .foregroundStyle(owned ? .white : .white.opacity(0.55))
                if !owned {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill").font(.system(size: 10))
                        Text("\(remaining) more stars")
                            .font(.system(.caption, design: .rounded).bold())
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
                // Eşiğe ne kadar kaldığı çubuktan da okunsun
                ProgressView(value: Double(min(progress.totalStars, cost)),
                             total: Double(max(cost, 1)))
                    .tint(settings.theme.lumen.color)
                    .frame(width: 70)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Mağaza/ayarlarda küre stilinin küçük önizlemesi
struct CharacterPreview: View {
    let kind: OrbStyle.Kind
    let theme: Theme

    /// Oyundaki karşılıklarıyla birebir aynı iki sabit renk
    private static let fireflyGlow = Color(red: 0.75, green: 1.0, blue: 0.4)
    private static let championGold = Color(red: 1.0, green: 0.82, blue: 0.35)

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
                .foregroundStyle(theme.gate.opacity(0.85))
                .overlay {
                    Image(systemName: "hexagon").font(.system(size: 18))
                        .foregroundStyle(.white)
                }
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
            // Oyundaki hâli 45° döndürülmüş bir kare; kart maçası değil
            Rectangle()
                .fill(theme.accent.color)
                .overlay(Rectangle().strokeBorder(.white, lineWidth: 1.2))
                .frame(width: 14, height: 14)
                .rotationEffect(.degrees(45))
        case .flame:
            ZStack {
                Image(systemName: "flame.fill").font(.system(size: 19))
                    .foregroundStyle(theme.hazard.color)
                Image(systemName: "flame.fill").font(.system(size: 10))
                    .foregroundStyle(theme.lumen.color)
                    .offset(y: 3)
            }
        case .pixel:
            RoundedRectangle(cornerRadius: 2)
                .fill(theme.gate.color)
                .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(.white, lineWidth: 1))
                .frame(width: 15, height: 15)
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
            // Oyundaki hâli: koyu gövde, altında yanıp sönen yeşil kuyruk
            ZStack {
                Circle().fill(Color(red: 0.16, green: 0.12, blue: 0.08))
                    .frame(width: 13, height: 13)
                Circle().fill(Self.fireflyGlow)
                    .frame(width: 8, height: 8)
                    .shadow(color: Self.fireflyGlow, radius: 5)
                    .offset(y: 7)
            }
        case .cloud:
            // Oyundaki hâli üç beyaz yumak; tek bulut ikonu değil
            ZStack {
                Circle().fill(.white).frame(width: 11, height: 11).offset(x: -6, y: 2)
                Circle().fill(.white).frame(width: 9, height: 9).offset(x: 7, y: 2)
                Circle().fill(.white).frame(width: 14, height: 14).offset(y: -2)
            }
        case .champion:
            ZStack {
                Circle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 5]))
                    .foregroundStyle(Self.championGold.opacity(0.85))
                    .frame(width: 32, height: 32)
                Image(systemName: "crown.fill").font(.system(size: 16))
                    .foregroundStyle(Self.championGold)
                    .shadow(color: Self.championGold, radius: 6)
            }
        }
    }
}

/// Arka plan kartı. Ayarlar'dan Kişiselleştir ekranına taşındı.
struct ThemeSwatch: View {
    let theme: Theme
    let selected: Bool
    let locked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(colors: [theme.bgTop.color, theme.bgBottom.color],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 84, height: 110)

                    Circle()
                        .strokeBorder(theme.ring.color, lineWidth: 2.5)
                        .frame(width: 34, height: 34)
                    Circle()
                        .fill(theme.orb.color)
                        .frame(width: 9, height: 9)
                        .offset(x: 17)
                        .shadow(color: theme.accent.color, radius: 4)

                    if locked {
                        Color.black.opacity(0.45)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(selected ? theme.accent.color : .white.opacity(0.15),
                                      lineWidth: selected ? 2.5 : 1)
                }

                HStack(spacing: 3) {
                    if theme.isPremium {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(theme.lumen.color)
                    }
                    Text(theme.localizedName)
                        .font(.system(.caption, design: .rounded).bold())
                        .foregroundStyle(selected ? .white : .white.opacity(0.6))
                }
            }
        }
    }
}
