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

    /// Renk körlüğü modunda üretilmiş bir tema mı? Oyun alanı bu bayrağa
    /// bakarak renge ek olarak ŞEKİL ipucu da çiziyor (tehlike yaylarındaki
    /// tırtıklar), çünkü tek başına renk hiçbir palette yeterli değil.
    var isColorBlindSafe = false

    /// "Bu tur yakmaz" durumundaki tehlike yayının rengi: kırmızının karşıtı
    /// olduğu için yeşil, ama BİLEREK sönük ve halkadan bir tık koyu. Tek
    /// vurgu dilinde ekranın tek doygun rengi tehlike kırmızısı olmalı;
    /// müsamahalı hâl fark edilir ama bağırmaz.
    ///
    /// Renk körlüğü modunda yeşil tam da işe yaramayan renk; orada
    /// Okabe–Ito'nun mavimsi yeşiline geçiliyor.
    var hazardSafe: ThemeColor {
        isColorBlindSafe
        ? ThemeColor(r: 0.243, g: 0.435, b: 0.396)
        : ThemeColor(r: 0.325, g: 0.463, b: 0.345)
    }

    // MARK: Temalar
    //
    // TEK VURGU dili: halkalar, zemin ve küre nötr; ekrandaki TEK doygun renk
    // tehlike kırmızısı, en parlak şey de hedef kapısı. Anlam taşıyan üç renk
    // (kapı ≈ beyaz, tehlike kırmızı, yıldız altın) bütün temalarda AYNI —
    // tema değiştirmek oynanışın dilini değiştirmiyor, yalnızca zeminin ve
    // halkanın ton sapmasını değiştiriyor.

    // Varsayılan tema. Menekşe-gri.
    static let nebula = Theme(
        id: "nebula", name: "Nebula", isPremium: false,
        bgTop: ThemeColor(r: 0.048, g: 0.047, b: 0.061),
        bgBottom: ThemeColor(r: 0.094, g: 0.089, b: 0.112),
        ring: ThemeColor(r: 0.503, g: 0.499, b: 0.540),
        gate: ThemeColor(r: 0.829, g: 0.955, b: 0.925),
        orb: ThemeColor(r: 0.941, g: 0.945, b: 0.953),
        hazard: ThemeColor(r: 0.820, g: 0.286, b: 0.357),
        lumen: ThemeColor(r: 0.710, g: 0.580, b: 0.314),
        accent: ThemeColor(r: 0.453, g: 0.433, b: 0.531)
    )

    // Soğuk mavi-gri.
    static let gece = Theme(
        id: "gece", name: "Night", isPremium: false,
        bgTop: ThemeColor(r: 0.043, g: 0.050, b: 0.062),
        bgBottom: ThemeColor(r: 0.078, g: 0.096, b: 0.115),
        ring: ThemeColor(r: 0.478, g: 0.512, b: 0.537),
        gate: ThemeColor(r: 0.857, g: 0.949, b: 0.886),
        orb: ThemeColor(r: 0.941, g: 0.945, b: 0.953),
        hazard: ThemeColor(r: 0.820, g: 0.286, b: 0.357),
        lumen: ThemeColor(r: 0.710, g: 0.580, b: 0.314),
        accent: ThemeColor(r: 0.385, g: 0.471, b: 0.513)
    )

    // Gül-gri, hafif sıcak.
    static let safak = Theme(
        id: "safak", name: "Dawn", isPremium: true,
        bgTop: ThemeColor(r: 0.053, g: 0.045, b: 0.060),
        bgBottom: ThemeColor(r: 0.109, g: 0.084, b: 0.098),
        ring: ThemeColor(r: 0.499, g: 0.504, b: 0.527),
        gate: ThemeColor(r: 0.934, g: 0.914, b: 0.862),
        orb: ThemeColor(r: 0.941, g: 0.945, b: 0.953),
        hazard: ThemeColor(r: 0.820, g: 0.286, b: 0.357),
        lumen: ThemeColor(r: 0.710, g: 0.580, b: 0.314),
        accent: ThemeColor(r: 0.501, g: 0.430, b: 0.417)
    )

    // Yeşile çalan gri.
    static let orman = Theme(
        id: "orman", name: "Forest", isPremium: true,
        bgTop: ThemeColor(r: 0.040, g: 0.053, b: 0.051),
        bgBottom: ThemeColor(r: 0.078, g: 0.101, b: 0.092),
        ring: ThemeColor(r: 0.482, g: 0.519, b: 0.494),
        gate: ThemeColor(r: 0.855, g: 0.936, b: 0.954),
        orb: ThemeColor(r: 0.941, g: 0.945, b: 0.953),
        hazard: ThemeColor(r: 0.820, g: 0.286, b: 0.357),
        lumen: ThemeColor(r: 0.710, g: 0.580, b: 0.314),
        accent: ThemeColor(r: 0.401, g: 0.479, b: 0.430)
    )

    // Deniz grisi.
    static let mercan = Theme(
        id: "mercan", name: "Coral", isPremium: true,
        bgTop: ThemeColor(r: 0.042, g: 0.050, b: 0.061),
        bgBottom: ThemeColor(r: 0.074, g: 0.100, b: 0.107),
        ring: ThemeColor(r: 0.473, g: 0.519, b: 0.519),
        gate: ThemeColor(r: 0.944, g: 0.911, b: 0.850),
        orb: ThemeColor(r: 0.941, g: 0.945, b: 0.953),
        hazard: ThemeColor(r: 0.820, g: 0.286, b: 0.357),
        lumen: ThemeColor(r: 0.710, g: 0.580, b: 0.314),
        accent: ThemeColor(r: 0.514, g: 0.424, b: 0.415)
    )

    // Mor-yeşil arası soğuk gri.
    static let aurora = Theme(
        id: "aurora", name: "Aurora", isPremium: true,
        bgTop: ThemeColor(r: 0.049, g: 0.044, b: 0.072),
        bgBottom: ThemeColor(r: 0.075, g: 0.100, b: 0.107),
        ring: ThemeColor(r: 0.474, g: 0.520, b: 0.506),
        gate: ThemeColor(r: 0.944, g: 0.884, b: 0.990),
        orb: ThemeColor(r: 0.941, g: 0.945, b: 0.953),
        hazard: ThemeColor(r: 0.820, g: 0.286, b: 0.357),
        lumen: ThemeColor(r: 0.710, g: 0.580, b: 0.314),
        accent: ThemeColor(r: 0.389, g: 0.480, b: 0.454)
    )

    // En koyu zemin, mor-gri halka.
    static let neon = Theme(
        id: "neon", name: "Neon", isPremium: true,
        bgTop: ThemeColor(r: 0.047, g: 0.047, b: 0.067),
        bgBottom: ThemeColor(r: 0.098, g: 0.084, b: 0.124),
        ring: ThemeColor(r: 0.464, g: 0.521, b: 0.530),
        gate: ThemeColor(r: 0.854, g: 0.953, b: 0.872),
        orb: ThemeColor(r: 0.941, g: 0.945, b: 0.953),
        hazard: ThemeColor(r: 0.820, g: 0.286, b: 0.357),
        lumen: ThemeColor(r: 0.710, g: 0.580, b: 0.314),
        accent: ThemeColor(r: 0.515, g: 0.398, b: 0.550)
    )

    // Tamamen nötr gri — hiç renk sapması yok.
    static let karbon = Theme(
        id: "karbon", name: "Carbon", isPremium: true,
        bgTop: ThemeColor(r: 0.049, g: 0.049, b: 0.052),
        bgBottom: ThemeColor(r: 0.093, g: 0.093, b: 0.097),
        ring: ThemeColor(r: 0.505, g: 0.505, b: 0.508),
        gate: ThemeColor(r: 0.831, g: 0.965, b: 0.869),
        orb: ThemeColor(r: 0.941, g: 0.945, b: 0.953),
        hazard: ThemeColor(r: 0.820, g: 0.286, b: 0.357),
        lumen: ThemeColor(r: 0.710, g: 0.580, b: 0.314),
        accent: ThemeColor(r: 0.440, g: 0.451, b: 0.472)
    )

    // Gece mavisine çalan gri.
    static let kraliyet = Theme(
        id: "kraliyet", name: "Royal", isPremium: true,
        bgTop: ThemeColor(r: 0.045, g: 0.048, b: 0.066),
        bgBottom: ThemeColor(r: 0.086, g: 0.091, b: 0.119),
        ring: ThemeColor(r: 0.502, g: 0.505, b: 0.514),
        gate: ThemeColor(r: 0.837, g: 0.955, b: 0.904),
        orb: ThemeColor(r: 0.941, g: 0.945, b: 0.953),
        hazard: ThemeColor(r: 0.820, g: 0.286, b: 0.357),
        lumen: ThemeColor(r: 0.710, g: 0.580, b: 0.314),
        accent: ThemeColor(r: 0.477, g: 0.449, b: 0.386)
    )

    // Erik-gri, yumuşak.
    static let sakura = Theme(
        id: "sakura", name: "Sakura", isPremium: true,
        bgTop: ThemeColor(r: 0.054, g: 0.045, b: 0.056),
        bgBottom: ThemeColor(r: 0.104, g: 0.086, b: 0.100),
        ring: ThemeColor(r: 0.505, g: 0.501, b: 0.527),
        gate: ThemeColor(r: 0.858, g: 0.944, b: 0.906),
        orb: ThemeColor(r: 0.941, g: 0.945, b: 0.953),
        hazard: ThemeColor(r: 0.820, g: 0.286, b: 0.357),
        lumen: ThemeColor(r: 0.710, g: 0.580, b: 0.314),
        accent: ThemeColor(r: 0.486, g: 0.431, b: 0.451)
    )

    static let all: [Theme] = [.nebula, .gece, .safak, .orman, .mercan, .aurora,
                               .neon, .karbon, .kraliyet, .sakura]

    static func theme(id: String) -> Theme {
        all.first { $0.id == id } ?? .nebula
    }

    // MARK: Renk körlüğü modu

    /// Oyunun anlamı renge bağlı: yeşil kapı "git", kırmızı yay "ölürsün",
    /// sarı yıldız "topla". En yaygın renk körlüğü tam bu kırmızı–yeşil
    /// ayrımını siliyor. Bu mod açıkken zemin ve arka plan temanın kendisi
    /// olarak kalıyor, ama OYNANIŞI belirleyen dört renk Okabe–Ito
    /// paletinden sabit değerlerle değiştiriliyor: bu palet protanopi,
    /// döteranopi ve tritanopide de birbirinden ayrışır.
    ///
    /// Halka da nötr griye çekiliyor; yoksa kapının mavisi bazı temaların
    /// mavi halkasıyla karışıyor.
    var colorBlindSafe: Theme {
        Theme(
            id: id, name: name, isPremium: isPremium,
            bgTop: bgTop, bgBottom: bgBottom,
            ring: ThemeColor(r: 0.788, g: 0.808, b: 0.863),      // nötr gri-mavi
            gate: ThemeColor(r: 0.196, g: 0.588, b: 0.894),      // doygun mavi
            orb: ThemeColor(r: 1.0, g: 1.0, b: 1.0),
            hazard: ThemeColor(r: 0.902, g: 0.400, b: 0.055),    // vermilyon
            lumen: ThemeColor(r: 0.941, g: 0.894, b: 0.259),     // sarı
            accent: ThemeColor(r: 0.0, g: 0.694, b: 0.506),      // mavimsi yeşil
            isColorBlindSafe: true
        )
    }
}
