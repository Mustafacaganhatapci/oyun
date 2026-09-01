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
    func previousWeekRank(playerID: String) async -> (week: Int, rank: Int)? {
        guard isAvailable else { return nil }
        let week = currentWeek - 1
        guard week >= 0 else { return nil }
        #if canImport(FirebaseCore)
        let top = await FirebaseBridge.fetchTop(mode: .endless, week: week, myPlayerID: playerID)
        guard let index = top.prefix(3).firstIndex(where: { $0.id == playerID }) else { return nil }
        return (week, index + 1)
        #else
        return nil
        #endif
    }

    /// Bu haftanın ilk 50 sonucunu getirir
    func refresh(mode: LeaderboardMode, myPlayerID: String) {
        guard isAvailable else { return }
        #if canImport(FirebaseCore)
        isLoading = true
        let week = currentWeek
        Task {
            let entries = await FirebaseBridge.fetchTop(mode: mode, week: week, myPlayerID: myPlayerID)
            await MainActor.run {
                switch mode {
                case .endless: self.endlessEntries = entries
                case .speedrun: self.speedrunEntries = entries
                }
                self.isLoading = false
            }
        }
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

    static func fetchTop(mode: LeaderboardMode, week: Int, myPlayerID: String) async -> [LeaderboardEntry] {
        let db = Firestore.firestore()
        let descending = (mode == .endless)   // endless: yüksek üstte, speedrun: düşük üstte
        do {
            let query = db.collection(mode.collection(week: week))
                .order(by: "value", descending: descending)
                .limit(to: 50)
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
    static func fetchTop(mode: LeaderboardMode, week: Int, myPlayerID: String) async -> [LeaderboardEntry] { [] }
}
#endif
#endif
