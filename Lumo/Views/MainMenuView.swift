import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var player: PlayerStore
    @EnvironmentObject private var daily: DailyRewardStore
    @EnvironmentObject private var missions: MissionStore
    @EnvironmentObject private var leaderboard: LeaderboardService

    @State private var showMissions = false
    @State private var claimedFlash: Int?
    @State private var championAward: (rank: Int, stars: Int)?
    /// Yıldız eşiği geçilip açılan, henüz gösterilmemiş karakter
    @State private var orbReveal: OrbStyle?

    var body: some View {
        ZStack {
            AnimatedBackground(theme: settings.theme)

            // Üst şerit: solda premium durumu, sağda sıralama ve ayarlar.
            // İkisi de ortalamayı bozmayan ayrı bir katmanda duruyor; alttaki
            // düğme yığını böylece kısaldı ve menü daha sakin görünüyor.
            VStack {
                HStack(spacing: 8) {
                    premiumBadge
                    Spacer()
                    Button {
                        AudioEngine.shared.playTap()
                        player.hasUsername ? (app.route = .ranking) : app.openUsername()
                    } label: {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(settings.theme.lumen.color)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.white.opacity(0.1)))
                    }
                    Button {
                        AudioEngine.shared.playTap()
                        app.route = .settings
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white.opacity(0.75))
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.white.opacity(0.1)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                Spacer()
            }
            .zIndex(1)

            // Küçük ekranlarda taşmasın diye kaydırılabilir; büyük ekranda ortalanır
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: 28)

                        logo
                            .padding(.top, 8)

                        // kerning son harften sonra da boşluk ekler; sola kaymayı
                        // dengelemek için sol tarafa aynı miktarda boşluk veriyoruz
                        // İnce ve geniş aralıklı, parıltısız: kalın siyah harf
                        // ve mor hâle, mat görsel dille çelişiyordu
                        Text("ORBEON")
                            .font(.system(size: 42, weight: .light, design: .default))
                            .foregroundStyle(.white)
                            .kerning(13)
                            .padding(.leading, 13)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .padding(.top, 14)

                        Text("the journey of light")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .kerning(4)
                            .padding(.leading, 4)

                        if progress.totalStars > 0 {
                            starGoal.padding(.top, 12)
                        }

                        Spacer(minLength: 24)

                        dailyStrip
                            .padding(.horizontal, 28)
                            .padding(.bottom, 14)

                        weeklyPodium
                            .padding(.horizontal, 28)
                            .padding(.bottom, 14)

                        actions
                            .padding(.horizontal, 28)
                            .padding(.bottom, 28)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geo.size.height)
                    .multilineTextAlignment(.center)
                }
            }
        }
        .onAppear {
            leaderboard.configureIfPossible()
            leaderboard.refresh(mode: .endless, myPlayerID: player.playerID)
            Task { await claimChampionRewardIfEarned() }
            orbReveal = progress.pendingOrbReveal()
        }
        .onChange(of: progress.totalStars) { _, _ in
            // Günlük ödül, görev ve şampiyonluk yıldızları da eşik geçirebilir
            if orbReveal == nil { orbReveal = progress.pendingOrbReveal() }
        }
        .overlay {
            if let award = championAward {
                ChampionAwardView(rank: award.rank, stars: award.stars,
                                  theme: settings.theme) { championAward = nil }
            } else if let style = orbReveal {
                OrbRevealView(style: style, theme: settings.theme) {
                    settings.orbStyleID = style.id
                    progress.markOrbRevealed(style)
                    orbReveal = progress.pendingOrbReveal()
                } onClose: {
                    progress.markOrbRevealed(style)
                    orbReveal = progress.pendingOrbReveal()
                }
            }
        }
    }

    /// Yıldız hedefi. Toplam sayı ("x / 806") oyuncuya hiçbir şey
    /// söylemiyordu — kaç yıldız biriktiği değil, SIRADAKİ karaktere ne
    /// kaldığı önemli. Hepsi açıldıysa yalnızca bu söyleniyor, sayı yok.
    @ViewBuilder
    private var starGoal: some View {
        if let goal = progress.nextOrbGoal {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(settings.theme.lumen.color)
                    Text("\(goal.remaining) stars to the next character")
                        .font(.system(.subheadline, design: .rounded).bold())
                        .foregroundStyle(.white.opacity(0.8))
                }
                if let cost = goal.style.starCost {
                    // Önizleme BULANIK: ne kazanacağını merak etsin
                    HStack(spacing: 8) {
                        CharacterPreview(kind: goal.style.kind, theme: settings.theme)
                            .frame(width: 22, height: 22)
                            .blur(radius: 4)
                        ProgressView(value: Double(min(progress.totalStars, cost)),
                                     total: Double(max(cost, 1)))
                            .tint(settings.theme.lumen.color)
                            .frame(width: 120)
                    }
                }
            }
        } else {
            // Hepsi açıldı: toplanan yıldız sayısı burada bir işe yaramıyor,
            // yalnızca hedefin bittiğini söylemek yetiyor
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(settings.theme.lumen.color)
                Text("All characters unlocked")
                    .font(.system(.subheadline, design: .rounded).bold())
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    /// Sol üst köşe. Premium değilse sade bir çağrı, premiumsa yalnızca bir
    /// nişan — ikisi de mağazaya götürüyor, böylece alttaki "Mağaza" düğmesine
    /// gerek kalmadı.
    private var premiumBadge: some View {
        Button {
            AudioEngine.shared.playTap()
            app.route = .shop
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 12, weight: .bold))
                if store.isPremium {
                    Text(verbatim: "PREMIUM")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .kerning(1.6)
                } else {
                    Text("Go Premium")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
            }
            .foregroundStyle(
                store.isPremium
                ? LinearGradient(colors: [settings.theme.lumen.color, .white],
                                 startPoint: .leading, endPoint: .trailing)
                : LinearGradient(colors: [.white.opacity(0.85), .white.opacity(0.85)],
                                 startPoint: .leading, endPoint: .trailing)
            )
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(
                Capsule().fill(.white.opacity(store.isPremium ? 0.06 : 0.12))
            )
            .overlay(
                Capsule().stroke(
                    store.isPremium ? settings.theme.lumen.opacity(0.55) : .white.opacity(0.14),
                    lineWidth: 1
                )
            )
            .shadow(color: store.isPremium ? settings.theme.lumen.opacity(0.35) : .clear, radius: 10)
        }
    }

    /// Geçen haftanın ilk üçündeysem ödülü bir kez verir ve kutlama gösterir.
    /// Sıra sunucudan okunur; ödülün iki kez verilmemesini ProgressStore
    /// hafta numarasıyla güvenceye alır (iCloud üzerinden de eşitlenir).
    private func claimChampionRewardIfEarned() async {
        guard player.hasUsername else { return }
        guard let result = await leaderboard.previousWeekRank(playerID: player.playerID) else { return }
        guard result.week > progress.lastChampionWeek else { return }
        let amount = LeaderboardService.championStars(forRank: result.rank)
        guard progress.grantChampionReward(week: result.week, rank: result.rank, stars: amount) else { return }
        AudioEngine.shared.playWin()
        Haptics.shared.win()
        championAward = (result.rank, amount)
    }

    /// Haftanın ilk üçü. Sıralama her Pazartesi sıfırlandığı için menüde
    /// durması anlamlı: tablo ulaşılabilir görünüyor ve hafta içinde değişiyor.
    ///
    /// Kutu tablo boşken de çizilir. Önce boşsa tamamen gizleniyordu ve bu,
    /// "henüz kimse oynamamış", "adın yok" ve "sıralama bağlı değil"
    /// durumlarını birbirinden ayırt edilemez kılıyordu — ekranda hiçbir şey
    /// olmadığı için sebebi ancak günlüklere bakarak anlamak mümkündü.
    @ViewBuilder
    private var weeklyPodium: some View {
        if leaderboard.isAvailable {
            let top = Array(leaderboard.endlessEntries.prefix(3))
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(settings.theme.lumen.color)
                    Text("Champions of the week")
                        .font(.system(.caption, design: .rounded).bold())
                        .foregroundStyle(.white.opacity(0.75))
                    Spacer(minLength: 0)
                    Text("\(leaderboard.resetCountdownText) left")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                }

                if !top.isEmpty {
                    ForEach(Array(top.enumerated()), id: \.element.id) { index, entry in
                        HStack(spacing: 10) {
                            Text(Self.medals[index])
                                .font(.system(size: 15))
                            Text(entry.username)
                                .font(.system(.subheadline, design: .rounded).bold())
                                .foregroundStyle(entry.isMe ? settings.theme.lumen.color : .white.opacity(0.9))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text("\(Int(entry.value))")
                                .font(.system(.subheadline, design: .rounded).bold())
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                } else if leaderboard.isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                } else {
                    Text(player.hasUsername
                         ? "No scores this week yet — play Endless to take the top spot"
                         : "No scores this week yet — set your name to join")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 2)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.07))
            }
            .contentShape(Rectangle())
            .onTapGesture {
                AudioEngine.shared.playTap()
                player.hasUsername ? (app.route = .ranking) : app.openUsername()
            }
        }
    }

    private static let medals = ["🥇", "🥈", "🥉"]

    /// Yayın çember üstündeki yeri — hem çizim hem de kürenin "yay üstünde mi"
    /// hesabı aynı sayıları kullansın diye tek yerde. (Android'de de aynı.)
    private static let logoArcStart = -103.0
    private static let logoArcSweep = 94.0
    private static let logoPeriod = 9.0     // bir tur kaç saniye
    private static let logoSize = 126.0

    /// Marka işareti oyunun kendisi: nötr bir halka, üstünde tek kırmızı yay,
    /// çemberin üstünde dolanan beyaz küre. Yani logo, oyunun bir karesi.
    ///
    /// Canvas ile ÇİZİLİYOR, view ağacıyla kurulmuyor. Küre bir görünüm olduğu
    /// sürece SwiftUI onun konumunu animasyona uygun sayıyor: menünün yerleşimi
    /// oynadığında (yıldız hedefi tek satırdan iki satıra geçince) ya da tur
    /// 360°'den 0°'ye dönerken, üstteki herhangi bir örtük animasyon araya girip
    /// küreyi alt noktada kaydırıyordu. Canvas'ta böyle bir ara değer yok.
    private var logo: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let turn = (t / Self.logoPeriod).truncatingRemainder(dividingBy: 1)
            logoCanvas(degrees: turn * 360)
        }
        .frame(width: Self.logoSize, height: Self.logoSize)
    }

    private func logoCanvas(degrees: Double) -> some View {
        let ring = settings.theme.ring.color
        let hazard = settings.theme.hazard.color
        let orb = settings.theme.orb.color
        let heat = hazardHeat(degrees: degrees)

        return Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = size.width * 0.373
            let box = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)

            ctx.stroke(Path(ellipseIn: box), with: .color(ring), lineWidth: 4)

            var arc = Path()
            arc.addArc(center: c, radius: r,
                       startAngle: .degrees(Self.logoArcStart),
                       endAngle: .degrees(Self.logoArcStart + Self.logoArcSweep),
                       clockwise: false)
            ctx.stroke(arc, with: .color(hazard),
                       style: StrokeStyle(lineWidth: 9, lineCap: .round))

            // 0° = alt nokta; oradan saat yönünde döner
            let a = (degrees + 90) * .pi / 180
            let p = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
            let orbR = 8.5

            // Küre kırmızı yayın üstünden geçerken yanar, çıkınca beyaza döner:
            // logo, oyunun tek kuralını bir turda anlatıyor.
            if heat > 0 {
                let g = orbR * (1 + heat * 0.7)
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - g, y: p.y - g, width: g * 2, height: g * 2)),
                         with: .color(hazard.opacity(heat * 0.35)))
            }
            let dot = Path(ellipseIn: CGRect(x: p.x - orbR, y: p.y - orbR,
                                             width: orbR * 2, height: orbR * 2))
            ctx.fill(dot, with: .color(orb))
            if heat > 0 { ctx.fill(dot, with: .color(hazard.opacity(heat))) }
        }
    }

    /// Kürenin yaya ne kadar girdiği (0 = uzak, 1 = tam üstünde).
    /// Uçlarda yumuşak geçiş var; sert renk sıçraması ucuz duruyordu.
    private func hazardHeat(degrees: Double) -> Double {
        func norm(_ a: Double) -> Double {
            let m = a.truncatingRemainder(dividingBy: 360)
            return m < 0 ? m + 360 : m
        }
        func gap(_ a: Double, _ b: Double) -> Double {
            let d = abs(a - b).truncatingRemainder(dividingBy: 360)
            return min(d, 360 - d)
        }

        let orb = norm(degrees + 90)
        let start = norm(Self.logoArcStart)
        let end = norm(Self.logoArcStart + Self.logoArcSweep)

        let inside = start <= end
            ? (orb >= start && orb <= end)
            : (orb >= start || orb <= end)
        if inside { return 1 }

        let fade = 16.0
        return max(0, 1 - min(gap(orb, start), gap(orb, end)) / fade)
    }

    /// Günlük ödül + görevler — menüde tek satır, panel açılır kapanır
    private var dailyStrip: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    AudioEngine.shared.playTap()
                    if let reward = daily.claim() {
                        progress.grantBonusStars(reward)
                        AudioEngine.shared.playWin()
                        Haptics.shared.win()
                        claimedFlash = reward
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { claimedFlash = nil }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: daily.claimedToday ? "checkmark.seal.fill" : "gift.fill")
                        VStack(alignment: .leading, spacing: 1) {
                            Text(daily.claimedToday ? "Claimed today" : "Daily +\(daily.todayReward)")
                                .font(.system(.subheadline, design: .rounded).bold())
                            if daily.streak > 0 {
                                Text("\(daily.streak) day streak")
                                    .font(.system(size: 10, design: .rounded))
                                    .opacity(0.7)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .foregroundStyle(daily.claimedToday ? .white.opacity(0.5) : .black)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(daily.claimedToday
                                  ? Color.white.opacity(0.08)
                                  : settings.theme.lumen.color)
                    }
                }
                .disabled(daily.claimedToday)

                Button {
                    AudioEngine.shared.playTap()
                    withAnimation(.easeInOut(duration: 0.25)) { showMissions.toggle() }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "checklist")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 46, height: 44)
                            .background {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(.white.opacity(0.1))
                            }
                        if missions.unclaimedCount > 0 {
                            Circle()
                                .fill(settings.theme.hazard.color)
                                .frame(width: 10, height: 10)
                                .offset(x: 3, y: -3)
                        }
                    }
                }
            }

            if let reward = claimedFlash {
                Label("+\(reward) stars", systemImage: "star.fill")
                    .font(.system(.caption, design: .rounded).bold())
                    .foregroundStyle(settings.theme.lumen.color)
            }

            if showMissions {
                VStack(spacing: 8) {
                    ForEach(missions.missions) { mission in
                        missionRow(mission)
                    }
                }
                .padding(14)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.white.opacity(0.06))
                }
            }
        }
    }

    private func missionRow(_ mission: MissionStore.Mission) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(mission.title)
                    .font(.system(.caption, design: .rounded).bold())
                    .foregroundStyle(.white.opacity(0.9))

                // İlerleme çubuğu
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.12))
                        Capsule()
                            .fill(mission.isComplete ? settings.theme.gate.color : settings.theme.accent.color)
                            .frame(width: geo.size.width * mission.fraction)
                    }
                }
                .frame(height: 5)

                Text("\(min(mission.progress, mission.target)) / \(mission.target)")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }

            if mission.claimed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(settings.theme.gate.color)
            } else if mission.isComplete {
                Button {
                    if let reward = missions.claim(mission.id) {
                        progress.grantBonusStars(reward)
                        AudioEngine.shared.playWin()
                        Haptics.shared.win()
                    }
                } label: {
                    Text("+\(mission.reward)")
                        .font(.system(.caption, design: .rounded).bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(settings.theme.lumen.color))
                }
            } else {
                Text("+\(mission.reward)")
                    .font(.system(.caption, design: .rounded).bold())
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                AudioEngine.shared.playTap()
                app.route = .game(progress.highestUnlocked)
            } label: {
                if progress.completedCount == 0 {
                    Label("Play", systemImage: "play.fill")
                } else {
                    Label("Continue — Level \(progress.highestUnlocked)", systemImage: "play.fill")
                }
            }
            .buttonStyle(GlowButtonStyle(color: settings.theme.accent.color, prominent: true))

            Button {
                AudioEngine.shared.playTap()
                app.route = .levels
            } label: {
                Label("Levels", systemImage: "circle.grid.3x3.fill")
            }
            .buttonStyle(GlowButtonStyle(color: settings.theme.ring.color))

            Button {
                AudioEngine.shared.playTap()
                if progress.endlessUnlocked { app.route = .endless }
            } label: {
                HStack { Spacer(); Label("Endless Mode", systemImage: "infinity"); Spacer() }
            }
            .buttonStyle(GlowButtonStyle(color: settings.theme.gate.color))
            .opacity(progress.endlessUnlocked ? 1 : 0.55)

            Button {
                AudioEngine.shared.playTap()
                if progress.endlessUnlocked { app.route = .speedrun }
            } label: {
                HStack { Spacer(); Label("Speed Run", systemImage: "stopwatch.fill"); Spacer() }
            }
            .buttonStyle(GlowButtonStyle(color: settings.theme.hazard.color))
            .opacity(progress.endlessUnlocked ? 1 : 0.55)

        }
    }
}

