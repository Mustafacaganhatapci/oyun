import Foundation
import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    @Published var musicOn: Bool {
        didSet {
            UserDefaults.standard.set(musicOn, forKey: "lumo.settings.music")
            AudioEngine.shared.musicEnabled = musicOn
        }
    }
    @Published var sfxOn: Bool {
        didSet {
            UserDefaults.standard.set(sfxOn, forKey: "lumo.settings.sfx")
            AudioEngine.shared.sfxEnabled = sfxOn
        }
    }
    @Published var hapticsOn: Bool {
        didSet {
            UserDefaults.standard.set(hapticsOn, forKey: "lumo.settings.haptics")
            Haptics.shared.enabled = hapticsOn
        }
    }
    /// Renk körlüğü modu — oynanışı belirleyen renkleri ayrışan bir palete
    /// çevirir ve tehlike yaylarına şekil ipucu ekler
    @Published var colorBlindOn: Bool {
        didSet { UserDefaults.standard.set(colorBlindOn, forKey: "lumo.settings.colorBlind") }
    }
    @Published var themeID: String {
        didSet { UserDefaults.standard.set(themeID, forKey: "lumo.settings.theme") }
    }
    @Published var orbStyleID: String {
        didSet { UserDefaults.standard.set(orbStyleID, forKey: "lumo.settings.orbStyle") }
    }
    /// Fotoğraflı küre görselini değiştirince arayüzü tazelemek için
    @Published var orbPhotoVersion = 0

    /// Oyunun her yerinde kullanılan tema. Renk körlüğü modu burada
    /// uygulanıyor: tek noktadan geçtiği için menü, HUD ve oyun alanı
    /// kendiliğinden aynı paleti görüyor.
    var theme: Theme {
        let base = Theme.theme(id: themeID)
        return colorBlindOn ? base.colorBlindSafe : base
    }
    var orbStyle: OrbStyle { OrbStyle.style(id: orbStyleID) }

    init() {
        let d = UserDefaults.standard
        musicOn = d.object(forKey: "lumo.settings.music") as? Bool ?? true
        sfxOn = d.object(forKey: "lumo.settings.sfx") as? Bool ?? true
        hapticsOn = d.object(forKey: "lumo.settings.haptics") as? Bool ?? true
        colorBlindOn = d.object(forKey: "lumo.settings.colorBlind") as? Bool ?? false
        themeID = d.string(forKey: "lumo.settings.theme") ?? Theme.nebula.id
        orbStyleID = d.string(forKey: "lumo.settings.orbStyle") ?? "classic"
        AudioEngine.shared.musicEnabled = musicOn
        AudioEngine.shared.sfxEnabled = sfxOn
        Haptics.shared.enabled = hapticsOn
    }
}
