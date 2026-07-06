import Foundation
import SwiftUI

/// Oyuncu ilerlemesi — UserDefaults'ta saklanır, buluta bağımlılık yoktur.
@MainActor
final class ProgressStore: ObservableObject {
    @Published private(set) var stars: [Int: Int] = [:]      // bölüm -> 0...3 yıldız
    @Published private(set) var endlessBest: Int = 0
    @Published private(set) var speedrunBest: Double = 0     // saniye; 0 = henüz yok
    @Published private(set) var totalHops: Int = 0

    private let defaults = UserDefaults.standard
    private enum Key {
        static let stars = "lumo.progress.stars"
        static let endlessBest = "lumo.progress.endlessBest"
        static let speedrunBest = "lumo.progress.speedrunBest"
        static let totalHops = "lumo.progress.totalHops"
    }

    init() {
        if let data = defaults.data(forKey: Key.stars),
           let decoded = try? JSONDecoder().decode([Int: Int].self, from: data) {
            stars = decoded
        }
        endlessBest = defaults.integer(forKey: Key.endlessBest)
        speedrunBest = defaults.double(forKey: Key.speedrunBest)
        totalHops = defaults.integer(forKey: Key.totalHops)
    }

    /// Tamamlanan en yüksek bölüm + 1 oynanabilir; 1. bölüm her zaman açık.
    var highestUnlocked: Int {
        let completed = stars.keys.max() ?? 0
        return min(completed + 1, LevelLibrary.count)
    }

    var completedCount: Int { stars.count }
    var totalStars: Int { stars.values.reduce(0, +) }
    var endlessUnlocked: Bool { stars[LevelLibrary.adFreeLevels] != nil }

    func isUnlocked(_ level: Int) -> Bool { level <= highestUnlocked }

    func complete(level: Int, stars newStars: Int) {
        let existing = stars[level] ?? 0
        stars[level] = max(existing, newStars)
        save()
    }

    func recordHop() {
        totalHops += 1
        defaults.set(totalHops, forKey: Key.totalHops)
    }

    func recordEndless(score: Int) {
        if score > endlessBest {
            endlessBest = score
            defaults.set(endlessBest, forKey: Key.endlessBest)
        }
    }

    /// Yeni rekor ise true döner
    @discardableResult
    func recordSpeedrun(time: Double) -> Bool {
        if speedrunBest == 0 || time < speedrunBest {
            speedrunBest = time
            defaults.set(speedrunBest, forKey: Key.speedrunBest)
            return true
        }
        return false
    }

    private func save() {
        if let data = try? JSONEncoder().encode(stars) {
            defaults.set(data, forKey: Key.stars)
        }
    }
}
