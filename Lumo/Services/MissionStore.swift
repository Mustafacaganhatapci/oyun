import Foundation
import SwiftUI

/// Günlük görevler — her gün 3 görev, tamamlananın ödülü yıldız olarak alınır.
/// Görev listesi güne göre deterministik seçilir (aynı gün = aynı görevler).
@MainActor
final class MissionStore: ObservableObject {

    struct Mission: Identifiable, Equatable {
        let id: String
        let title: LocalizedStringKey
        let target: Int
        let reward: Int
        var progress: Int
        var claimed: Bool

        var isComplete: Bool { progress >= target }
        var fraction: Double { min(1, Double(progress) / Double(max(1, target))) }
    }

    /// Görev şablonları — id sabit kalmalı (ilerleme bunlara yazılır)
    private enum Template: String, CaseIterable {
        case levels3, levels5, stars30, hops150, lumens40, noDeath

        var target: Int {
            switch self {
            case .levels3: return 3
            case .levels5: return 5
            case .stars30: return 30
            case .hops150: return 150
            case .lumens40: return 40
            case .noDeath: return 1
            }
        }
        var reward: Int {
            switch self {
            case .levels3: return 15
            case .levels5: return 25
            case .stars30: return 20
            case .hops150: return 15
            case .lumens40: return 20
            case .noDeath: return 30
            }
        }
        var title: LocalizedStringKey {
            switch self {
            case .levels3: return "Finish 3 levels"
            case .levels5: return "Finish 5 levels"
            case .stars30: return "Collect 30 stars"
            case .hops150: return "Make 150 hops"
            case .lumens40: return "Collect 40 lumens"
            case .noDeath: return "Clear a level without dying"
            }
        }
    }

    @Published private(set) var missions: [Mission] = []

    private let defaults = UserDefaults.standard
    private enum Key {
        static let day = "lumo.missions.day"
        static let progress = "lumo.missions.progress"   // [id: Int]
        static let claimed = "lumo.missions.claimed"     // [id]
    }

    init() { reloadForToday() }

    var unclaimedCount: Int { missions.filter { $0.isComplete && !$0.claimed }.count }

    /// Gün değiştiyse yeni görevleri kurar, ilerlemeyi sıfırlar.
    func reloadForToday() {
        let today = Self.dayKey()
        if defaults.string(forKey: Key.day) != today {
            defaults.set(today, forKey: Key.day)
            defaults.removeObject(forKey: Key.progress)
            defaults.removeObject(forKey: Key.claimed)
        }
        let progress = defaults.dictionary(forKey: Key.progress) as? [String: Int] ?? [:]
        let claimed = Set(defaults.stringArray(forKey: Key.claimed) ?? [])

        missions = Self.todaysTemplates().map { t in
            Mission(id: t.rawValue, title: t.title, target: t.target, reward: t.reward,
                    progress: progress[t.rawValue] ?? 0, claimed: claimed.contains(t.rawValue))
        }
    }

    // MARK: İlerleme kaydı — oyun bu üçünü çağırır

    func recordLevelCleared(deathless: Bool, starsEarned: Int) {
        bump(.levels3, 1); bump(.levels5, 1)
        if starsEarned > 0 { bump(.stars30, starsEarned) }
        if deathless { bump(.noDeath, 1) }
    }

    func recordHops(_ count: Int) { bump(.hops150, count) }
    func recordLumens(_ count: Int) { bump(.lumens40, count) }

    /// Tamamlanmış görevin ödülünü alır; verilecek yıldızı döner.
    @discardableResult
    func claim(_ id: String) -> Int? {
        guard let index = missions.firstIndex(where: { $0.id == id }),
              missions[index].isComplete, !missions[index].claimed else { return nil }
        missions[index].claimed = true
        var claimed = Set(defaults.stringArray(forKey: Key.claimed) ?? [])
        claimed.insert(id)
        defaults.set(Array(claimed), forKey: Key.claimed)
        return missions[index].reward
    }

    private func bump(_ template: Template, _ amount: Int) {
        guard let index = missions.firstIndex(where: { $0.id == template.rawValue }),
              !missions[index].claimed else { return }
        missions[index].progress += amount
        var progress = defaults.dictionary(forKey: Key.progress) as? [String: Int] ?? [:]
        progress[template.rawValue] = missions[index].progress
        defaults.set(progress, forKey: Key.progress)
    }

    // MARK: Günün görev seçimi (deterministik)

    private static func dayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private static func todaysTemplates() -> [Template] {
        var seed: UInt64 = 0
        for byte in dayKey().utf8 { seed = seed &* 31 &+ UInt64(byte) }
        var rng = SplitMix64(seed: seed)
        return Array(Template.allCases.shuffled(using: &rng).prefix(3))
    }
}
