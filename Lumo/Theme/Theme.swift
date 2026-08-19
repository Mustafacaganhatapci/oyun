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

    /// "Bu tur yakmaz" durumundaki tehlike yayının rengi. Kırmızının tam
    /// karşıtı olduğu için yeşil, ama BİLEREK sönük: müsamahalı hâl ekranda
    /// bağırmamalı, bağıran şey öldüren kırmızı olmalı. Parlak yeşilken bütün
    /// yaylar aynı anda öne fırlıyor ve ekran okunmaz hâle geliyordu.
    ///
    /// Renk körlüğü modunda yeşil tam da işe yaramayan renk; orada
    /// Okabe–Ito'nun mavimsi yeşiline geçiliyor.
    var hazardSafe: ThemeColor {
        isColorBlindSafe
        ? ThemeColor(r: 0.176, g: 0.478, b: 0.404)
        : ThemeColor(r: 0.318, g: 0.494, b: 0.337)
    }

    // Varsayılan tema. Arka plan bilerek DÜŞÜK doygunlukta: eski mor
    // (0.129, 0.043, 0.267) uzun oturumlarda göz yoruyordu. Kimlik aynı
    // kaldı, sadece morun kanı çekildi ve biraz maviye kaydırıldı.
    static let nebula = Theme(
        id: "nebula", name: "Nebula", isPremium: false,
        bgTop: ThemeColor(r: 0.047, g: 0.046, b: 0.071),
        bgBottom: ThemeColor(r: 0.082, g: 0.074, b: 0.110),
        ring: ThemeColor(r: 0.570, g: 0.560, b: 0.663),
        gate: ThemeColor(r: 0.347, g: 0.725, b: 0.633),
        orb: ThemeColor(r: 0.940, g: 0.940, b: 0.940),
        hazard: ThemeColor(r: 0.703, g: 0.302, b: 0.368),
        lumen: ThemeColor(r: 0.777, g: 0.678, b: 0.405),
        accent: ThemeColor(r: 0.519, g: 0.473, b: 0.697)
    )

    static let gece = Theme(
        id: "gece", name: "Night", isPremium: false,
        bgTop: ThemeColor(r: 0.029, g: 0.039, b: 0.057),
        bgBottom: ThemeColor(r: 0.056, g: 0.084, b: 0.113),
        ring: ThemeColor(r: 0.534, g: 0.625, b: 0.690),
        gate: ThemeColor(r: 0.472, g: 0.772, b: 0.567),
        orb: ThemeColor(r: 0.869, g: 0.915, b: 0.935),
        hazard: ThemeColor(r: 0.695, g: 0.278, b: 0.272),
        lumen: ThemeColor(r: 0.782, g: 0.696, b: 0.437),
        accent: ThemeColor(r: 0.397, g: 0.609, b: 0.715)
    )

    // Pembe/gül tonlu tema — ama halka SOĞUK (periwinkle) olduğu için
    // kırmızı tehlike net ayrışır, göz yormaz.
    static let safak = Theme(
        id: "safak", name: "Dawn", isPremium: true,
        bgTop: ThemeColor(r: 0.095, g: 0.069, b: 0.116),
        bgBottom: ThemeColor(r: 0.220, g: 0.138, b: 0.184),
        ring: ThemeColor(r: 0.659, g: 0.675, b: 0.742),
        gate: ThemeColor(r: 0.789, g: 0.715, b: 0.530),
        orb: ThemeColor(r: 0.936, g: 0.908, b: 0.882),
        hazard: ThemeColor(r: 0.699, g: 0.299, b: 0.292),
        lumen: ThemeColor(r: 0.774, g: 0.668, b: 0.373),
        accent: ThemeColor(r: 0.730, g: 0.543, b: 0.508)
    )

    // Orman: halka yeşil olduğundan kapı AÇIK CAMGÖBEĞİ — sarı yıldızlarla
    // ve yeşil halkayla karışmaz; kırmızı tehlike yeşilin tam karşıtıdır.
    static let orman = Theme(
        id: "orman", name: "Forest", isPremium: true,
        bgTop: ThemeColor(r: 0.041, g: 0.071, b: 0.065),
        bgBottom: ThemeColor(r: 0.082, g: 0.135, b: 0.115),
        ring: ThemeColor(r: 0.597, g: 0.706, b: 0.633),
        gate: ThemeColor(r: 0.450, g: 0.709, b: 0.765),
        orb: ThemeColor(r: 0.896, g: 0.937, b: 0.896),
        hazard: ThemeColor(r: 0.696, g: 0.288, b: 0.257),
        lumen: ThemeColor(r: 0.782, g: 0.696, b: 0.437),
        accent: ThemeColor(r: 0.483, g: 0.699, b: 0.564)
    )

    // Mercan/okyanus teması — halka AQUA (soğuk), kapı amber, tehlike canlı
    // mercan-kırmızısı: üçü de birbirinden net ayrışır.
    static let mercan = Theme(
        id: "mercan", name: "Coral", isPremium: true,
        bgTop: ThemeColor(r: 0.048, g: 0.066, b: 0.091),
        bgBottom: ThemeColor(r: 0.085, g: 0.152, b: 0.171),
        ring: ThemeColor(r: 0.560, g: 0.691, b: 0.692),
        gate: ThemeColor(r: 0.776, g: 0.664, b: 0.461),
        orb: ThemeColor(r: 0.937, g: 0.918, b: 0.896),
        hazard: ThemeColor(r: 0.695, g: 0.277, b: 0.295),
        lumen: ThemeColor(r: 0.783, g: 0.698, b: 0.468),
        accent: ThemeColor(r: 0.715, g: 0.493, b: 0.470)
    )

    // Aurora: yıldızlar tüm temalarda olduğu gibi AMBER (öğretici "sarıları
    // topla" der — yeşil yıldız kafa karıştırıyordu); tehlike net kırmızı.
    static let aurora = Theme(
        id: "aurora", name: "Aurora", isPremium: true,
        bgTop: ThemeColor(r: 0.034, g: 0.028, b: 0.062),
        bgBottom: ThemeColor(r: 0.061, g: 0.108, b: 0.122),
        ring: ThemeColor(r: 0.588, g: 0.727, b: 0.685),
        gate: ThemeColor(r: 0.612, g: 0.452, b: 0.734),
        orb: ThemeColor(r: 0.897, g: 0.938, b: 0.928),
        hazard: ThemeColor(r: 0.694, g: 0.271, b: 0.298),
        lumen: ThemeColor(r: 0.782, g: 0.696, b: 0.437),
        accent: ThemeColor(r: 0.465, g: 0.721, b: 0.648)
    )

    // Yüksek kontrastlı premium tema — neredeyse siyah zeminde elektrik renkleri;
    // her öğe (özellikle kırmızı tehlike) keskin ayrışır.
    static let neon = Theme(
        id: "neon", name: "Neon", isPremium: true,
        bgTop: ThemeColor(r: 0.018, g: 0.018, b: 0.033),
        bgBottom: ThemeColor(r: 0.041, g: 0.031, b: 0.060),
        ring: ThemeColor(r: 0.541, g: 0.709, b: 0.733),
        gate: ThemeColor(r: 0.452, g: 0.767, b: 0.508),
        orb: ThemeColor(r: 0.940, g: 0.940, b: 0.940),
        hazard: ThemeColor(r: 0.680, g: 0.193, b: 0.308),
        lumen: ThemeColor(r: 0.785, g: 0.729, b: 0.355),
        accent: ThemeColor(r: 0.608, g: 0.362, b: 0.681)
    )

    // Ultra yüksek kontrast / erişilebilirlik teması — beyaz halka, saf kırmızı
    // tehlike, yeşil kapı (trafik ışığı netliği); kömür siyahı zemin.
    static let karbon = Theme(
        id: "karbon", name: "Carbon", isPremium: true,
        bgTop: ThemeColor(r: 0.032, g: 0.032, b: 0.036),
        bgBottom: ThemeColor(r: 0.077, g: 0.077, b: 0.083),
        ring: ThemeColor(r: 0.795, g: 0.795, b: 0.807),
        gate: ThemeColor(r: 0.354, g: 0.755, b: 0.469),
        orb: ThemeColor(r: 0.548, g: 0.786, b: 0.908),
        hazard: ThemeColor(r: 0.682, g: 0.223, b: 0.223),
        lumen: ThemeColor(r: 0.769, g: 0.654, b: 0.309),
        accent: ThemeColor(r: 0.507, g: 0.532, b: 0.581)
    )

    // Lüks tema: gece mavisi kadife zemin, platin halka, zümrüt kapı,
    // altın vurgu — "kraliyet" havası, ama oyun okunurluğu tam.
    static let kraliyet = Theme(
        id: "kraliyet", name: "Royal", isPremium: true,
        bgTop: ThemeColor(r: 0.039, g: 0.044, b: 0.075),
        bgBottom: ThemeColor(r: 0.078, g: 0.087, b: 0.136),
        ring: ThemeColor(r: 0.719, g: 0.730, b: 0.758),
        gate: ThemeColor(r: 0.354, g: 0.690, b: 0.543),
        orb: ThemeColor(r: 0.938, g: 0.929, b: 0.897),
        hazard: ThemeColor(r: 0.692, g: 0.262, b: 0.284),
        lumen: ThemeColor(r: 0.774, g: 0.661, b: 0.407),
        accent: ThemeColor(r: 0.726, g: 0.643, b: 0.463)
    )

    // Sakura: mürekkep koyuluğunda erik zemin, lavanta halka, nane kapı,
    // kiraz çiçeği vurgusu — pembe yalnızca süslemede, tehlike net kırmızı.
    static let sakura = Theme(
        id: "sakura", name: "Sakura", isPremium: true,
        bgTop: ThemeColor(r: 0.073, g: 0.054, b: 0.078),
        bgBottom: ThemeColor(r: 0.137, g: 0.096, b: 0.128),
        ring: ThemeColor(r: 0.672, g: 0.659, b: 0.738),
        gate: ThemeColor(r: 0.463, g: 0.737, b: 0.615),
        orb: ThemeColor(r: 0.937, g: 0.909, b: 0.918),
        hazard: ThemeColor(r: 0.689, g: 0.252, b: 0.259),
        lumen: ThemeColor(r: 0.779, g: 0.682, b: 0.434),
        accent: ThemeColor(r: 0.750, g: 0.592, b: 0.650)
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
