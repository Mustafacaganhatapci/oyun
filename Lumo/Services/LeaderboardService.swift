import Foundation
import SwiftUI
import os

/// Sıralama günlüğü.
///
/// `os_log`'un `.info` seviyesi Xcode'un hata ayıklama panelinde her zaman
/// gösterilmiyor; sorun ararken "log hiç düşmedi mi yoksa gizlendi mi"
/// belirsizliği başlı başına vakit kaybettiriyor. Hata ayıklama derlemesinde
/// ayrıca `print` ile yazılır, böylece panelde kesinlikle görünür.
func leaderboardLog(_ message: String, isError: Bool = false) {
    os_log(isError ? .error : .info, "%{public}@", message)
    #if DEBUG
    print("[Orbeon.Leaderboard] \(message)")
    #endif
}

enum LeaderboardMode {
    case endless    // yüksek skor kazanır
    case speedrun   // düşük süre kazanır

    fileprivate var base: String {
        switch self {
        case .endless: return "leaderboard_endless"
        case .speedrun: return "leaderboard_speedrun"
        }
    }

    /// Her hafta kendi koleksiyonuna yazılır. Tek koleksiyonda `week` alanıyla
    /// süzmek Firestore'da bileşik dizin ister; ayrı koleksiyon yalnızca
    /// `value` sıralaması kullandığı için ek kurulum gerektirmez ve geçmiş
    /// haftalar silinmeden kendiliğinden arşivlenmiş olur.
    func collection(week: Int) -> String { "\(base)_w\(week)" }
}

struct LeaderboardEntry: Identifiable {
    let id: String          // playerID
    let username: String
    let value: Double       // endless: skor, speedrun: saniye
    var isMe: Bool = false
}

/// Dünya sıralaması. Firebase (Firestore + Auth) varsa gerçek küresel tablo,
/// yoksa "bağlı değil" durumunda yerel en iyi skoru gösterir.
///
/// Firebase'i etkinleştirmek için (README'de ayrıntı):
///  1. Xcode > Add Package: https://github.com/firebase/firebase-ios-sdk
///     (FirebaseFirestore ve FirebaseAuth ürünlerini ekle)
///  2. Firebase konsolundan GoogleService-Info.plist indir, projeye sürükle
///  3. Firestore'u "test mode" veya uygun kurallarla aç
/// SDK ya da plist yoksa uygulama çökmeden yerel modda çalışır.
@MainActor
final class LeaderboardService: ObservableObject {
    @Published private(set) var isAvailable = false      // SDK + plist mevcut mu
    @Published private(set) var isLoading = false
    @Published private(set) var endlessEntries: [LeaderboardEntry] = []
    @Published private(set) var speedrunEntries: [LeaderboardEntry] = []
    /// Bu haftaki kendi sıram — tabloda görünen pencerenin DIŞINDA olsam da.
    /// 500 kişilik bir tabloda 327. olan kendini asla göremiyordu.
    @Published private(set) var endlessMyRank: Int?
    @Published private(set) var speedrunMyRank: Int?

    private var didConfigure = false

    // MARK: Haftalık dönem
    //
    // Hafta numarası, sabit bir Pazartesiden (1 Ocak 2024 00:00 UTC) geçen tam
    // hafta sayısıdır. Takvim/ISO hafta hesabı yerine bu kullanılıyor çünkü iki
    // platformda da tek satırlık aritmetikle birebir aynı sonucu veriyor ve
    // sıralama herkes için aynı anda, Pazartesi 00:00 UTC'de sıfırlanıyor.
    private static let weekAnchor: TimeInterval = 1_704_067_200   // 2024-01-01, Pazartesi, UTC
    private static let weekLength: TimeInterval = 7 * 24 * 60 * 60

    static func weekIndex(at date: Date = Date()) -> Int {
        Int(floor((date.timeIntervalSince1970 - weekAnchor) / weekLength))
    }

    /// Bu haftanın numarası — okuma ve yazma bunun üzerinden yapılır
    var currentWeek: Int { Self.weekIndex() }

    /// Bu haftanın başlangıç anı (Unix saniye)
    var weekStart: TimeInterval { Self.weekAnchor + Double(currentWeek) * Self.weekLength }
    static var weekSpan: TimeInterval { weekLength }

    /// Firestore'dan okunan doldurma ayarları (bir kez, uygulama ömrü boyunca)
    private var seedConfig: LeaderboardSeed.Config?

    /// Sıralamanın sıfırlanmasına kalan süre
    var timeUntilReset: TimeInterval {
        let nextStart = Self.weekAnchor + Double(currentWeek + 1) * Self.weekLength
        return max(0, nextStart - Date().timeIntervalSince1970)
    }

