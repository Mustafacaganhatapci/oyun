import SwiftUI
import UIKit

/// Oyunun tüm renk kimliği tek yerden yönetilir.
/// Her tema hem SwiftUI (Color) hem SpriteKit (UIColor) tarafında kullanılır.
struct ThemeColor: Equatable {
    let r: Double
    let g: Double
    let b: Double

    var color: Color { Color(red: r, green: g, blue: b) }
    var uiColor: UIColor { UIColor(red: r, green: g, blue: b, alpha: 1) }

    func opacity(_ a: Double) -> Color { Color(red: r, green: g, blue: b).opacity(a) }
}

struct Theme: Identifiable, Equatable {
    let id: String
    /// İngilizce ad — aynı zamanda yerelleştirme anahtarıdır (Localizable.xcstrings)
    let name: String
    let isPremium: Bool

    var localizedName: String { String(localized: String.LocalizationValue(name)) }

    let bgTop: ThemeColor
    let bgBottom: ThemeColor
    let ring: ThemeColor
    let gate: ThemeColor
    let orb: ThemeColor
    let hazard: ThemeColor
    let lumen: ThemeColor
    let accent: ThemeColor

    static let nebula = Theme(
        id: "nebula", name: "Nebula", isPremium: false,
        bgTop: ThemeColor(r: 0.055, g: 0.043, b: 0.161),
        bgBottom: ThemeColor(r: 0.129, g: 0.043, b: 0.267),
        ring: ThemeColor(r: 0.478, g: 0.408, b: 0.933),
        gate: ThemeColor(r: 0.290, g: 0.949, b: 0.788),
        orb: ThemeColor(r: 1.0, g: 1.0, b: 1.0),
        hazard: ThemeColor(r: 1.0, g: 0.302, b: 0.416),
        lumen: ThemeColor(r: 1.0, g: 0.827, b: 0.353),
        accent: ThemeColor(r: 0.639, g: 0.545, b: 1.0)
    )

    static let gece = Theme(
        id: "gece", name: "Night", isPremium: false,
        bgTop: ThemeColor(r: 0.020, g: 0.051, b: 0.102),
        bgBottom: ThemeColor(r: 0.031, g: 0.122, b: 0.216),
        ring: ThemeColor(r: 0.302, g: 0.678, b: 0.949),
        gate: ThemeColor(r: 0.478, g: 1.0, b: 0.643),
        orb: ThemeColor(r: 0.918, g: 0.976, b: 1.0),
        hazard: ThemeColor(r: 1.0, g: 0.427, b: 0.349),
        lumen: ThemeColor(r: 1.0, g: 0.902, b: 0.478),
        accent: ThemeColor(r: 0.353, g: 0.784, b: 1.0)
    )

    // Pembe/gül tonlu tema — ama halka SOĞUK (periwinkle) olduğu için
    // kırmızı tehlike net ayrışır, göz yormaz.
    static let safak = Theme(
        id: "safak", name: "Dawn", isPremium: true,
        bgTop: ThemeColor(r: 0.141, g: 0.063, b: 0.204),
        bgBottom: ThemeColor(r: 0.396, g: 0.129, b: 0.278),
        ring: ThemeColor(r: 0.655, g: 0.722, b: 1.0),
        gate: ThemeColor(r: 1.0, g: 0.871, b: 0.549),
        orb: ThemeColor(r: 1.0, g: 0.965, b: 0.933),
        hazard: ThemeColor(r: 1.0, g: 0.302, b: 0.290),
        lumen: ThemeColor(r: 1.0, g: 0.816, b: 0.302),
        accent: ThemeColor(r: 1.0, g: 0.620, b: 0.549)
    )

    static let orman = Theme(
        id: "orman", name: "Forest", isPremium: true,
        bgTop: ThemeColor(r: 0.016, g: 0.106, b: 0.086),
        bgBottom: ThemeColor(r: 0.043, g: 0.216, b: 0.153),
        ring: ThemeColor(r: 0.427, g: 0.878, b: 0.576),
        gate: ThemeColor(r: 0.949, g: 0.933, b: 0.478),
        orb: ThemeColor(r: 0.949, g: 1.0, b: 0.949),
        hazard: ThemeColor(r: 1.0, g: 0.376, b: 0.302),
        lumen: ThemeColor(r: 1.0, g: 0.867, b: 0.400),
        accent: ThemeColor(r: 0.478, g: 0.918, b: 0.643)
    )

