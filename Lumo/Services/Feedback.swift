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

    /// Günde kaç mesaj. Kutu sınırsızdı: tek bir kişi gece boyunca yüzlerce
    /// belge yazabiliyordu — hem Firestore faturası hem de gerçek geri
    /// bildirimin içinde kaybolması. İkisi, söyleyecek sözü olan birine yeter.
    static let dailyLimit = 2

    private static let dayKey = "lumo.feedback.day"
    private static let countKey = "lumo.feedback.count"

    /// Bugünün gün numarası (1970'ten beri). Saat dilimi cihazın kendisi:
    /// oyuncunun "bugün"ü neyse o.
    private static var today: Int {
        let start = Calendar.current.startOfDay(for: Date())
        return Int(start.timeIntervalSince1970 / 86_400)
    }

    /// Bugün kaç hakkı kaldı
    static var remainingToday: Int {
        let d = UserDefaults.standard
        guard d.integer(forKey: dayKey) == today else { return dailyLimit }
        return max(0, dailyLimit - d.integer(forKey: countKey))
    }

    /// Hak yalnızca GÖNDERİM BAŞARILI olunca düşüyor: ağ koptuğu için
    /// gitmeyen bir mesaj oyuncunun hakkını yakmamalı.
    private static func consume() {
        let d = UserDefaults.standard
        if d.integer(forKey: dayKey) != today {
            d.set(today, forKey: dayKey)
            d.set(0, forKey: countKey)
        }
        d.set(d.integer(forKey: countKey) + 1, forKey: countKey)
    }

    /// true = yazıldı. Firebase yoksa, ağ hatasında ya da günlük hak
    /// bittiyse false.
    static func send(message: String, playerID: String, username: String) async -> Bool {
        guard remainingToday > 0 else { return false }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4 else { return false }
        let clipped = String(trimmed.prefix(maxLength))
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"

        #if canImport(FirebaseCore)
        let sent = await FirebaseBridge.sendFeedback(message: clipped,
                                                     playerID: playerID,
                                                     username: username,
                                                     version: version)
        if sent { consume() }
        return sent
        #else
        return false
        #endif
    }
}