    /// Kalan süre: "3 g 14 s" gibi yalnızca iki birim. Birim harfleri dile
    /// göre değişiyor — sabit "d/h" İngilizce dışında hiçbir dilde okunmuyordu.
    var resetCountdownText: String {
        let total = Int(timeUntilReset)
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let d = String(localized: "unit.day.short")
        let h = String(localized: "unit.hour.short")
        if days > 0 { return "\(days) \(d) \(hours) \(h)" }
        let minutes = (total % 3_600) / 60
        return "\(hours) \(h) \(minutes) \(String(localized: "unit.minute.short"))"
    }

    /// Uygulama başlangıcında (LumoApp.init) çağrılır — Firebase'in
    /// istediği gibi ilk kare çizilmeden önce yapılandırır.
    static func bootstrapFirebase() {
        #if canImport(FirebaseCore)
        // GoogleService-Info.plist yoksa Firebase'i başlatma (çökmeyi önler)
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else { return }
        FirebaseBridge.configure()
        #endif
    }

    func configureIfPossible() {
        guard !didConfigure else { return }
        didConfigure = true
        #if canImport(FirebaseCore)
        isAvailable = FirebaseBridge.isConfigured
        #else
        isAvailable = false
        #endif
    }

    /// Ad sahiplenme sonucu
    enum NameClaim { case claimed, taken, offline }

    /// Adı küresel olarak sahiplenmeye çalışır. Aynı ad başkasındaysa `.taken`
    /// döner. Firebase yoksa `.offline` — o durumda sıralama da kapalı olduğu
    /// için ad yalnızca cihazda anlam taşır.
    func claimUsername(_ name: String, playerID: String) async -> NameClaim {
        guard isAvailable else { return .offline }
        #if canImport(FirebaseCore)
        switch await FirebaseBridge.claimUsername(name, playerID: playerID) {
        case .some(true): return .claimed
        case .some(false): return .taken
        case .none: return .offline     // ağ/izin hatası: adı yerelde kabul et
        }
        #else
        return .offline
        #endif
    }

    /// Oyuncunun BU TURDA yaptığı sonucu küresel tabloya yazar
    func submit(mode: LeaderboardMode, value: Double, username: String, playerID: String) {
        // Sonsuz modda 0, "oynadım" değil "ilk halkadan atlayamadım" demek.
        // Tabloyu sıfırlarla doldurmanın kimseye faydası yok; hız turunda ise
        // düşük değer İYİ olduğu için aynı eşik uygulanamaz.
        guard !(mode == .endless && value < 1) else {
            leaderboardLog("GÖNDERİLMEDİ: sonsuz modda 0 skor tabloya yazılmaz")
            return
        }
        // Firebase'e gitmese bile (çevrimdışı, ad henüz girilmemiş) bu haftanın
        // sonucunu yerelde tut — sıralama ekranı açıldığında yeniden denenir.
        rememberWeekly(mode, value)

        // Sessizce çıkmak, "yazma denendi ama reddedildi" ile "yazma hiç
        // denenmedi" durumlarını ayırt edilemez kılıyordu.
        guard isAvailable else {
            leaderboardLog("GÖNDERİLMEDİ: Firebase bağlı değil (isAvailable=false)", isError: true)
            return
        }
        guard !username.isEmpty else {
            leaderboardLog("GÖNDERİLMEDİ: kullanıcı adı boş — skor \(value) yazılmadı", isError: true)
            return
        }
        #if canImport(FirebaseCore)
        let week = currentWeek
        Task {
            await FirebaseBridge.submit(mode: mode, week: week, value: value,
                                        username: username, playerID: playerID)
        }
        #endif
    }

    // MARK: Bu haftanın kendi sonucu
    //
    // Haftalık tabloya YALNIZCA bu hafta yapılan sonuç yazılır. Eskiden sıralama
    // ekranı her açılışında oyuncunun TÜM ZAMANLARIN rekorunu gönderiyordu:
    // hafta sıfırlandığı anda o rekor taze haftaya düşüyor ve oyuncu o hafta ne
    // yaparsa yapsın tabloda hep eski rakamı görüyordu — üstelik onu geçmeden
    // hiçbir yeni skoru da yazılamıyordu.
    //
    // Anahtar hafta numarasını içerdiği için yeni hafta kendiliğinden boş başlar;
    // eski haftaların değerleri okunmaz.
    private func weeklyKey(_ mode: LeaderboardMode) -> String {
        "lumo.weeklyBest.\(mode.base).w\(currentWeek)"
    }

    /// Bu hafta yapılmış en iyi sonuç — hiç oynanmadıysa nil
    func weeklyBest(_ mode: LeaderboardMode) -> Double? {
        let key = weeklyKey(mode)
        guard UserDefaults.standard.object(forKey: key) != nil else { return nil }
        return UserDefaults.standard.double(forKey: key)
    }

    private func rememberWeekly(_ mode: LeaderboardMode, _ value: Double) {
        if let existing = weeklyBest(mode) {
            let better = mode == .endless ? value > existing : value < existing
            guard better else { return }
        }
        UserDefaults.standard.set(value, forKey: weeklyKey(mode))
    }

