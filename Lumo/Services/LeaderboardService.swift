import Foundation
import SwiftUI
import os

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

    /// "2g 4s" gibi kısa bir kalan süre metni
    var resetCountdownText: String {
        let total = Int(timeUntilReset)
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        if days > 0 { return "\(days)d \(hours)h" }
        let minutes = (total % 3_600) / 60
        return "\(hours)h \(minutes)m"
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

    /// Oyuncunun en iyi sonucunu küresel tabloya yazar
    func submit(mode: LeaderboardMode, value: Double, username: String, playerID: String) {
        guard isAvailable, !username.isEmpty else { return }
        #if canImport(FirebaseCore)
        let week = currentWeek
        Task {
            await FirebaseBridge.submit(mode: mode, week: week, value: value,
                                        username: username, playerID: playerID)
        }
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
            os_log(.error, "Ad sahiplenilemedi (usernames/%{public}@): %{public}@",
                   name.lowercased(), error.localizedDescription)
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
            os_log(.info, "Sıralama yazıldı: %{public}@ = %f", mode.collection(week: week), value)
        } catch {
            // Sessizce yutmak, izin kuralları yazmayı engellediğinde tabloyu
            // "boş" gösteriyor ve hiçbir iz bırakmıyordu. Console.app'te
            // "Orbeon" süzülerek gerçek sebep görülebilsin.
            os_log(.error, "Sıralama YAZILAMADI (%{public}@): %{public}@",
                   mode.collection(week: week), error.localizedDescription)
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
            os_log(.info, "Sıralama okundu: %{public}@ → %d kayıt",
                   mode.collection(week: week), snap.documents.count)
            return snap.documents.compactMap { doc in
                guard let username = doc.data()["username"] as? String,
                      let value = doc.data()["value"] as? Double else { return nil }
                return LeaderboardEntry(id: doc.documentID, username: username,
                                        value: value, isMe: doc.documentID == myPlayerID)
            }
        } catch {
            os_log(.error, "Sıralama OKUNAMADI (%{public}@): %{public}@",
                   mode.collection(week: week), error.localizedDescription)
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
    static func submit(mode: LeaderboardMode, week: Int, value: Double,
                       username: String, playerID: String) async {}
    static func fetchTop(mode: LeaderboardMode, week: Int, myPlayerID: String) async -> [LeaderboardEntry] { [] }
}
#endif
#endif
