import Foundation
import SwiftUI
import UIKit

/// Bir küre stilinin nasıl açıldığı.
enum OrbUnlock: Equatable {
    case free               // baştan açık
    case stars(Int)         // toplanan yıldızlarla satın alınır
    case premium            // LUMO Premium (IAP) ile açılır
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
        case photo      // kürenin içinde oyuncunun kendi fotoğrafı
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
        OrbStyle(id: "crystal", name: "Crystal", unlock: .stars(20),   kind: .crystal),
        OrbStyle(id: "comet",   name: "Comet",   unlock: .stars(45),   kind: .comet),
        OrbStyle(id: "rainbow", name: "Rainbow", unlock: .stars(80),   kind: .rainbow),
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