    /// Sıralama ekranı açılınca çağrılır: bu haftaki sonuç bir sebeple
    /// (çevrimdışıydı, ad sonradan girildi) yazılamadıysa yeniden dener.
    /// Genel rekor ASLA gönderilmez.
    func resubmitWeeklyBest(mode: LeaderboardMode, username: String, playerID: String) {
        guard let best = weeklyBest(mode) else { return }
        submit(mode: mode, value: best, username: username, playerID: playerID)
    }

    /// Şampiyonluk ödülü: sıraya göre yıldız. Şampiyon küresi üçüne de verilir.
    static func championStars(forRank rank: Int) -> Int {
        switch rank {
        case 1: return 250
        case 2: return 150
        default: return 100
        }
    }

    /// GEÇEN haftanın ilk üçünde miyim? Değilsem nil döner.
    /// Ödülü vermek çağıranın işi — burada yalnızca sıra okunur.
    ///
    /// Okumadan ÖNCE geçen haftanın doldurmaları siliniyor. Yalnızca temizlik
    /// için değil, doğruluk için: nüfus 500'e çıkınca ilk 50'yi baştan sona
    /// doldurmalar kaplıyor, gerçek oyuncular o pencereye hiç giremiyor ve
    /// şampiyon kimse çıkmıyordu. Silindikten sonra ilk 50 zaten yalnızca
    /// gerçek insanlardan oluşuyor.
    func previousWeekRank(playerID: String) async -> (week: Int, rank: Int)? {
        guard isAvailable else { return nil }
        let week = currentWeek - 1
        guard week >= 0 else { return nil }
        #if canImport(FirebaseCore)
        await prune(mode: .endless, week: week, keeping: nil)

        // Kalmış olabilecekler yine de ELENİR: ödül sıralaması yalnızca gerçek
        // oyunculardan hesaplanır, kimse sahte bir adın arkasında kalıp
        // yıldızını kaybetmez.
        let top = await FirebaseBridge.fetchTop(mode: .endless, week: week,
                                                myPlayerID: playerID, limit: 50)
            .filter { !LeaderboardSeed.isSeed($0.id) }
        guard let index = top.prefix(3).firstIndex(where: { $0.id == playerID }) else { return nil }
        return (week, index + 1)
        #else
        return nil
        #endif
    }

    /// Kendi sıramı sunucudan sorar. Bütün tabloyu indirmeye gerek yok:
    /// benden İYİ olanların SAYISI + 1. Tek sayım okuması, beş yüz satır değil.
    private func refreshMyRank(mode: LeaderboardMode, week: Int, playerID: String) async {
        #if canImport(FirebaseCore)
        let rank = await FirebaseBridge.myRank(mode: mode, week: week, playerID: playerID)
        switch mode {
        case .endless: endlessMyRank = rank
        case .speedrun: speedrunMyRank = rank
        }
        #endif
    }

    func myRank(_ mode: LeaderboardMode) -> Int? {
        mode == .endless ? endlessMyRank : speedrunMyRank
    }

    /// Tablonun ilk sayfası kaç satır — "daha fazla göster" bunun katlarıyla
    /// büyür. Elli satır haftanın nüfusunun onda biriydi: tablo hep aynı
    /// yerde bitiyor, arkadaki kalabalık hiç görünmüyordu.
    nonisolated static let pageSize = 100
    /// Görünebilecek azami satır. Bir haftanın nüfusundan büyük olmasının
    /// zararı yok; okuma sayısını sınırlamak için var.
    nonisolated static let maxRows = 500

    /// Bu haftanın ilk `limit` sonucunu getirir. Tablo yarım kalmışsa, zamanı
    /// gelmiş doldurmaları yazıp yeniden okur.
    func refresh(mode: LeaderboardMode, myPlayerID: String, limit: Int = pageSize) {
        guard isAvailable else { return }
        #if canImport(FirebaseCore)
        isLoading = true
        let week = currentWeek
        let start = weekStart
        let rows = max(1, min(limit, Self.maxRows))
        Task {
            // Eski kuşak varsa ÖNCE gitsin: sayaç onları da sayıyor
            await self.pruneStaleGeneration(mode: mode, week: week)

            var entries = await FirebaseBridge.fetchTop(mode: mode, week: week,
                                                        myPlayerID: myPlayerID, limit: rows)

            if let added = await seedIfNeeded(mode: mode, week: week, start: start,
                                              existing: entries), added > 0 {
                entries = await FirebaseBridge.fetchTop(mode: mode, week: week,
                                                        myPlayerID: myPlayerID, limit: rows)
            }

            // Gelen ne varsa gösterilir. Eskiden doldurmalar ilk 50'ye
            // sığmadıklarında gizleniyordu: dün tabloda duran bir ad bugün
            // yok oluyordu ve bu, tabloyu güvenilmez yapıyordu. Artık bir
            // satır bir kez göründüyse hafta boyunca yerinde kalıyor.
            let shown = entries
            await MainActor.run {
                switch mode {
                case .endless: self.endlessEntries = shown
                case .speedrun: self.speedrunEntries = shown
                }
                self.isLoading = false
            }

            await self.refreshMyRank(mode: mode, week: week, playerID: myPlayerID)

            // Temizlik tablo çizildikten SONRA: eski haftaların silinmesi
            // oyuncuyu bekletmemeli, kimse onu görmüyor bile.
            await self.pruneSeeds(mode: mode, week: week)
        }
        #endif
    }

