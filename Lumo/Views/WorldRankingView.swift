import SwiftUI

/// Dünya sıralaması. Firebase bağlıysa küresel ilk 50; değilse yerel en iyi + kurulum ipucu.
struct WorldRankingView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var player: PlayerStore
    @EnvironmentObject private var leaderboard: LeaderboardService

    @State private var mode: LeaderboardMode = .endless
    /// Kaç satır isteniyor. Tablo yüz satırla açılıyor, "daha fazla göster"
    /// her seferinde bir sayfa daha getiriyor — beş yüz kişiyi tek seferde
    /// indirmek hem yavaş hem gereksiz, kimse beşinci yüzü açar açmaz aramıyor.
    @State private var visibleRows = LeaderboardService.pageSize
    /// Kısa süre parlayacak satır — "beni bul"a basınca kendi satırın
    @State private var flashID: String?
    /// Satırlar henüz gelmedi, geldiğinde kaydır
    @State private var pendingJump = false
    /// Üstteki şeride basıldı. Kaydırıcı listenin İÇİNDE olduğu için şerit ona
    /// doğrudan erişemiyor; sayaç artınca liste kendi tarafında kaydırıyor.
    @State private var jumpRequest = 0

    private var entries: [LeaderboardEntry] {
        mode == .endless ? leaderboard.endlessEntries : leaderboard.speedrunEntries
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            // Mod seçici
            Picker("", selection: $mode) {
                Text("Endless").tag(LeaderboardMode.endless)
                Text("Speed Run").tag(LeaderboardMode.speedrun)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .onChange(of: mode) { _, _ in
                visibleRows = LeaderboardService.pageSize
                flashID = nil
                pendingJump = false
                load()
            }

            // Tablo haftalık: oyuncu neye baktığını ve ne zaman sıfırlanacağını
            // bilmezse eski skorların kaybolması hata gibi görünür
            if leaderboard.isAvailable {
                Text("This week · \(leaderboard.resetCountdownText) left")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.top, 8)
            }

            // "Sen buradasın" şeridi EN ÜSTTE. Aşağıdayken tabloyu sonuna
            // kadar kaydırmadan görülmüyordu; oysa oyuncunun bu ekranda ilk
            // sorduğu şey bu. Rütbe başlıklarından ayrışsın diye dolgulu ve
            // çerçeveli — onlar düz yazı, bu bir kart.
            if leaderboard.isAvailable, let rank = myPlace {
                myRankBanner(rank)
            }

            if !leaderboard.isAvailable {
                notConnected
            } else if leaderboard.isLoading && entries.isEmpty {
                Spacer()
                loadingOrb
                Spacer()
            } else if entries.isEmpty {
                Spacer()
                Text("No scores yet — be the first!")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
            } else {
                list
            }
        }
        .onAppear(perform: load)
    }

    private var header: some View {
        HStack {
            BackButton { app.route = .menu }
            Spacer()
            Text("World Ranking")
                .font(.system(.title2, design: .rounded).bold())
                .foregroundStyle(.white)
            Spacer()
            Button { app.openUsername() } label: {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.white.opacity(0.12)))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    /// Bir rütbe kümesi ve içindeki satırlar.
    ///
    /// Kimliklerin içinde MOD var. Doldurma belgeleri iki koleksiyonda da aynı
    /// kimliği taşıyor (`bot_w87_g3_000`); mod değiştirince SwiftUI aynı
    /// kimlikleri görüp satırları yeniden kurmuyor, eski içerikle bırakıyordu.
    /// Ekranda hız turundan kalma satırlar sonsuz modda görünüyordu.
    private struct RankGroup: Identifiable {
        let rank: Rank
        let modeKey: String
        var rows: [Row]
        var id: String { "\(modeKey)-\(rank.rawValue)" }

        struct Row: Identifiable {
            let place: Int              // tablodaki genel sıra (0'dan)
            let entry: LeaderboardEntry
            let modeKey: String
            var id: String { "\(modeKey)-\(entry.id)" }
        }
    }

    /// Kimliklerin mod öneki
    private var modeKey: String { mode == .endless ? "e" : "s" }

    /// Kaydırma çıpası — `RankGroup.Row.id` ile birebir aynı olmalı
    private func rowID(_ entry: LeaderboardEntry) -> String { "\(modeKey)-\(entry.id)" }

    /// Tablo rütbelere bölünmüş hâlde. Liste zaten skora göre sıralı olduğu
    /// için art arda gelenleri kümelemek yetiyor: küme başlığı her rütbe
    /// değiştiğinde düşüyor, en yüksek rütbe en üstte.
    private var groups: [RankGroup] {
        var out: [RankGroup] = []
        let key = modeKey
        for (place, entry) in entries.enumerated() {
            let rank = Rank.of(value: entry.value, mode: mode)
            let row = RankGroup.Row(place: place, entry: entry, modeKey: key)
            if out.last?.rank == rank {
                out[out.count - 1].rows.append(row)
            } else {
                out.append(RankGroup(rank: rank, modeKey: key, rows: [row]))
            }
        }
        return out
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(groups) { group in
                        groupHeader(group.rank, count: group.rows.count)
                        ForEach(group.rows) { item in
                            row(index: item.place, entry: item.entry, rank: group.rank)
                                .id(item.id)
                        }
                    }

                    // Düğmeye basmak yerine: son satır ekrana girince bir
                    // sayfa daha isteniyor. Beş yüz kişilik bir tabloda
                    // "daha fazla göster"e dört kez basmak iş gibi duruyordu.
                    if canLoadMore { loadMoreSentinel }

                    ladder
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
            .onChange(of: entries.count) { _, _ in
                guard pendingJump else { return }
                jump(with: proxy)
            }
            .onChange(of: jumpRequest) { _, _ in
                jump(with: proxy)
            }
        }
        // Mod değişince kaydırma görünümü baştan kurulur. Kimlikleri ayırmak
        // tek başına yetmiyor: liste yarı yolda kalmış bir animasyonla iki
        // veri kümesi arasında geçiş yapıyor ve arada karışık duruyordu.
        // Yan faydası: yeni tabloya en baştan bakıyorsun.
        .id(modeKey)
    }

    /// Listenin sonundaki görünmez tetik. Ekrana girdiği an sonraki sayfa
    /// yükleniyor; yüklenirken küçük bir çark dönüyor ki hiçbir şey olmuyormuş
    /// gibi durmasın.
    private var loadMoreSentinel: some View {
        HStack {
            Spacer()
            ProgressView()
                .tint(.white.opacity(0.6))
                .opacity(leaderboard.isLoading ? 1 : 0.35)
            Spacer()
        }
        .frame(height: 44)
        .onAppear {
            guard !leaderboard.isLoading else { return }
            visibleRows = min(visibleRows + LeaderboardService.pageSize,
                              LeaderboardService.maxRows)
            loadMore()
        }
    }

    /// Tablonun üstünde duran "sen buradasın" şeridi. Görünen pencerenin
    /// dışında olsan da sıranı söylüyor; dokununca oraya kadar yükleyip
    /// satırını parlatıyor.
    private func myRankBanner(_ rank: Int) -> some View {
        let myRank = Rank.of(value: myValue ?? 0, mode: mode)
        return Button {
            AudioEngine.shared.playTap()
            // Sıra görünen pencerenin dışındaysa oraya kadar yükle
            let needed = min(LeaderboardService.maxRows,
                             ((rank + LeaderboardService.pageSize - 1)
                              / LeaderboardService.pageSize) * LeaderboardService.pageSize)
            if needed > visibleRows {
                visibleRows = needed
                pendingJump = true
                loadMore()
            } else {
                jumpRequest += 1
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "scope")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(settings.theme.accent.color)

                VStack(alignment: .leading, spacing: 1) {
                    Text("You")
                        .font(.system(.subheadline, design: .rounded).bold())
                        .foregroundStyle(.white)
                    HStack(spacing: 5) {
                        RankBadge(rank: myRank, size: 9)
                        Text(myRank.title)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(myRank.color)
                    }
                }

                Spacer(minLength: 8)

                if pendingJump && leaderboard.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("#\(rank)")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(settings.theme.accent.color)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(settings.theme.accent.opacity(0.14))
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(settings.theme.accent.opacity(0.40), lineWidth: 1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
        }
        .buttonStyle(.plain)
    }

    /// Şeritte yazan sıra. Satırım yüklenmiş sayfaların içindeyse GÖZÜN
    /// gördüğü sırayı kullanır; şerit "198" derken satırın başka bir yerde
    /// duramaz. Sunucudan gelen sayım yalnızca satırım henüz yüklenmemiş
    /// pencerenin ötesindeyken devreye giriyor.
    private var myPlace: Int? {
        if let i = entries.firstIndex(where: \.isMe) { return i + 1 }
        return leaderboard.myRank(mode)
    }

    /// Kendi skorum — rozeti doğru renkte çizmek için
    private var myValue: Double? {
        entries.first(where: \.isMe)?.value ?? leaderboard.weeklyBest(mode)
    }

    /// Kendi satırıma kaydır ve kısa bir parlama bırak
    private func jump(with proxy: ScrollViewProxy) {
        guard let me = entries.first(where: \.isMe) else { return }
        pendingJump = false
        withAnimation(.easeInOut(duration: 0.45)) {
            proxy.scrollTo(rowID(me), anchor: .center)
        }
        withAnimation(.easeOut(duration: 0.2)) { flashID = rowID(me) }
        // Parlama kısa: dikkati çeksin, ekranda kalmasın
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeInOut(duration: 0.5)) { flashID = nil }
        }
    }

    /// Getirilen satır sayısı istenene eşitse arkada daha var demektir
    private var canLoadMore: Bool {
        entries.count >= visibleRows && visibleRows < LeaderboardService.maxRows
    }

    private func groupHeader(_ rank: Rank, count: Int) -> some View {
        HStack(spacing: 8) {
            RankBadge(rank: rank, size: 14)
            Text(rank.title)
                .font(.system(.subheadline, design: .rounded).bold())
                .foregroundStyle(rank.color)
            Text(rank.rangeText(mode: mode))
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
            Spacer()
            Text("\(count)")
                .font(.system(.caption2, design: .rounded).bold())
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(.horizontal, 4)
        .padding(.top, 14)
        .padding(.bottom, 2)
    }

    private func row(index: Int, entry: LeaderboardEntry, rank: Rank) -> some View {
        HStack(spacing: 14) {
            // Rütbenin rengi satırın kenarında ince bir şerit: başlığı
            // kaydırıp geçtiğinde de hangi kümede olduğun belli kalıyor
            Capsule()
                .fill(rank.color.opacity(entry.isMe ? 0.95 : 0.55))
                .frame(width: 3, height: 22)

            // Sıra üç haneye çıkabiliyor (500 satır). Sütun 30 puntoydu ve
            // "180" alt alta iki satıra sarıyordu. Punto artık sabit:
            // `minimumScaleFactor` küçülttüğünde SwiftUI yazıyı aynı taban
            // çizgisinde bırakıyor, küçülen rakamlar isme göre aşağı kaymış
            // görünüyordu. 17 punto monospace üç hanede 31 punto tutuyor,
            // 44'lük sütuna her zaman sığıyor — küçültmeye gerek kalmıyor.
            Text("\(index + 1)")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .foregroundStyle(rankColor(index))
                .frame(width: 44, alignment: .center)

            Text(entry.username)
                .font(.system(.body, design: .rounded).bold())
                .foregroundStyle(entry.isMe ? settings.theme.accent.color : .white)
                .lineLimit(1)
            if entry.isMe {
                Text("you")
                    .font(.system(.caption2, design: .rounded).bold())
                    .foregroundStyle(settings.theme.accent.color)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(settings.theme.accent.opacity(0.2)))
            }

            Spacer()

            Text(valueText(entry.value))
                .font(.system(.body, design: .rounded).bold())
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.leading, 10)
        .padding(.trailing, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(entry.isMe ? settings.theme.accent.opacity(0.12) : .white.opacity(0.05))
            // "Beni bul"dan sonraki kısa parlama. Beş yüz satırın ortasına
            // kaydırmak tek başına yetmiyor: ekran duruyor ama hangi satır
            // olduğu anlaşılmıyor.
            if flashID == rowID(entry) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(settings.theme.accent.opacity(0.30))
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(settings.theme.accent.color, lineWidth: 1.5)
                    .shadow(color: settings.theme.accent.opacity(0.9), radius: 8)
            }
        }
    }

    /// Rütbe cetveli: aşağıdan yukarıya bütün basamaklar. Tabloda yalnızca o
    /// an dolu olan rütbeler görünüyor; merdivenin tamamını görmeden bir
    /// üsttekine ne kadar kaldığı bilinmiyor.
    private var ladder: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ranks")
                .font(.system(.headline, design: .rounded).bold())
                .foregroundStyle(.white.opacity(0.9))

            ForEach(Rank.allCases.reversed()) { rank in
                HStack(spacing: 10) {
                    RankBadge(rank: rank, size: 13)
                    Text(rank.title)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(rank.color)
                    Spacer()
                    Text(rank.rangeText(mode: mode))
                        .font(.system(.caption, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.05))
        }
        .padding(.top, 24)
    }

    /// Bekleme ekranı. Çıplak bir çark her uygulamada aynı; burada oyunun
    /// kendi hareketi dönüyor — küre bir halkanın çevresinde. Altındaki yazı
    /// da her saniye değişiyor, böylece bekleme donmuş gibi durmuyor.
    private var loadingOrb: some View {
        VStack(spacing: 18) {
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let angle = t * 2.2                      // rad/sn
                let r: Double = 26
                ZStack {
                    Circle()
                        .strokeBorder(settings.theme.ring.opacity(0.45), lineWidth: 2)
                        .frame(width: r * 2, height: r * 2)
                    Circle()
                        .fill(settings.theme.orb.color)
                        .frame(width: 11, height: 11)
                        .shadow(color: settings.theme.accent.opacity(0.9), radius: 7)
                        .offset(x: cos(angle) * r, y: sin(angle) * r)
                }
                .frame(width: r * 2 + 14, height: r * 2 + 14)
            }

            // Üç satır sırayla: bekleme kısa sürerse ilkini bile görmeden geçer
            TimelineView(.periodic(from: .now, by: 1.3)) { timeline in
                let step = Int(timeline.date.timeIntervalSinceReferenceDate / 1.3)
                Text(Self.loadingLines[step % Self.loadingLines.count])
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .transition(.opacity)
                    .id(step % Self.loadingLines.count)
            }
            .animation(.easeInOut(duration: 0.3), value: UUID())
        }
    }

    private static let loadingLines: [LocalizedStringKey] = [
        "Lining up the rings…",
        "Waking the leaderboard…",
        "Counting everyone twice…"
    ]

    private var notConnected: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "globe.badge.chevron.backward")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.5))
            Text("Global ranking not connected")
                .font(.system(.headline, design: .rounded).bold())
                .foregroundStyle(.white)
            Text("Add Firebase to enable the world ranking (see README). Your local best is shown below.")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 4) {
                Text("Your best")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                Text(localBestText)
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(settings.theme.accent.color)

                // Tablo kapalıyken de rütbe görünür: rütbe internete değil
                // skora bağlı, öyleyse çevrimdışı oyuncudan saklanmasın
                if let rank = localRank {
                    HStack(spacing: 6) {
                        RankBadge(rank: rank, size: 13)
                        Text(rank.title)
                            .font(.system(.subheadline, design: .rounded).bold())
                            .foregroundStyle(rank.color)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.top, 10)
            Spacer()
            Spacer()
        }
    }

    /// Cihazdaki en iyi sonucun rütbesi (hiç oynanmadıysa yok)
    private var localRank: Rank? {
        if mode == .endless {
            guard progress.endlessBest > 0 else { return nil }
            return .of(value: Double(progress.endlessBest), mode: .endless)
        }
        guard progress.speedrunBest > 0 else { return nil }
        return .of(value: progress.speedrunBest, mode: .speedrun)
    }

    private var localBestText: String {
        if mode == .endless {
            return "\(progress.endlessBest)"
        } else {
            return progress.speedrunBest > 0 ? GameContainerView.formatTime(progress.speedrunBest) : "—"
        }
    }

    private func valueText(_ v: Double) -> String {
        mode == .endless ? "\(Int(v))" : GameContainerView.formatTime(v)
    }

    private func rankColor(_ index: Int) -> Color {
        switch index {
        case 0: return settings.theme.lumen.color
        case 1: return .white.opacity(0.85)
        case 2: return Color(red: 0.8, green: 0.5, blue: 0.3)
        default: return .white.opacity(0.5)
        }
    }

    /// Tabloyu getir. Buradan GENEL REKOR gönderilmez: tablo haftalık, gönderim
    /// de tur bitiminde yapılır. Eskiden her açılışta tüm zamanların rekoru
    /// gönderiliyordu ve hafta sıfırlanır sıfırlanmaz o rekor taze haftaya
    /// düşüyordu — oyuncu ne yaparsa yapsın tabloda hep eski rakamını görüyordu.
    /// Yalnızca BU HAFTA yapılmış ama yazılamamış bir sonuç varsa yeniden denenir.
    private func load() {
        guard leaderboard.isAvailable else { return }
        if player.hasUsername {
            leaderboard.resubmitWeeklyBest(mode: mode,
                                           username: player.username,
                                           playerID: player.playerID)
        }
        leaderboard.refresh(mode: mode, myPlayerID: player.playerID, limit: visibleRows)
    }

    /// Sonraki sayfa. `load()`'tan farkı: skor yeniden GÖNDERİLMEZ. Her sayfada
    /// aynı sonucu tekrar yazmak boşuna yazma işlemi.
    private func loadMore() {
        guard leaderboard.isAvailable else { return }
        leaderboard.refresh(mode: mode, myPlayerID: player.playerID, limit: visibleRows)
    }
}
