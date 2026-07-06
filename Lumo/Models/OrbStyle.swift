import Foundation
import SwiftUI
import UIKit

/// Kürenin (oyuncu "karakterinin") görsel stili.
/// 2 stil ücretsiz, 4 stil premium — hepsi tamamen kozmetiktir.
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
    let isPremium: Bool
    let kind: Kind

    var localizedName: String { String(localized: String.LocalizationValue(name)) }

    static let all: [OrbStyle] = [
        OrbStyle(id: "classic", name: "Light", isPremium: false, kind: .classic),
        OrbStyle(id: "star", name: "Star", isPremium: false, kind: .star),
        OrbStyle(id: "crystal", name: "Crystal", isPremium: true, kind: .crystal),
        OrbStyle(id: "comet", name: "Comet", isPremium: true, kind: .comet),
        OrbStyle(id: "rainbow", name: "Rainbow", isPremium: true, kind: .rainbow),
        OrbStyle(id: "photo", name: "Photo", isPremium: true, kind: .photo)
    ]

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