    /// Eksik doldurmaları yazar, kaç tane yazdığını döner.
    ///
    /// Belge kimlikleri hafta ve sıradan türetildiği için aynı doldurmayı iki
    /// cihaz yazsa bile tabloda tek satır olur. Bir seferde en çok 50 tane
    /// yazılır: ilk sayfa (100 satır) iki açılışta doluyor, beş yüzün tamamı
    /// da on açılışta. Tek seferde hepsini yazmak bir oyuncuyu başkalarının
    /// tablosunu doldurmak için bekletmek olurdu.
    ///
    /// Nüfus artık ilk 50'den çok daha büyük olduğu için hangi doldurmanın
    /// yazıldığı ilk 50'ye bakılarak anlaşılamıyor. İki koruma var:
    ///  • Cihaz kendi yazdıklarını hatırlıyor (hafta bazlı, hafta değişince
    ///    kendiliğinden geçersiz).
    ///  • Yazmadan önce koleksiyondaki belge SAYISI soruluyor; başka bir cihaz
    ///    çoktan doldurmuşsa hiç yazılmıyor. Tek bir sayım okuması, beş yüz
    ///    gereksiz yazmadan ucuz.
    private func seedIfNeeded(mode: LeaderboardMode, week: Int, start: TimeInterval,
                              existing: [LeaderboardEntry]) async -> Int? {
        #if canImport(FirebaseCore)
        let config = await loadSeedConfig()
        guard config.enabled, config.population > 0 else { return 0 }

        let due = LeaderboardSeed.due(week: week, mode: mode, config: config,
                                      weekStart: start, weekLength: Self.weekSpan)
        guard !due.isEmpty else { return 0 }

        // Koleksiyon zaten bu haftanın kotasını doldurmuşsa dokunma
        if let present = await FirebaseBridge.documentCount(mode: mode, week: week),
           present >= due.count { return 0 }

        let key = "lumo.seedWritten.\(mode.base).w\(week)"
        var mine = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
        let known = Set(existing.map(\.id)).union(mine)

        let batch = due.filter { !known.contains($0.id) }.prefix(50)
        guard !batch.isEmpty else { return 0 }

        let written = await FirebaseBridge.writeSeeds(Array(batch), mode: mode, week: week)
        guard written > 0 else { return 0 }

        mine.formUnion(batch.map(\.id))
        UserDefaults.standard.set(Array(mine), forKey: key)
        Self.forgetOldSeedKeys(before: week)
        return written
        #else
        return 0
        #endif
    }

    /// Geçmiş haftaların doldurma kayıtları UserDefaults'ta birikmesin: beş yüz
    /// kimlik haftada bir eklenirse dosya şişer. Hem "ben şunları yazdım"
    /// listeleri hem de "bu hafta temizlendi" işaretleri süpürülüyor.
    private static func forgetOldSeedKeys(before week: Int) {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys
        where key.hasPrefix("lumo.seedWritten.") || key.hasPrefix("lumo.seedPruned.") {
            guard let range = key.range(of: ".w", options: .backwards) else { continue }
            // ".w123" ya da ".w123.gen" — hafta numarası noktaya kadar
            let tail = key[range.upperBound...]
            let digits = tail.prefix { $0.isNumber }
            guard let keyWeek = Int(digits) else { continue }
            // Yazma listesi hafta bitince işe yaramaz; temizlik işaretleri ise
            // temizlenen haftalar kadar (dört hafta) saklanır.
            let keepUntil = key.hasPrefix("lumo.seedWritten.") ? week : week - 4
            if keyWeek < keepUntil { defaults.removeObject(forKey: key) }
        }
    }

    /// Bir oturumda aynı temizliği tekrar tekrar denememek için
    private var prunedThisSession = Set<String>()

