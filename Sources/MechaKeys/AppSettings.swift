import Foundation

enum SoundProfile: String, CaseIterable, Identifiable {
    case clicky

    var id: String { rawValue }
    var title: String { "Clicky" }
}

struct AppSettings {
    var isEnabled: Bool = true
    var volume: Float = 0.65
    var soundProfile: SoundProfile = .clicky
    var maxVoices: Int = 8
    var privacyMode: Bool = false

    init(isEnabled: Bool = true, volume: Float = 0.65, soundProfile: SoundProfile = .clicky, maxVoices: Int = 8, privacyMode: Bool = false) {
        self.isEnabled = isEnabled
        self.volume = min(max(volume, 0), 1)
        self.soundProfile = soundProfile
        self.maxVoices = min(max(maxVoices, 1), 8)
        self.privacyMode = privacyMode
    }
}
