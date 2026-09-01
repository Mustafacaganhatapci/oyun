import Foundation
import SwiftUI

/// Öğretici ipuçlarının bir kez gösterilmesini yönetir (UserDefaults).
@MainActor
final class TutorialStore: ObservableObject {
    @Published private(set) var shown: Set<String> = []

    // v2: öğretici tamamen yenilendi (etkileşimli koç) — eski "gösterildi"
    // kayıtları geçersiz; anahtar değişince herkes yeni akışı bir kez görür
    private let key = "lumo.tutorial.shown.v3"

    init() {
        shown = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    func shouldShow(_ hint: TutorialHint) -> Bool { !shown.contains(hint.rawValue) }

    func markShown(_ hint: TutorialHint) {
        guard !shown.contains(hint.rawValue) else { return }
        shown.insert(hint.rawValue)
        UserDefaults.standard.set(Array(shown), forKey: key)
    }

    /// Tüm ipuçlarını sıfırla (ayarlardan "öğreticiyi tekrar göster")
    func reset() {
        shown = []
        UserDefaults.standard.removeObject(forKey: key)
    }
}

/// Öğretici ipucu türleri. rawValue kalıcı anahtardır.
enum TutorialHint: String, CaseIterable, Identifiable {
    case launch     // temel mekanik: dokun-fırla
    case hazard     // kırmızı tehlike yayı
    case moving     // hareketli halka
    case gate       // bitiş kapısı
    case timed      // süreli bölüm
    case bounds     // ileri bölümlerde kaçırmak = elenmek
    case bonus      // bonus turu: kapı yok, tehlike yok, süre var
    case modes      // 10. bölümde açılan sonsuz mod ve hız turu

    var id: String { rawValue }

    /// Yerelleştirme anahtarları (Localizable.xcstrings)
    var titleKey: String {
        switch self {
        case .launch: return "How to play"
        case .hazard: return "Watch out!"
        case .moving: return "Moving rings"
        case .gate:   return "The gate"
        case .timed:  return "Beat the clock!"
        case .bounds: return "Careful now!"
        case .bonus:  return "Bonus round"
        case .modes:  return "Two new modes"
        }
    }
    var bodyKey: String {
        switch self {
        case .launch: return "The orb orbits a ring. Tap anywhere to launch it toward the next ring."
        case .hazard: return "The arc starts green: on your first lap it can't hurt you. The green melts away from both ends, and once it's gone the arc turns red and burns. Leave before that."
        case .moving: return "Some rings drift back and forth. Wait for the right moment."
        case .gate:   return "Reach the dashed turquoise gate to finish the level."
        case .timed:  return "This level is timed! Reach the gate before the countdown hits zero."
        case .bounds: return "From this level on, if the orb flies off the screen, you lose the attempt."
        case .bonus:  return "No gate and nothing that can hurt you here. Just grab as many stars as you can before the clock runs out."
        case .modes:  return "Endless Mode and Speed Run are open. Both go on the weekly board, and it resets every Monday — see if you can take a place in the top three."
        }
    }
    var systemImage: String {
        switch self {
        case .launch: return "hand.tap.fill"
        case .hazard: return "exclamationmark.triangle.fill"
        case .moving: return "arrow.left.and.right"
        case .gate:   return "flag.checkered"
        case .timed:  return "timer"
        case .bounds: return "xmark.octagon.fill"
        case .bonus:  return "sparkles"
        case .modes:  return "trophy.fill"
        }
    }
}