    /// İşi biten doldurmaları siler.
    ///
    /// İki şey temizleniyor:
    ///  • Geçen hafta ve daha eskisinin TÜM doldurmaları. Gerçek oyuncuların
    ///    satırlarına dokunulmuyor — onların geçmişi kalıyor.
    ///  • Bu haftanın eski kuşaktan kalmış doldurmaları; ad üretimi değişince
    ///    iki farklı üretim yan yana durmasın.
    ///
    /// Silme bir seferde 150 belge, boşalana kadar en çok beş geçiş. Bir geçiş
    /// hiçbir şey silmezse o hafta "temiz" işaretlenir ve bir daha
    /// sorgulanmaz — yoksa boş bir koleksiyonu her açılışta taramak,
    /// silinecek hiçbir şey yokken bile okuma harcardı.
    private func pruneSeeds(mode: LeaderboardMode, week: Int) async {
        #if canImport(FirebaseCore)
        // GEÇEN hafta dahil. Eskiden bir hafta bekletiliyordu çünkü şampiyon
        // ödülü o tablodan okunuyor; ama ödül zaten doldurmaları saymıyor ve
        // okuma öncesi kendi temizliğini yapıyor. Bekletmenin tek sonucu,
        // konsolda işi bitmiş bin kaydın durması olurdu.
        for old in (week - 4)...(week - 1) where old >= 0 {
            await prune(mode: mode, week: old, keeping: nil)
        }
        #endif
    }

    /// Bu haftanın eski kuşaktan kalmış doldurmaları. YAZMADAN ÖNCE çağrılır:
    /// sayaç eski kuşağı da saydığı için önce temizlenmezse "koleksiyon zaten
    /// dolu" denip yeni kuşak hiç yazılmıyor, tablo birkaç açılış boyunca eski
    /// üretimde takılı kalıyordu.
    private func pruneStaleGeneration(mode: LeaderboardMode, week: Int) async {
        #if canImport(FirebaseCore)
        await prune(mode: mode, week: week, keeping: LeaderboardSeed.prefix(week: week))
        #endif
    }

    private func prune(mode: LeaderboardMode, week: Int, keeping prefix: String?) async {
        #if canImport(FirebaseCore)
        // Kuşak numarası anahtarın içinde: üretim değişip kuşak artınca eski
        // "temizlendi" işareti kendiliğinden geçersiz oluyor, yoksa bir kez
        // temiz denmiş hafta yeni kuşakta bir daha hiç taranmazdı.
        let key = prefix == nil
            ? "lumo.seedPruned.\(mode.base).w\(week).all"
            : "lumo.seedPruned.\(mode.base).w\(week).gen\(LeaderboardSeed.generation)"
        guard !prunedThisSession.contains(key),
              !UserDefaults.standard.bool(forKey: key) else { return }
        prunedThisSession.insert(key)

        // Beş yüz kaydı yüz ellişer silmek dört geçiş eder. Tek geçişle
        // bırakılsa temizlik açılışlara yayılır ve arada eksik bir tablo
        // gösterilirdi.
        for _ in 0..<5 {
            let removed = await FirebaseBridge.deleteSeeds(mode: mode, week: week, keeping: prefix)
            if removed == 0 {
                UserDefaults.standard.set(true, forKey: key)
                return
            }
        }
        #endif
    }

    private func loadSeedConfig() async -> LeaderboardSeed.Config {
        if let seedConfig { return seedConfig }
        #if canImport(FirebaseCore)
        let loaded = await FirebaseBridge.fetchSeedConfig()
        seedConfig = loaded
        return loaded
        #else
        return .default
        #endif
    }
}

// MARK: - Firebase köprüsü
// Tüm Firebase API çağrıları burada izole edilir. SDK yoksa bu bölüm hiç derlenmez.
#if canImport(FirebaseCore)
import FirebaseCore
#if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
import FirebaseFirestore
import FirebaseAuth

enum FirebaseBridge {
    static var isConfigured: Bool { FirebaseApp.app() != nil }

