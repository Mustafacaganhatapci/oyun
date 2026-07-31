import Foundation
import SwiftUI

/// Oyuncu ilerlemesi. Kaynak her zaman cihazdaki UserDefaults'tur; iCloud
/// anahtar-değer deposu yalnızca yedektir. iCloud kapalıysa ya da yetenek
/// projede etkin değilse yazmalar sessizce yok sayılır ve oyun aynen çalışır.
@MainActor
final class ProgressStore: ObservableObject {
    @Published private(set) var stars: [Int: Int] = [:]      // bölüm -> 0...3 yıldız
    @Published private(set) var endlessBest: Int = 0
    @Published private(set) var speedrunBest: Double = 0     // saniye; 0 = henüz yok
    @Published private(set) var totalHops: Int = 0
    @Published private(set) var spentStars: Int = 0          // karakter almak için harcanan yıldız
    @Published private(set) var unlockedOrbs: Set<String> = []  // yıldızla açılan küre stilleri
    @Published private(set) var bonusStars: Int = 0          // hediye/teselli yıldızları (ör. promo kodu)

    private let defaults = UserDefaults.standard
    private enum Key {
        static let stars = "lumo.progress.stars"
        static let endlessBest = "lumo.progress.endlessBest"
        static let speedrunBest = "lumo.progress.speedrunBest"
        static let totalHops = "lumo.progress.totalHops"
        static let spentStars = "lumo.progress.spentStars"
        static let unlockedOrbs = "lumo.progress.unlockedOrbs"
        static let bonusStars = "lumo.progress.bonusStars"
    }

    private let cloud = NSUbiquitousKeyValueStore.default

