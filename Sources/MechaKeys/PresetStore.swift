import Foundation

struct SoundPreset: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var audioPath: String?
    let isDefault: Bool

    init(id: UUID = UUID(), name: String, audioPath: String? = nil, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.audioPath = audioPath
        self.isDefault = isDefault
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

    func deleteSelected() {
        guard let index = presets.firstIndex(where: { $0.id == selectedPresetID }), !presets[index].isDefault else { return }
        let removed = presets.remove(at: index)
        if let path = removed.audioPath { try? fileManager.removeItem(atPath: path) }
        select(presets[0].id)
        save()
    }

    func replaceSelectedAudio(with sourceURL: URL) throws {
        let ext = sourceURL.pathExtension.lowercased()
        guard ["wav", "caf", "aiff", "aif", "m4a"].contains(ext) else {
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