    static func configure() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        // Anonim giriş (yazma yetkisi için); sessizce dener
        if Auth.auth().currentUser == nil {
            Auth.auth().signInAnonymously { _, _ in }
        }
    }

    /// Adı `usernames` koleksiyonunda sahiplenir. Belge kimliği adın küçük
    /// harfli hâli olduğu için "Ali" ve "ali" aynı ad sayılır.
    ///
    /// İşlem (transaction) içinde yapılır: iki oyuncu aynı anda aynı adı
    /// isterse yalnızca biri alır. Okuyup sonra yazmak bu yarışı açık bırakırdı.
    ///
    /// true = alındı, false = başkasında, nil = hata (çağıran yerelde kabul eder)
    static func claimUsername(_ name: String, playerID: String) async -> Bool? {
        let db = Firestore.firestore()
        let doc = db.collection("usernames").document(name.lowercased())
        do {
            let result = try await db.runTransaction { transaction, errorPointer -> Any? in
                do {
                    let snapshot = try transaction.getDocument(doc)
                    if snapshot.exists,
                       let owner = snapshot.data()?["playerID"] as? String,
                       owner != playerID {
                        return false
                    }
                    transaction.setData([
                        "playerID": playerID,
                        "username": name,
                        "claimedAt": FieldValue.serverTimestamp()
                    ], forDocument: doc)
                    return true
                } catch let error as NSError {
                    errorPointer?.pointee = error
                    return nil
                }
            }
            return result as? Bool
        } catch {
            leaderboardLog("AD SAHİPLENİLEMEDİ usernames/\(name.lowercased()): \(error.localizedDescription)",
                           isError: true)
            return nil
        }
    }

    /// Oyuncunun ayarlardan yazdığı görüş/öneri.
    ///
    /// Belge kimliği rastgele; aynı kişi birden çok kez yazabilsin diye
    /// playerID kullanılmıyor. Kurallar okumayı istemciye kapatır.
    static func sendFeedback(message: String, playerID: String, username: String,
                             version: String) async -> Bool {
        let db = Firestore.firestore()
        var data: [String: Any] = [
            "message": message,
            "playerID": playerID,
            "platform": "iOS",
            "version": version,
            "sentAt": FieldValue.serverTimestamp()
        ]
        if !username.isEmpty { data["username"] = username }
        do {
            _ = try await db.collection("feedback").addDocument(data: data)
            leaderboardLog("GÖRÜŞ GÖNDERİLDİ (\(message.count) karakter)")
            return true
        } catch {
            leaderboardLog("GÖRÜŞ GÖNDERİLEMEDİ: \(error.localizedDescription)", isError: true)
            return false
        }
    }

    /// Destekçi kaydı: kim, hangi adla, ne aldı.
    ///
    /// Amacı muhasebe değil — sonradan o kişilere hediye premium ya da kod
    /// gönderebilmek. Belge kimliği playerID; ürünler diziye eklenir, aynı
    /// kişi ikinci kez alırsa satır çoğalmaz.
    static func recordSupporter(playerID: String, username: String,
                                productID: String, price: String) async {
        let db = Firestore.firestore()
        let doc = db.collection("supporters").document(playerID)
        var data: [String: Any] = [
            "products": FieldValue.arrayUnion([productID]),
            "lastPurchaseAt": FieldValue.serverTimestamp(),
            "purchaseCount": FieldValue.increment(Int64(1))
        ]
        if !username.isEmpty { data["username"] = username }
        if !price.isEmpty { data["lastPrice"] = price }
        do {
            try await doc.setData(data, merge: true)
            leaderboardLog("DESTEKÇİ KAYDEDİLDİ supporters/\(playerID) ← \(productID)")
        } catch {
            leaderboardLog("DESTEKÇİ YAZILAMADI supporters/\(playerID): \(error.localizedDescription)",
                           isError: true)
        }
    }

    /// Firestore'daki `promoCodes` koleksiyonundan bir kodu kullanır.
    ///
    /// Belge kimliği kodun küçük harfli hâli. Alanlar:
    ///   active   (bool)   — false ise kod kapalı
    ///   maxUses  (int)    — 0 ya da yok: sınırsız
    ///   uses     (int)    — kaç kez kullanıldı (biz artırırız)
    ///   note     (string) — kimin için verildiği, yalnızca senin için
    ///
    /// İşlem (transaction) içinde okunup artırılır: aynı anda iki kişi son
    /// hakkı kullanamaz. Aynı oyuncu kodu tekrar girerse hak harcanmaz —
    /// telefon değiştiren biri kodunu yeniden kullanabilsin diye.
    ///
    /// true = kabul, false = geçersiz/bitmiş, nil = ağ hatası (çağıran yerel
    /// listeye düşer)
    static func redeemPromoCode(_ code: String, playerID: String) async -> Bool? {
        let db = Firestore.firestore()
        let doc = db.collection("promoCodes").document(code)
        do {
            let result = try await db.runTransaction { transaction, errorPointer -> Any? in
                do {
                    let snapshot = try transaction.getDocument(doc)
                    guard snapshot.exists, let data = snapshot.data() else { return false }
                    if let active = data["active"] as? Bool, !active { return false }

                    // Bu oyuncu daha önce kullandıysa hak düşmez
                    var redeemers = data["redeemedBy"] as? [String] ?? []
                    if redeemers.contains(playerID) { return true }

                    let uses = data["uses"] as? Int ?? 0
                    let maxUses = data["maxUses"] as? Int ?? 0
                    if maxUses > 0, uses >= maxUses { return false }

                    // Liste sınırsız büyümesin: son 50 kullanan tutulur
                    redeemers.append(playerID)
                    if redeemers.count > 50 { redeemers.removeFirst(redeemers.count - 50) }

                    transaction.updateData([
                        "uses": uses + 1,
                        "redeemedBy": redeemers,
                        "lastRedeemedAt": FieldValue.serverTimestamp()
                    ], forDocument: doc)
                    return true
                } catch let error as NSError {
                    errorPointer?.pointee = error
                    return nil
                }
            }
            return result as? Bool
        } catch {
            leaderboardLog("KOD OKUNAMADI promoCodes/\(code): \(error.localizedDescription)",
                           isError: true)
            return nil
        }
    }

    static func submit(mode: LeaderboardMode, week: Int, value: Double,
                       username: String, playerID: String) async {
        let db = Firestore.firestore()
        let doc = db.collection(mode.collection(week: week)).document(playerID)
        do {
            // Sadece daha iyi sonucu yaz
            let snapshot = try? await doc.getDocument()
            if let existing = snapshot?.data()?["value"] as? Double {
                let better = mode == .endless ? value > existing : value < existing
                if !better { return }
            }
            try await doc.setData([
                "username": username,
                "value": value,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
            leaderboardLog("YAZILDI \(mode.collection(week: week)) ← \(username) = \(value)")
        } catch {
            // Sessizce yutmak, izin kuralları yazmayı engellediğinde tabloyu
            // "boş" gösteriyor ve hiçbir iz bırakmıyordu. Console.app'te
            // "Orbeon" süzülerek gerçek sebep görülebilsin.
            leaderboardLog("YAZILAMADI \(mode.collection(week: week)): \(error.localizedDescription)",
                           isError: true)
        }
    }

    /// `config/leaderboard` — doldurma ayarları. Belge yoksa koddaki
    /// varsayılanlar kullanılır; yani Firestore'a hiç dokunmadan da çalışır.
    static func fetchSeedConfig() async -> LeaderboardSeed.Config {
        var config = LeaderboardSeed.Config.default
        let db = Firestore.firestore()
        guard let snap = try? await db.collection("config").document("leaderboard").getDocument(),
              let data = snap.data() else { return config }
        if let v = data["botsEnabled"] as? Bool { config.enabled = v }
        if let v = data["botTarget"] as? Int { config.target = max(0, min(50, v)) }
        // Haftalık toplam nüfus. Üst sınır bilerek var: konsolda yanlışlıkla
        // yazılan bir sıfır fazlası on binlerce belge yazmasın.
        if let v = data["botPopulation"] as? Int { config.population = max(0, min(2_000, v)) }
        if let v = data["botEndlessBest"] as? Int { config.endlessBest = v }
        if let v = data["botEndlessWorst"] as? Int { config.endlessWorst = v }
        if let v = data["botSpeedrunBest"] as? Double { config.speedrunBest = v }
        if let v = data["botSpeedrunWorst"] as? Double { config.speedrunWorst = v }
        if config.endlessBest < config.endlessWorst {
            swap(&config.endlessBest, &config.endlessWorst)
        }
        return config
    }

    /// Oyuncunun bu haftaki sırası. Önce kendi satırını okur, sonra kendisinden
    /// iyi olanları SAYAR — sıralamayı baştan sona indirmenin ucuz karşılığı.
    /// Hiç skor göndermemişse nil.
    static func myRank(mode: LeaderboardMode, week: Int, playerID: String) async -> Int? {
        let db = Firestore.firestore()
        let collection = db.collection(mode.collection(week: week))
        guard let doc = try? await collection.document(playerID).getDocument(),
              let value = doc.data()?["value"] as? Double else { return nil }
        // Sonsuz modda 0 skor tabloya girmiyor; sırası da yok
        if mode == .endless, value < 1 { return nil }

        let better = mode == .endless
            ? collection.whereField("value", isGreaterThan: value)
            : collection.whereField("value", isLessThan: value)
        guard let snap = try? await better.count.getAggregation(source: .server) else { return nil }
        return snap.count.intValue + 1
    }

    /// `config/announcement` — ana menüdeki duyuru kartı. Belge yoksa nil.
    static func fetchAnnouncement() async -> [String: Any]? {
        let db = Firestore.firestore()
        guard let snap = try? await db.collection("config").document("announcement").getDocument()
        else { return nil }
        return snap.data()
    }

    /// Doldurmaları yazar. `merge: false` DEĞİL — var olanın üstüne yazmayız;
    /// belge zaten varsa dokunulmaz, çünkü yalnızca eksik olanlar gönderilir.
    static func writeSeeds(_ seeds: [(id: String, name: String, value: Double)],
                           mode: LeaderboardMode, week: Int) async -> Int {
        let db = Firestore.firestore()
        let collection = db.collection(mode.collection(week: week))
        var written = 0
        for seed in seeds {
            do {
                try await collection.document(seed.id).setData([
                    "username": seed.name,
                    "value": seed.value,
                    "seed": true,
                    "updatedAt": FieldValue.serverTimestamp()
                ])
                written += 1
            } catch {
                leaderboardLog("DOLDURMA YAZILAMADI \(seed.id): \(error.localizedDescription)",
                               isError: true)
            }
        }
        if written > 0 { leaderboardLog("DOLDURMA \(written) kayıt → \(mode.collection(week: week))") }
        return written
    }

    /// Koleksiyondaki belge sayısı. Sunucu tarafı sayım: beş yüz belgeyi
    /// indirmeden "doldu mu" sorusunu cevaplıyor. Sayım başarısızsa `nil`
    /// döner ve çağıran yazmaya devam eder — doldurma yapmamaktansa
    /// gereksiz yazmak yeğ.
    static func documentCount(mode: LeaderboardMode, week: Int) async -> Int? {
        let db = Firestore.firestore()
        do {
            let snap = try await db.collection(mode.collection(week: week))
                .count.getAggregation(source: .server)
            return snap.count.intValue
        } catch {
            return nil
        }
    }

    /// Doldurmaları siler. `keeping` verilirse yalnızca o önekle BAŞLAMAYAN
    /// doldurmalar silinir (eski kuşak temizliği); `nil` ise haftanın bütün
    /// doldurmaları gider. Gerçek oyuncuların satırlarına hiçbir koşulda
    /// dokunulmaz — sorgu `seed == true` ile süzülüyor, kimlikler de ayrıca
    /// denetleniyor.
    @discardableResult
    static func deleteSeeds(mode: LeaderboardMode, week: Int,
                            keeping prefix: String?, limit: Int = 150) async -> Int {
        let db = Firestore.firestore()
        let collection = db.collection(mode.collection(week: week))
        do {
            let snap = try await collection
                .whereField("seed", isEqualTo: true)
                .limit(to: limit)
                .getDocuments()
            let doomed = snap.documents.filter { doc in
                guard LeaderboardSeed.isSeed(doc.documentID) else { return false }
                guard let prefix else { return true }
                return !doc.documentID.hasPrefix(prefix)
            }
            guard !doomed.isEmpty else { return 0 }

            let batch = db.batch()
            for doc in doomed { batch.deleteDocument(doc.reference) }
            try await batch.commit()
            leaderboardLog("DOLDURMA SİLİNDİ \(doomed.count) kayıt ← \(mode.collection(week: week))")
            return doomed.count
        } catch {
            leaderboardLog("DOLDURMA SİLİNEMEDİ \(mode.collection(week: week)): \(error.localizedDescription)",
                           isError: true)
            return 0
        }
    }

    static func fetchTop(mode: LeaderboardMode, week: Int, myPlayerID: String,
                         limit: Int = 100) async -> [LeaderboardEntry] {
        let db = Firestore.firestore()
        let descending = (mode == .endless)   // endless: yüksek üstte, speedrun: düşük üstte
        do {
            let query = db.collection(mode.collection(week: week))
                .order(by: "value", descending: descending)
                .limit(to: limit)
            let snap = try await query.getDocuments()
            leaderboardLog("OKUNDU \(mode.collection(week: week)) → \(snap.documents.count) kayıt")
            return snap.documents.compactMap { doc in
                guard let username = doc.data()["username"] as? String,
                      let value = doc.data()["value"] as? Double else { return nil }
                // Eskiden yazılmış 0 skorlar tabloda duruyor; okurken de
                // eleniyorlar ki kimse sıfırla sıralamada yer tutmasın
                if mode == .endless, value < 1 { return nil }
                return LeaderboardEntry(id: doc.documentID, username: username,
                                        value: value, isMe: doc.documentID == myPlayerID)
            }
        } catch {
            leaderboardLog("OKUNAMADI \(mode.collection(week: week)): \(error.localizedDescription)",
                           isError: true)
            return []
        }
    }
}
#else
// FirebaseCore var ama Firestore/Auth eklenmemiş: yine de uygulamayı yapılandır
// (I-COR000003 uyarısı kalkar), ancak sıralama yazma/okuma yapılamaz —
// isAvailable false kalır, oyun yerel en iyi skoru gösterir.
enum FirebaseBridge {
    static var isConfigured: Bool { false }   // Firestore/Auth yoksa sıralama kapalı
    static func configure() {
        if FirebaseApp.app() == nil { FirebaseApp.configure() }
    }
    static func claimUsername(_ name: String, playerID: String) async -> Bool? { nil }
    static func redeemPromoCode(_ code: String, playerID: String) async -> Bool? { nil }
    static func recordSupporter(playerID: String, username: String,
                                productID: String, price: String) async {}
    static func sendFeedback(message: String, playerID: String, username: String,
                             version: String) async -> Bool { false }
    static func submit(mode: LeaderboardMode, week: Int, value: Double,
                       username: String, playerID: String) async {}
    static func fetchTop(mode: LeaderboardMode, week: Int, myPlayerID: String,
                         limit: Int = 100) async -> [LeaderboardEntry] { [] }
    static func fetchSeedConfig() async -> LeaderboardSeed.Config { .default }
    static func fetchAnnouncement() async -> [String: Any]? { nil }
    static func myRank(mode: LeaderboardMode, week: Int, playerID: String) async -> Int? { nil }
    static func writeSeeds(_ seeds: [(id: String, name: String, value: Double)],
                           mode: LeaderboardMode, week: Int) async -> Int { 0 }
    static func documentCount(mode: LeaderboardMode, week: Int) async -> Int? { nil }
    @discardableResult
    static func deleteSeeds(mode: LeaderboardMode, week: Int,
                            keeping prefix: String?, limit: Int = 150) async -> Int { 0 }
}
#endif
#endif
