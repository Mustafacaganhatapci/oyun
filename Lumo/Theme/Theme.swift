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
    let name: String
    let isPremium: Bool

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
        id: "gece", name: "Gece", isPremium: false,
        bgTop: ThemeColor(r: 0.020, g: 0.051, b: 0.102),
        bgBottom: ThemeColor(r: 0.031, g: 0.122, b: 0.216),
        ring: ThemeColor(r: 0.302, g: 0.678, b: 0.949),
        gate: ThemeColor(r: 0.478, g: 1.0, b: 0.643),
        orb: ThemeColor(r: 0.918, g: 0.976, b: 1.0),
        hazard: ThemeColor(r: 1.0, g: 0.427, b: 0.349),
        lumen: ThemeColor(r: 1.0, g: 0.902, b: 0.478),
        accent: ThemeColor(r: 0.353, g: 0.784, b: 1.0)
    )

    static let safak = Theme(
        id: "safak", name: "Şafak", isPremium: true,
        bgTop: ThemeColor(r: 0.184, g: 0.051, b: 0.216),
        bgBottom: ThemeColor(r: 0.475, g: 0.145, b: 0.243),
        ring: ThemeColor(r: 1.0, g: 0.596, b: 0.400),
        gate: ThemeColor(r: 1.0, g: 0.867, b: 0.510),
        orb: ThemeColor(r: 1.0, g: 0.965, b: 0.933),
        hazard: ThemeColor(r: 0.855, g: 0.153, b: 0.467),
        lumen: ThemeColor(r: 1.0, g: 0.843, b: 0.251),
        accent: ThemeColor(r: 1.0, g: 0.588, b: 0.427)
    )

    static let orman = Theme(
        id: "orman", name: "Orman", isPremium: true,
        bgTop: ThemeColor(r: 0.016, g: 0.106, b: 0.086),
        bgBottom: ThemeColor(r: 0.043, g: 0.216, b: 0.153),
        ring: ThemeColor(r: 0.427, g: 0.878, b: 0.576),
        gate: ThemeColor(r: 0.949, g: 0.933, b: 0.478),
        orb: ThemeColor(r: 0.949, g: 1.0, b: 0.949),
        hazard: ThemeColor(r: 1.0, g: 0.376, b: 0.302),
        lumen: ThemeColor(r: 1.0, g: 0.867, b: 0.400),
        accent: ThemeColor(r: 0.478, g: 0.918, b: 0.643)
    )

    static let mercan = Theme(
        id: "mercan", name: "Mercan", isPremium: true,
        bgTop: ThemeColor(r: 0.024, g: 0.086, b: 0.184),
        bgBottom: ThemeColor(r: 0.008, g: 0.278, b: 0.345),
        ring: ThemeColor(r: 1.0, g: 0.502, b: 0.502),
        gate: ThemeColor(r: 0.353, g: 0.949, b: 0.867),
        orb: ThemeColor(r: 1.0, g: 0.976, b: 0.949),
        hazard: ThemeColor(r: 0.937, g: 0.267, b: 0.600),
        lumen: ThemeColor(r: 1.0, g: 0.788, b: 0.427),
        accent: ThemeColor(r: 1.0, g: 0.573, b: 0.573)
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

    static let all: [Theme] = [.nebula, .gece, .safak, .orman, .mercan, .aurora]

    static func theme(id: String) -> Theme {
        all.first { $0.id == id } ?? .nebula
    }
}
