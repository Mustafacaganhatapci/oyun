import Foundation
import SwiftUI

/// Günlük giriş ödülü — art arda gelen günlerde artan yıldız verir.
/// Bir gün kaçırılırsa seri başa döner. Ödül yalnızca gün başına bir kez alınır.
@MainActor
final class DailyRewardStore: ObservableObject {

    /// 7 günlük döngü; 7. günden sonra son basamak tekrar eder.
    static let ladder = [5, 10, 15, 20, 30, 40, 60]

    @Published private(set) var streak = 0            // kaç gündür üst üste
    @Published private(set) var claimedToday = false

    private let defaults = UserDefaults.standard
    private enum Key {
        static let streak = "lumo.daily.streak"
        static let lastClaim = "lumo.daily.lastClaim"   // gün başlangıcı (timeIntervalSince1970)
    }

    init() {
        streak = defaults.integer(forKey: Key.streak)
        refresh()
    }

    /// Bugünün ödülü (seri kırılmışsa ilk basamak)
    var todayReward: Int {
        let index = min(max(0, effectiveStreak), Self.ladder.count - 1)
        return Self.ladder[index]
    }

    /// Ödül alınırsa serinin kaçıncı günü olacağı (0 tabanlı)
    private var effectiveStreak: Int {
        guard let last = lastClaimDay else { return 0 }
        let days = daysBetween(last, startOfToday)
        return days == 1 ? streak : 0     // dün alındıysa devam, değilse sıfırla
    }

    /// Seri kırıldıysa sayacı düşürüp arayüzü tazeler.
    func refresh() {
        guard let last = lastClaimDay else {
            claimedToday = false
            return
        }
        let days = daysBetween(last, startOfToday)
        claimedToday = (days == 0)
        if days > 1 { streak = 0; defaults.set(0, forKey: Key.streak) }
    }

    /// Bugünün ödülünü verir. Zaten alındıysa nil döner.
    @discardableResult
    func claim() -> Int? {
        refresh()
        guard !claimedToday else { return nil }
        let reward = todayReward
        streak = effectiveStreak + 1
        claimedToday = true
        defaults.set(streak, forKey: Key.streak)
        defaults.set(startOfToday.timeIntervalSince1970, forKey: Key.lastClaim)
        return reward
    }

    // MARK: Gün hesapları (yerel takvim)

    private var startOfToday: Date { Calendar.current.startOfDay(for: Date()) }

    private var lastClaimDay: Date? {
        let raw = defaults.double(forKey: Key.lastClaim)
        return raw > 0 ? Date(timeIntervalSince1970: raw) : nil
    }

    private func daysBetween(_ a: Date, _ b: Date) -> Int {
        Calendar.current.dateComponents([.day], from: a, to: b).day ?? 0
    }
}
