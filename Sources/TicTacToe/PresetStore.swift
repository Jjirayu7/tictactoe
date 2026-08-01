import Foundation

struct SoundPreset: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var audioPath: String?
    let isDefault: Bool
    var volumeDB: Float
    var speed: Float
    var eqLow: Float
    var eqMid: Float
    var eqHigh: Float

    private enum CodingKeys: String, CodingKey {
        case id, name, audioPath, isDefault, volumeDB, volume, speed, eqLow, eqMid, eqHigh
    }

    init(
        id: UUID = UUID(),
        name: String,
        audioPath: String? = nil,
        isDefault: Bool = false,
        volumeDB: Float = 0,
        speed: Float = 1,
        eqLow: Float = 0,
        eqMid: Float = 0,
        eqHigh: Float = 0
    ) {
        self.id = id
        self.name = name
        self.audioPath = audioPath
        self.isDefault = isDefault
        self.volumeDB = min(max(volumeDB, -60), 24)
        self.speed = min(max(speed, 0.5), 2)
        self.eqLow = min(max(eqLow, -12), 12)
        self.eqMid = min(max(eqMid, -12), 12)
        self.eqHigh = min(max(eqHigh, -12), 12)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            audioPath: try container.decodeIfPresent(String.self, forKey: .audioPath),
            isDefault: try container.decode(Bool.self, forKey: .isDefault),
            volumeDB: try container.decodeIfPresent(Float.self, forKey: .volumeDB)
                ?? Self.linearVolumeToDecibels(try container.decodeIfPresent(Float.self, forKey: .volume) ?? 1),
            speed: try container.decodeIfPresent(Float.self, forKey: .speed) ?? 1,
            eqLow: try container.decodeIfPresent(Float.self, forKey: .eqLow) ?? 0,
            eqMid: try container.decodeIfPresent(Float.self, forKey: .eqMid) ?? 0,
            eqHigh: try container.decodeIfPresent(Float.self, forKey: .eqHigh) ?? 0
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(audioPath, forKey: .audioPath)
        try container.encode(isDefault, forKey: .isDefault)
        try container.encode(volumeDB, forKey: .volumeDB)
        try container.encode(speed, forKey: .speed)
        try container.encode(eqLow, forKey: .eqLow)
        try container.encode(eqMid, forKey: .eqMid)
        try container.encode(eqHigh, forKey: .eqHigh)
    }

    private static func linearVolumeToDecibels(_ value: Float) -> Float {
        guard value > 0 else { return -60 }
        return min(max(20 * log10(value), -60), 24)
    }
}

enum PresetStoreError: LocalizedError {
    case defaultPresetIsReadOnly

    var errorDescription: String? {
        "Default preset ใช้เสียงจาก Resources และไม่สามารถแทนที่ได้"
    }
}

@MainActor
final class PresetStore {
    private(set) var presets: [SoundPreset] = []
    private(set) var selectedPresetID: UUID

    private let fileManager = FileManager.default
    private let defaultsKey = "selectedPresetID"
    private let directoryURL: URL
    private let metadataURL: URL

    init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directoryURL = appSupport.appendingPathComponent("tictactoe/Presets", isDirectory: true)
        metadataURL = directoryURL.appendingPathComponent("presets.json")

        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        var needsSave = false
        if let data = try? Data(contentsOf: metadataURL),
           let saved = try? JSONDecoder().decode([SoundPreset].self, from: data),
           !saved.isEmpty {
            presets = saved
        } else {
            presets = [SoundPreset(name: "Default", isDefault: true)]
            needsSave = true
        }

        if let index = presets.firstIndex(where: { $0.isDefault }),
           presets[index].name != "Default" || presets[index].audioPath != nil {
            presets[index].name = "Default"
            presets[index].audioPath = nil
            needsSave = true
        }

        let savedID = UserDefaults.standard.string(forKey: defaultsKey).flatMap(UUID.init)
        selectedPresetID = presets.contains { $0.id == savedID } ? (savedID ?? presets[0].id) : presets[0].id
        if needsSave { save() }
    }

    var selectedPreset: SoundPreset {
        presets.first(where: { $0.id == selectedPresetID }) ?? presets[0]
    }

    func select(_ id: UUID) {
        guard presets.contains(where: { $0.id == id }) else { return }
        selectedPresetID = id
        UserDefaults.standard.set(id.uuidString, forKey: defaultsKey)
    }

    func addPreset(named name: String = "New Preset") {
        let preset = SoundPreset(name: uniqueName(name))
        presets.append(preset)
        select(preset.id)
        save()
    }

    func renameSelected(to name: String) {
        guard let index = presets.firstIndex(where: { $0.id == selectedPresetID }), !presets[index].isDefault else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        presets[index].name = trimmed
        save()
    }

    func updateSelectedSoundSettings(volumeDB: Float, speed: Float, eqLow: Float, eqMid: Float, eqHigh: Float) {
        guard let index = presets.firstIndex(where: { $0.id == selectedPresetID }), !presets[index].isDefault else { return }
        presets[index].volumeDB = min(max(volumeDB, -60), 24)
        presets[index].speed = min(max(speed, 0.5), 2)
        presets[index].eqLow = min(max(eqLow, -12), 12)
        presets[index].eqMid = min(max(eqMid, -12), 12)
        presets[index].eqHigh = min(max(eqHigh, -12), 12)
        save()
    }

    func deleteSelected() {
        guard let index = presets.firstIndex(where: { $0.id == selectedPresetID }), !presets[index].isDefault else { return }
        let removed = presets.remove(at: index)
        if let path = removed.audioPath { try? fileManager.removeItem(atPath: path) }
        select(presets[0].id)
        save()
    }

    func replaceSelectedAudio(with sourceURL: URL) throws {
        let ext = sourceURL.pathExtension.lowercased()
        guard ["wav", "caf", "aiff", "aif", "m4a", "mp3"].contains(ext) else {
            throw CocoaError(.fileReadUnsupportedScheme)
        }
        guard let index = presets.firstIndex(where: { $0.id == selectedPresetID }) else { return }
        guard !presets[index].isDefault else { throw PresetStoreError.defaultPresetIsReadOnly }

        let destination = directoryURL.appendingPathComponent("\(selectedPresetID.uuidString).\(ext)")
        if let oldPath = presets[index].audioPath, oldPath != destination.path {
            try? fileManager.removeItem(atPath: oldPath)
        }
        try? fileManager.removeItem(at: destination)
        try fileManager.copyItem(at: sourceURL, to: destination)
        presets[index].audioPath = destination.path
        save()
    }

    func audioURLs(for preset: SoundPreset? = nil) -> [URL] {
        let target = preset ?? selectedPreset
        if target.isDefault {
            return (1...6).compactMap { Bundle.module.url(forResource: "click-\($0)", withExtension: "wav") }
        }
        if let path = target.audioPath { return [URL(fileURLWithPath: path)] }
        return []
    }

    private func uniqueName(_ requested: String) -> String {
        let base = requested.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "New Preset" : requested
        var candidate = base
        var suffix = 2
        while presets.contains(where: { $0.name.caseInsensitiveCompare(candidate) == .orderedSame }) {
            candidate = "\(base) \(suffix)"
            suffix += 1
        }
        return candidate
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        try? data.write(to: metadataURL, options: .atomic)
    }
}
