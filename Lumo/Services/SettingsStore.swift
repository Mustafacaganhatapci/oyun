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
    @Published var themeID: String {
        didSet { UserDefaults.standard.set(themeID, forKey: "lumo.settings.theme") }
    }

    var theme: Theme { Theme.theme(id: themeID) }

    init() {
        let d = UserDefaults.standard
        musicOn = d.object(forKey: "lumo.settings.music") as? Bool ?? true
        sfxOn = d.object(forKey: "lumo.settings.sfx") as? Bool ?? true
        hapticsOn = d.object(forKey: "lumo.settings.haptics") as? Bool ?? true
        themeID = d.string(forKey: "lumo.settings.theme") ?? Theme.nebula.id
        AudioEngine.shared.musicEnabled = musicOn
        AudioEngine.shared.sfxEnabled = sfxOn
        Haptics.shared.enabled = hapticsOn
    }
}
