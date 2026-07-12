import Foundation
import SwiftUI

enum LeaderboardMode {
    case endless    // yüksek skor kazanır
    case speedrun   // düşük süre kazanır

    var collection: String {
        switch self {
        case .endless: return "leaderboard_endless"
        case .speedrun: return "leaderboard_speedrun"
        }
    }
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

    /// Oyuncunun en iyi sonucunu küresel tabloya yazar
    func submit(mode: LeaderboardMode, value: Double, username: String, playerID: String) {
        guard isAvailable, !username.isEmpty else { return }
        #if canImport(FirebaseCore)
        Task { await FirebaseBridge.submit(mode: mode, value: value, username: username, playerID: playerID) }
        #endif
    }

    /// İlk 50 sonucu getirir
    func refresh(mode: LeaderboardMode, myPlayerID: String) {
        guard isAvailable else { return }
        #if canImport(FirebaseCore)
        isLoading = true
        Task {
            let entries = await FirebaseBridge.fetchTop(mode: mode, myPlayerID: myPlayerID)
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

    static func submit(mode: LeaderboardMode, value: Double, username: String, playerID: String) async {
        let db = Firestore.firestore()
        let doc = db.collection(mode.collection).document(playerID)
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
        } catch {
            // sessizce yut
        }
    }

    static func fetchTop(mode: LeaderboardMode, myPlayerID: String) async -> [LeaderboardEntry] {
        let db = Firestore.firestore()
        let descending = (mode == .endless)   // endless: yüksek üstte, speedrun: düşük üstte
        do {
            let query = db.collection(mode.collection)
                .order(by: "value", descending: descending)
                .limit(to: 50)
            let snap = try await query.getDocuments()
            return snap.documents.compactMap { doc in
                guard let username = doc.data()["username"] as? String,
                      let value = doc.data()["value"] as? Double else { return nil }
                return LeaderboardEntry(id: doc.documentID, username: username,
                                        value: value, isMe: doc.documentID == myPlayerID)
            }
        } catch {
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
    static func submit(mode: LeaderboardMode, value: Double, username: String, playerID: String) async {}
    static func fetchTop(mode: LeaderboardMode, myPlayerID: String) async -> [LeaderboardEntry] { [] }
}
#endif
#endif
