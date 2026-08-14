import Foundation
import SwiftUI

/// Oyuncu kimliği: kullanıcı adı + kalıcı benzersiz kimlik.
/// Kimlik cihazda üretilir; dünya sıralamasında bu kimlikle skor yazılır.
@MainActor
final class PlayerStore: ObservableObject {
    @Published private(set) var username: String
    @Published private(set) var playerID: String

    /// Ad bir kez soruldu mu? Boş bırakan oyuncuya her açılışta sormamak için
    /// tutulur; sıralamaya katılmak isteğe bağlıdır.
    @Published private(set) var wasPromptedForUsername: Bool

    /// Ad bir kez seçilir. Sıralamada adlar tekil olduğu için sonradan
    /// değiştirmeye izin vermek, bırakılan adın yeniden alınıp alınamayacağı
    /// ve eski hafta kayıtlarının kime ait olduğu gibi sorular doğuruyor.
    @Published private(set) var isUsernameLocked: Bool

    private let defaults = UserDefaults.standard
    private enum Key {
        static let username = "lumo.player.username"
        static let playerID = "lumo.player.id"
        static let prompted = "lumo.player.usernamePrompted"
        static let locked = "lumo.player.usernameLocked"
    }

    init() {
        username = defaults.string(forKey: Key.username) ?? ""
        wasPromptedForUsername = defaults.bool(forKey: Key.prompted)
        // Bu sürümden önce ad koymuş oyuncular da kilitli sayılır: adları zaten
        // sıralamada geçiyor, sonradan serbest bırakmak tekilliği bozardı.
        isUsernameLocked = defaults.bool(forKey: Key.locked)
            || !(defaults.string(forKey: Key.username) ?? "").isEmpty
        if let existing = defaults.string(forKey: Key.playerID) {
            playerID = existing
        } else {
            let newID = UUID().uuidString
            playerID = newID
            defaults.set(newID, forKey: Key.playerID)
        }
    }

    var hasUsername: Bool { !username.trimmingCharacters(in: .whitespaces).isEmpty }

    /// Ad ekranı gösterildi (kaydedilmiş olsun ya da olmasın) — bir daha
    /// kendiliğinden açılmaz.
    func markUsernamePrompted() {
        guard !wasPromptedForUsername else { return }
        wasPromptedForUsername = true
        defaults.set(true, forKey: Key.prompted)
    }

    /// İlk açılışta ad sorulmalı mı?
    var shouldPromptForUsername: Bool { !hasUsername && !wasPromptedForUsername }

    /// Kullanıcı adını temizleyip kaydeder (3–16 karakter, harf/rakam/altçizgi).
    /// Ad bir kez kilitlendikten sonra değiştirilemez.
    @discardableResult
    func setUsername(_ raw: String) -> Bool {
        guard !isUsernameLocked else { return false }
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValid(cleaned) else { return false }
        username = cleaned
        defaults.set(cleaned, forKey: Key.username)
        isUsernameLocked = true
        defaults.set(true, forKey: Key.locked)
        return true
    }

    static func isValid(_ name: String) -> Bool {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard (3...16).contains(n.count) else { return false }
        let allowed = CharacterSet(charactersIn:
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
        return n.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
