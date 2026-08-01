import Foundation
import SwiftUI
import UIKit

/// Bir küre stilinin nasıl açıldığı.
enum OrbUnlock: Equatable {
    case free               // baştan açık
    case stars(Int)         // toplanan yıldızlarla satın alınır
    case premium            // Orbeon Premium (IAP) ile açılır
}

/// Kürenin (oyuncu "karakterinin") görsel stili.
/// Bazıları ücretsiz, bazıları yıldızla alınır, biri premium — hepsi kozmetiktir.
struct OrbStyle: Identifiable, Equatable {
    enum Kind: String {
        case classic    // klasik ışık küresi
        case star       // dönen beş köşeli yıldız
        case crystal    // altıgen kristal
        case comet      // uzun izli kuyruklu yıldız
        case rainbow    // renk değiştiren küre
        case ring       // içi boş halka
        case diamond    // dönen elmas (dörtgen)
        case flame      // titreşen ateş küresi
        case pixel      // kare "piksel" küre
        case photo      // kürenin içinde oyuncunun kendi fotoğrafı
        case bubble     // titreşen sabun kabarcığı
        case heart      // kalp atışı gibi nabız atan kalp
        case firefly    // yanıp sönen kuyruklu ateşböceği
        case cloud      // yumuşakça sallanan küçük bulut
    }

    let id: String
    /// İngilizce ad — aynı zamanda yerelleştirme anahtarı
    let name: String
    let unlock: OrbUnlock
    let kind: Kind

    var localizedName: String { String(localized: String.LocalizationValue(name)) }
    var isPremium: Bool { unlock == .premium }
    var starCost: Int? { if case .stars(let n) = unlock { return n }; return nil }

    static let all: [OrbStyle] = [
        OrbStyle(id: "classic", name: "Light",   unlock: .free,        kind: .classic),
        OrbStyle(id: "star",    name: "Star",    unlock: .free,        kind: .star),
        OrbStyle(id: "ring",    name: "Ring",    unlock: .stars(15),   kind: .ring),
        OrbStyle(id: "bubble",  name: "Bubble",  unlock: .stars(20),   kind: .bubble),
        OrbStyle(id: "crystal", name: "Crystal", unlock: .stars(25),   kind: .crystal),
        OrbStyle(id: "pixel",   name: "Pixel",   unlock: .stars(40),   kind: .pixel),
        OrbStyle(id: "heart",   name: "Heart",   unlock: .stars(45),   kind: .heart),
        OrbStyle(id: "comet",   name: "Comet",   unlock: .stars(55),   kind: .comet),
        OrbStyle(id: "diamond", name: "Diamond", unlock: .stars(75),   kind: .diamond),
        OrbStyle(id: "firefly", name: "Firefly", unlock: .stars(90),   kind: .firefly),
        OrbStyle(id: "flame",   name: "Flame",   unlock: .stars(100),  kind: .flame),
        OrbStyle(id: "rainbow", name: "Rainbow", unlock: .stars(130),  kind: .rainbow),
        OrbStyle(id: "cloud",   name: "Cloud",   unlock: .stars(150),  kind: .cloud),
        OrbStyle(id: "photo",   name: "Photo",   unlock: .premium,     kind: .photo)
    ]

    /// Yıldızla satın alınabilen stiller (mağazada listelenir)
    static var starPurchasable: [OrbStyle] { all.filter { $0.starCost != nil } }

    static func style(id: String) -> OrbStyle {
        all.first { $0.id == id } ?? all[0]
    }
}

/// Premium "fotoğraflı küre" için kullanıcı fotoğrafını saklar.
/// Fotoğraf cihazda kalır, hiçbir yere yüklenmez.
enum OrbPhotoStore {
    private static var url: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("lumo_orb_photo.png")
    }

    static var exists: Bool { FileManager.default.fileExists(atPath: url.path) }

    static func load() -> UIImage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// Kare-kırpıp 256px'e küçülterek kaydeder (küre içinde dairesel maskelenir)
    @discardableResult
    static func save(_ image: UIImage) -> Bool {
        let side = min(image.size.width, image.size.height)
        let origin = CGPoint(x: (image.size.width - side) / 2,
                             y: (image.size.height - side) / 2)
        let target: CGFloat = 256

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: target, height: target), format: format)
        let rendered = renderer.image { _ in
            let drawRect = CGRect(x: -origin.x * (target / side),
                                  y: -origin.y * (target / side),
                                  width: image.size.width * (target / side),
                                  height: image.size.height * (target / side))
            image.draw(in: drawRect)
        }
        guard let data = rendered.pngData() else { return false }
        return (try? data.write(to: url)) != nil
    }

    static func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}