    init() {
        if let data = defaults.data(forKey: Key.stars),
           let decoded = try? JSONDecoder().decode([Int: Int].self, from: data) {
            stars = decoded
        }
        endlessBest = defaults.integer(forKey: Key.endlessBest)
        speedrunBest = defaults.double(forKey: Key.speedrunBest)
        totalHops = defaults.integer(forKey: Key.totalHops)
        spentStars = defaults.integer(forKey: Key.spentStars)
        unlockedOrbs = Set(defaults.stringArray(forKey: Key.unlockedOrbs) ?? [])
        bonusStars = defaults.integer(forKey: Key.bonusStars)

        // Yeni cihazda/silme sonrası buluttaki ilerlemeyi geri getir
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.mergeFromCloud() }
        }
        cloud.synchronize()
        mergeFromCloud()
    }

    // MARK: iCloud yedekleme
    //
    // Cihaz kaybı/değişimi ilerlemeyi silmesin diye anahtar-değer deposuna
    // yedeklenir. Çakışmada DAİMA daha ileri olan kazanır: bölüm başına en
    // yüksek yıldız, en iyi skorlar ve açılmış her karakter korunur — hiçbir
    // birleştirme oyuncunun elindekini geri almaz.

    private func mergeFromCloud() {
        if let data = cloud.data(forKey: Key.stars),
           let remote = try? JSONDecoder().decode([Int: Int].self, from: data) {
            for (level, value) in remote {
                stars[level] = max(stars[level] ?? 0, value)
            }
        }
        endlessBest = max(endlessBest, Int(cloud.longLong(forKey: Key.endlessBest)))
        totalHops = max(totalHops, Int(cloud.longLong(forKey: Key.totalHops)))
        bonusStars = max(bonusStars, Int(cloud.longLong(forKey: Key.bonusStars)))
        // Harcanan yıldız da en yükseği kazanır; yoksa bulut bakiyesi
        // sıfırlanıp aynı karakter iki kez satın alınabilirdi
        spentStars = max(spentStars, Int(cloud.longLong(forKey: Key.spentStars)))
        unlockedOrbs.formUnion(cloud.stringArray(forKey: Key.unlockedOrbs) ?? [])

        let remoteSpeed = cloud.double(forKey: Key.speedrunBest)
        if remoteSpeed > 0, speedrunBest == 0 || remoteSpeed < speedrunBest {
            speedrunBest = remoteSpeed
        }

        persistLocally()
        pushToCloud()
    }

    private func pushToCloud() {
        if let data = try? JSONEncoder().encode(stars) {
            cloud.set(data, forKey: Key.stars)
        }
        cloud.set(Int64(endlessBest), forKey: Key.endlessBest)
        cloud.set(Int64(totalHops), forKey: Key.totalHops)
        cloud.set(Int64(spentStars), forKey: Key.spentStars)
        cloud.set(Int64(bonusStars), forKey: Key.bonusStars)
        cloud.set(speedrunBest, forKey: Key.speedrunBest)
        cloud.set(Array(unlockedOrbs), forKey: Key.unlockedOrbs)
        cloud.synchronize()
    }

    private func persistLocally() {
        if let data = try? JSONEncoder().encode(stars) {
            defaults.set(data, forKey: Key.stars)
        }
        defaults.set(endlessBest, forKey: Key.endlessBest)
        defaults.set(speedrunBest, forKey: Key.speedrunBest)
        defaults.set(totalHops, forKey: Key.totalHops)
        defaults.set(spentStars, forKey: Key.spentStars)
        defaults.set(bonusStars, forKey: Key.bonusStars)
        defaults.set(Array(unlockedOrbs), forKey: Key.unlockedOrbs)
    }

    /// Tamamlanan en yüksek bölüm + 1 oynanabilir; 1. bölüm her zaman açık.
    var highestUnlocked: Int {
        let completed = stars.keys.max() ?? 0
        return min(completed + 1, LevelLibrary.count)
    }

    var completedCount: Int { stars.count }
    var totalStars: Int { stars.values.reduce(0, +) + bonusStars }
    /// Harcanabilir yıldız bakiyesi (toplam - harcanan)
    var availableStars: Int { max(0, totalStars - spentStars) }

    /// Hediye/teselli yıldızı ekler (ör. promo kodu 5'ten fazla yanlış girilince).
    func grantBonusStars(_ amount: Int) {
        bonusStars += amount
        defaults.set(bonusStars, forKey: Key.bonusStars)
        pushToCloud()
    }
    var endlessUnlocked: Bool { stars[LevelLibrary.adFreeLevels] != nil }

    func isUnlocked(_ level: Int) -> Bool { level <= highestUnlocked }

    // MARK: Yıldızla karakter (küre stili) satın alma

    func isOrbUnlocked(_ style: OrbStyle) -> Bool {
        switch style.unlock {
        case .free: return true
        case .premium: return false          // premium ayrı yönetilir (StoreManager)
        case .stars: return unlockedOrbs.contains(style.id)
        }
    }

    func canAfford(_ style: OrbStyle) -> Bool {
        guard let cost = style.starCost else { return false }
        return availableStars >= cost
    }

    /// Yeterli yıldız varsa satın alır; başarılıysa true döner.
    @discardableResult
    func purchaseOrb(_ style: OrbStyle) -> Bool {
        guard let cost = style.starCost, !isOrbUnlocked(style), availableStars >= cost else { return false }
        spentStars += cost
        unlockedOrbs.insert(style.id)
        defaults.set(spentStars, forKey: Key.spentStars)
        defaults.set(Array(unlockedOrbs), forKey: Key.unlockedOrbs)
        pushToCloud()
        return true
    }

    func complete(level: Int, stars newStars: Int) {
        let existing = stars[level] ?? 0
        stars[level] = max(existing, newStars)
        save()
    }

    func recordHop() {
        totalHops += 1
        defaults.set(totalHops, forKey: Key.totalHops)
        // Her sıçrayışta buluta yazmak gereksiz trafik; ara ara yeter
        if totalHops % 25 == 0 { pushToCloud() }
    }

    func recordEndless(score: Int) {
        if score > endlessBest {
            endlessBest = score
            defaults.set(endlessBest, forKey: Key.endlessBest)
            pushToCloud()
        }
    }

    /// Yeni rekor ise true döner
    @discardableResult
    func recordSpeedrun(time: Double) -> Bool {
        if speedrunBest == 0 || time < speedrunBest {
            speedrunBest = time
            defaults.set(speedrunBest, forKey: Key.speedrunBest)
            pushToCloud()
            return true
        }
        return false
    }

    private func save() {
        if let data = try? JSONEncoder().encode(stars) {
            defaults.set(data, forKey: Key.stars)
        }
        pushToCloud()
    }
}