/// Haftalık şampiyonluk kutlaması. Ödül zaten verilmiş olur; bu ekran yalnızca
/// oyuncuya ne kazandığını söyler ve kapatılana kadar durur.
private struct ChampionAwardView: View {
    let rank: Int
    let stars: Int
    let theme: Theme
    let onClose: () -> Void

    private var medal: String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        default: return "🥉"
        }
    }

    private var rankSentence: LocalizedStringKey {
        switch rank {
        case 1: return "You finished 1st on last week's board."
        case 2: return "You finished 2nd on last week's board."
        default: return "You finished 3rd on last week's board."
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()

            VStack(spacing: 18) {
                Text(medal).font(.system(size: 64))

                Text("Champion of the week")
                    .font(.system(.title2, design: .rounded).bold())
                    .foregroundStyle(.white)

                // Üç ayrı düz metin: araya sıra numarası enterpole edilirse
                // çeviri anahtarı "%@" içeren tek bir kalıba dönüşür ve
                // eklenen çeviriler eşleşmez.
                Text(rankSentence)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)

                HStack(spacing: 22) {
                    VStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.title2)
                            .foregroundStyle(theme.lumen.color)
                        Text("+\(stars)")
                            .font(.system(.headline, design: .rounded).bold())
                            .foregroundStyle(.white)
                    }
                    VStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .font(.title2)
                            .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.35))
                        Text("Champion orb")
                            .font(.system(.caption, design: .rounded).bold())
                            .foregroundStyle(.white)
                    }
                }
                .padding(.top, 4)

                Text("The champion orb cannot be bought — it is only won.")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)

                Button(action: onClose) { Text("Nice") }
                    .buttonStyle(GlowButtonStyle(color: theme.lumen.color, prominent: true))
                    .padding(.top, 6)
            }
            .padding(28)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.black.opacity(0.55))
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color(red: 1.0, green: 0.82, blue: 0.35).opacity(0.45), lineWidth: 1.5)
            }
            .padding(.horizontal, 34)
        }
    }
}
