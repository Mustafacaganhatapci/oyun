import Foundation

/// Ayarlardaki görüş/öneri kutusunun arkası.
///
/// Firestore'daki `feedback` koleksiyonuna yazar. Mağaza yorumları geliştiriciye
/// ulaşmıyor, e-posta bağlantısını da kimse açmıyor; oyuncunun bir şey
/// söyleyebileceği tek pratik yer bu.
enum Feedback {
    /// Metin sınırı. Doğrudan bir Firestore belgesine gittiği için sınırsız
    /// bırakılmıyor.
    static let maxLength = 1000

    /// true = yazıldı. Firebase yoksa ya da ağ hatasında false.
    static func send(message: String, playerID: String, username: String) async -> Bool {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4 else { return false }
        let clipped = String(trimmed.prefix(maxLength))
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"

        #if canImport(FirebaseCore)
        return await FirebaseBridge.sendFeedback(message: clipped,
                                                 playerID: playerID,
                                                 username: username,
                                                 version: version)
        #else
        return false
        #endif
    }
}
