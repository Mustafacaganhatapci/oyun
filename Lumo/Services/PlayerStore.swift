import Foundation
import SwiftUI

/// Oyuncu kimliği: kullanıcı adı + kalıcı benzersiz kimlik.
/// Kimlik cihazda üretilir; dünya sıralamasında bu kimlikle skor yazılır.
@MainActor
final class PlayerStore: ObservableObject {
    @Published private(set) var username: String
    @Published private(set) var playerID: String

    private let defaults = UserDefaults.standard
    private enum Key {
        static let username = "lumo.player.username"
        static let playerID = "lumo.player.id"
    }

    init() {
        username = defaults.string(forKey: Key.username) ?? ""
        if let existing = defaults.string(forKey: Key.playerID) {
            playerID = existing
        } else {
            let newID = UUID().uuidString
            playerID = newID
            defaults.set(newID, forKey: Key.playerID)
        }
    }

    var hasUsername: Bool { !username.trimmingCharacters(in: .whitespaces).isEmpty }

    /// Kullanıcı adını temizleyip kaydeder (3–16 karakter, harf/rakam/altçizgi).
    @discardableResult
    func setUsername(_ raw: String) -> Bool {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValid(cleaned) else { return false }
        username = cleaned
        defaults.set(cleaned, forKey: Key.username)
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
