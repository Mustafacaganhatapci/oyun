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
    /// ESKİ SÜRÜM ARTIĞI: küreler yıldızla satın alınırken harcanan bakiye.
    /// Artık hiçbir şey harcanmıyor (eşik geçilince açılıyor); yalnızca eski
    /// kayıtları bozmadan taşımak için okunup yazılmaya devam ediyor.
    @Published private(set) var spentStars: Int = 0
    @Published private(set) var unlockedOrbs: Set<String> = []  // ödülle kazanılan küre stilleri
    /// Açılışı oyuncuya GÖSTERİLMİŞ küreler. Eşik geçildiği anda küre zaten
    /// açılıyor; bu küme yalnızca kutlama ekranının bir kez çıkmasını sağlıyor.
    @Published private(set) var revealedOrbs: Set<String> = []
    @Published private(set) var bonusStars: Int = 0          // hediye/teselli yıldızları (ör. promo kodu)
    /// Şampiyonluk ödülü verilen son hafta — aynı hafta iki kez ödenmesin
    @Published private(set) var lastChampionWeek: Int = -1

    private let defaults = UserDefaults.standard
    private enum Key {
        static let stars = "lumo.progress.stars"
        static let endlessBest = "lumo.progress.endlessBest"
        static let speedrunBest = "lumo.progress.speedrunBest"
        static let totalHops = "lumo.progress.totalHops"
        static let spentStars = "lumo.progress.spentStars"
        static let unlockedOrbs = "lumo.progress.unlockedOrbs"
        static let revealedOrbs = "lumo.progress.revealedOrbs"
        static let bonusStars = "lumo.progress.bonusStars"
        static let lastChampionWeek = "lumo.progress.lastChampionWeek"
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
        revealedOrbs = Set(defaults.stringArray(forKey: Key.revealedOrbs) ?? [])
        bonusStars = defaults.integer(forKey: Key.bonusStars)
        // -1: hiç ödül alınmamış. Hafta numaraları 0'dan başladığı için
        // varsayılan 0 kullanılamaz, ilk haftayı ödenmiş sayardı.
        lastChampionWeek = defaults.object(forKey: Key.lastChampionWeek) as? Int ?? -1

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
        unlockedOrbs.formUnion(cloud.array(forKey: Key.unlockedOrbs) as? [String] ?? [])
        revealedOrbs.formUnion(cloud.array(forKey: Key.revealedOrbs) as? [String] ?? [])
        // İleri olan hafta kazanır: ödül aynı hesapta ikinci bir cihazda
        // tekrar verilmesin
        lastChampionWeek = max(lastChampionWeek, Int(cloud.longLong(forKey: Key.lastChampionWeek)))

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
        cloud.set(Array(revealedOrbs), forKey: Key.revealedOrbs)
        cloud.set(Int64(lastChampionWeek), forKey: Key.lastChampionWeek)
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
        defaults.set(Array(revealedOrbs), forKey: Key.revealedOrbs)
        defaults.set(lastChampionWeek, forKey: Key.lastChampionWeek)
    }

    /// Tamamlanan en yüksek bölüm + 1 oynanabilir; 1. bölüm her zaman açık.
    var highestUnlocked: Int {
        let completed = stars.keys.max() ?? 0
        return min(completed + 1, LevelLibrary.count)
    }

    var completedCount: Int { stars.count }
    var totalStars: Int { stars.values.reduce(0, +) + bonusStars }

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
        // Yıldız eşiği geçildiği an açılır — harcama yok. `unlockedOrbs` eski
        // sürümde satın almış oyuncular için duruyor: eşiğin altında olsalar
        // bile aldıkları küre ellerinden gitmesin.
        case .stars(let need): return unlockedOrbs.contains(style.id) || totalStars >= need
        // Şampiyon küresi satın alınamaz, eşikle de açılmaz: tek yolu
        // haftalık ilk üçe girmek.
        case .champion: return unlockedOrbs.contains(style.id)
        }
    }

    /// Açılmış ama oyuncuya HENÜZ gösterilmemiş ilk küre. Bölüm bitişinde
    /// sorulup kutlama ekranı buna göre açılıyor.
    func pendingOrbReveal() -> OrbStyle? {
        OrbStyle.starLadder.first { isOrbUnlocked($0) && !revealedOrbs.contains($0.id) }
    }

    func markOrbRevealed(_ style: OrbStyle) {
        guard revealedOrbs.insert(style.id).inserted else { return }
        defaults.set(Array(revealedOrbs), forKey: Key.revealedOrbs)
        pushToCloud()
    }

    /// Sıradaki küre ve ona kalan yıldız. Hepsi açıldıysa nil.
    var nextOrbGoal: (style: OrbStyle, remaining: Int)? {
        OrbStyle.nextLocked(totalStars: totalStars)
    }

    /// Haftalık şampiyonluk ödülü: yıldızlar + şampiyon küresi.
    /// Aynı hafta için birden fazla kez verilmez.
    @discardableResult
    func grantChampionReward(week: Int, rank: Int, stars amount: Int) -> Bool {
        guard week > lastChampionWeek else { return false }
        lastChampionWeek = week
        defaults.set(week, forKey: Key.lastChampionWeek)
        unlockedOrbs.insert(OrbStyle.championID)
        defaults.set(Array(unlockedOrbs), forKey: Key.unlockedOrbs)
        grantBonusStars(amount)
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