    // Mercan/okyanus teması — halka AQUA (soğuk), kapı amber, tehlike canlı
    // mercan-kırmızısı: üçü de birbirinden net ayrışır.
    static let mercan = Theme(
        id: "mercan", name: "Coral", isPremium: true,
        bgTop: ThemeColor(r: 0.031, g: 0.086, b: 0.161),
        bgBottom: ThemeColor(r: 0.020, g: 0.239, b: 0.302),
        ring: ThemeColor(r: 0.302, g: 0.847, b: 0.851),
        gate: ThemeColor(r: 1.0, g: 0.804, b: 0.451),
        orb: ThemeColor(r: 1.0, g: 0.976, b: 0.949),
        hazard: ThemeColor(r: 1.0, g: 0.271, b: 0.302),
        lumen: ThemeColor(r: 1.0, g: 0.851, b: 0.451),
        accent: ThemeColor(r: 1.0, g: 0.549, b: 0.502)
    )

    static let aurora = Theme(
        id: "aurora", name: "Aurora", isPremium: true,
        bgTop: ThemeColor(r: 0.043, g: 0.024, b: 0.129),
        bgBottom: ThemeColor(r: 0.016, g: 0.169, b: 0.216),
        ring: ThemeColor(r: 0.353, g: 0.933, b: 0.757),
        gate: ThemeColor(r: 0.788, g: 0.510, b: 1.0),
        orb: ThemeColor(r: 0.949, g: 1.0, b: 0.988),
        hazard: ThemeColor(r: 1.0, g: 0.349, b: 0.522),
        lumen: ThemeColor(r: 0.678, g: 1.0, b: 0.573),
        accent: ThemeColor(r: 0.427, g: 0.949, b: 0.800)
    )

    // Yüksek kontrastlı premium tema — neredeyse siyah zeminde elektrik renkleri;
    // her öğe (özellikle kırmızı tehlike) keskin ayrışır.
    static let neon = Theme(
        id: "neon", name: "Neon", isPremium: true,
        bgTop: ThemeColor(r: 0.020, g: 0.020, b: 0.063),
        bgBottom: ThemeColor(r: 0.063, g: 0.031, b: 0.122),
        ring: ThemeColor(r: 0.200, g: 0.902, b: 1.0),
        gate: ThemeColor(r: 0.451, g: 1.0, b: 0.549),
        orb: ThemeColor(r: 1.0, g: 1.0, b: 1.0),
        hazard: ThemeColor(r: 1.0, g: 0.153, b: 0.353),
        lumen: ThemeColor(r: 1.0, g: 0.902, b: 0.251),
        accent: ThemeColor(r: 0.851, g: 0.353, b: 1.0)
    )

    // Ultra yüksek kontrast / erişilebilirlik teması — beyaz halka, saf kırmızı
    // tehlike, yeşil kapı (trafik ışığı netliği); kömür siyahı zemin.
    static let karbon = Theme(
        id: "karbon", name: "Carbon", isPremium: true,
        bgTop: ThemeColor(r: 0.039, g: 0.039, b: 0.051),
        bgBottom: ThemeColor(r: 0.102, g: 0.102, b: 0.122),
        ring: ThemeColor(r: 0.949, g: 0.949, b: 1.0),
        gate: ThemeColor(r: 0.302, g: 1.0, b: 0.502),
        orb: ThemeColor(r: 0.549, g: 0.847, b: 1.0),
        hazard: ThemeColor(r: 1.0, g: 0.200, b: 0.200),
        lumen: ThemeColor(r: 1.0, g: 0.800, b: 0.200),
        accent: ThemeColor(r: 0.600, g: 0.651, b: 0.749)
    )

    static let all: [Theme] = [.nebula, .gece, .safak, .orman, .mercan, .aurora, .neon, .karbon]

    static func theme(id: String) -> Theme {
        all.first { $0.id == id } ?? .nebula
    }
}
