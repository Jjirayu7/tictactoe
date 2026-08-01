import AppKit
import ApplicationServices
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var mainWindow: NSWindow?
    private var keyboardMonitor: KeyboardMonitor!
    private var permissionTimer: Timer?
    private var globalShortcutMonitor: Any?
    private lazy var presetStore = PresetStore()
    private var soundEngine: ClickSoundEngine?
    private var settings = AppSettings()

    private weak var permissionDetailLabel: NSTextField?
    private weak var permissionButton: NSButton?
    private var lastPermissionState: Bool?
    private var presetPopup: NSPopUpButton?
    private var presetStatusLabel: NSTextField?
    private var deletePresetButton: NSButton?
    private var renamePresetButton: NSButton?
    private var importSoundButton: NSButton?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMenu()
        loadSelectedAudio()
        installGlobalShortcut()
        showMainWindow()
        keyboardMonitor.start()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.keyboardMonitor.start()
            self.refreshPermissionUI()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        keyboardMonitor.stop()
        permissionTimer?.invalidate()
        if let globalShortcutMonitor { NSEvent.removeMonitor(globalShortcutMonitor) }
    }

    private func configureMenu() {
        keyboardMonitor = KeyboardMonitor { [weak self] in
            guard let self, self.settings.isEnabled, !self.settings.privacyMode else { return }
            self.soundEngine?.play()
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "⌨︎"
        rebuildMenu()
    }

    private func loadSelectedAudio() {
        let urls = presetStore.audioURLs()
        if soundEngine == nil {
            soundEngine = ClickSoundEngine(audioURLs: urls)
        } else {
            soundEngine?.load(audioURLs: urls)
        }
        soundEngine?.setVolume(settings.volume)
    }

    private func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 360),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "tictactoe"
        window.center()

        let view = NSView(frame: window.contentView?.bounds ?? .zero)
        view.autoresizingMask = [.width, .height]

        let title = NSTextField(labelWithString: "tictactoe")
        title.font = .systemFont(ofSize: 24, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false

        let detail = NSTextField(labelWithString: keyboardMonitor.hasAccessibilityPermission
            ? "กำลังทำงาน — เสียงจะเล่นตาม preset ที่เลือก"
            : "ต้องอนุญาต Accessibility เพื่อเริ่มตรวจจับปุ่ม")
        detail.alignment = .center
        detail.translatesAutoresizingMaskIntoConstraints = false
        permissionDetailLabel = detail

        let permissionButton = NSButton(title: "เปิด Accessibility Settings", target: self, action: #selector(openAccessibilitySettings))
        permissionButton.translatesAutoresizingMaskIntoConstraints = false
        permissionButton.isHidden = keyboardMonitor.hasAccessibilityPermission
        self.permissionButton = permissionButton
        lastPermissionState = keyboardMonitor.hasAccessibilityPermission

        let presetLabel = NSTextField(labelWithString: "Sound preset")
        presetLabel.translatesAutoresizingMaskIntoConstraints = false

        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.target = self
        popup.action = #selector(presetChanged(_:))
        popup.translatesAutoresizingMaskIntoConstraints = false
        presetPopup = popup

        let addButton = NSButton(title: "เพิ่ม preset", target: self, action: #selector(addPreset))
        addButton.translatesAutoresizingMaskIntoConstraints = false
        let renameButton = NSButton(title: "เปลี่ยนชื่อ", target: self, action: #selector(renamePreset))
        renameButton.translatesAutoresizingMaskIntoConstraints = false
        renamePresetButton = renameButton
        let deleteButton = NSButton(title: "ลบ", target: self, action: #selector(deletePreset))
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deletePresetButton = deleteButton
        let importButton = NSButton(title: "นำเข้าเสียง", target: self, action: #selector(importSound))
        importButton.translatesAutoresizingMaskIntoConstraints = false
        importSoundButton = importButton

        let status = NSTextField(labelWithString: "")
        status.alignment = .center
        status.textColor = .secondaryLabelColor
        status.translatesAutoresizingMaskIntoConstraints = false
        presetStatusLabel = status

        [title, detail, permissionButton, presetLabel, popup, addButton, renameButton, deleteButton, importButton, status].forEach(view.addSubview)

        NSLayoutConstraint.activate([
            title.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            title.topAnchor.constraint(equalTo: view.topAnchor, constant: 22),
            detail.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            detail.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 12),
            detail.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            detail.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            permissionButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            permissionButton.topAnchor.constraint(equalTo: detail.bottomAnchor, constant: 12),
            presetLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 42),
            presetLabel.topAnchor.constraint(equalTo: permissionButton.bottomAnchor, constant: 24),
            popup.leadingAnchor.constraint(equalTo: presetLabel.trailingAnchor, constant: 16),
            popup.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -42),
            popup.centerYAnchor.constraint(equalTo: presetLabel.centerYAnchor),
            addButton.leadingAnchor.constraint(equalTo: popup.leadingAnchor),
            addButton.topAnchor.constraint(equalTo: popup.bottomAnchor, constant: 14),
            renameButton.leadingAnchor.constraint(equalTo: addButton.trailingAnchor, constant: 8),
            renameButton.centerYAnchor.constraint(equalTo: addButton.centerYAnchor),
            deleteButton.leadingAnchor.constraint(equalTo: renameButton.trailingAnchor, constant: 8),
            deleteButton.centerYAnchor.constraint(equalTo: addButton.centerYAnchor),
            importButton.trailingAnchor.constraint(equalTo: popup.trailingAnchor),
            importButton.centerYAnchor.constraint(equalTo: addButton.centerYAnchor),
            status.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 42),
            status.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -42),
            status.topAnchor.constraint(equalTo: addButton.bottomAnchor, constant: 14)
        ])

        window.contentView = view
        window.isReleasedWhenClosed = false
        mainWindow = window
        refreshPresetUI()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func refreshPermissionUI() {
        let granted = keyboardMonitor.hasAccessibilityPermission
        guard granted != lastPermissionState else { return }
        lastPermissionState = granted
        permissionDetailLabel?.stringValue = granted
            ? "กำลังทำงาน — เสียงจะเล่นตาม preset ที่เลือก"
            : "ต้องอนุญาต Accessibility เพื่อเริ่มตรวจจับปุ่ม"
        permissionButton?.isHidden = granted
        rebuildMenu()
    }

    private func refreshPresetUI() {
        guard let popup = presetPopup else { return }
        popup.removeAllItems()
        for preset in presetStore.presets {
            popup.addItem(withTitle: preset.name)
            popup.lastItem?.representedObject = preset.id.uuidString
        }
        if let index = presetStore.presets.firstIndex(where: { $0.id == presetStore.selectedPresetID }) {
            popup.selectItem(at: index)
        }
        let selected = presetStore.selectedPreset
        deletePresetButton?.isEnabled = !selected.isDefault
        renamePresetButton?.isEnabled = !selected.isDefault
        importSoundButton?.isEnabled = !selected.isDefault
        presetStatusLabel?.stringValue = presetStore.audioURLs().isEmpty
            ? "ไม่พบไฟล์เสียงของ preset นี้"
            : "ไฟล์เสียงพร้อมใช้งาน"
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let toggle = NSMenuItem(title: settings.isEnabled ? "Disable Sounds" : "Enable Sounds", action: #selector(toggleEnabled), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        let privacy = NSMenuItem(title: "Privacy Mode: \(settings.privacyMode ? "On" : "Off")", action: #selector(togglePrivacy), keyEquivalent: "")
        privacy.target = self
        menu.addItem(privacy)
        menu.addItem(.separator())
        let volumeItem = NSMenuItem()
        let volumeView = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 32))
        let volumeLabel = NSTextField(labelWithString: "Volume")
        volumeLabel.frame = NSRect(x: 10, y: 8, width: 54, height: 16)
        volumeLabel.font = .systemFont(ofSize: 12)
        let volumeSlider = NSSlider(value: Double(settings.volume), minValue: 0, maxValue: 1, target: self, action: #selector(volumeSliderChanged(_:)))
        volumeSlider.frame = NSRect(x: 68, y: 5, width: 142, height: 22)
        volumeSlider.isContinuous = true
        volumeView.addSubview(volumeLabel)
        volumeView.addSubview(volumeSlider)
        volumeItem.view = volumeView
        menu.addItem(volumeItem)
        let launch = NSMenuItem(title: "Launch at Login: \(loginItemEnabled ? "On" : "Off")", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launch.target = self
        menu.addItem(launch)
        menu.addItem(.separator())
        let permission = NSMenuItem(title: keyboardMonitor.hasAccessibilityPermission ? "Accessibility: Granted" : "Grant Accessibility Permission…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        permission.target = self
        menu.addItem(permission)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit tictactoe", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    private var loginItemEnabled: Bool { SMAppService.mainApp.status == .enabled }

    private func installGlobalShortcut() {
        globalShortcutMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 40,
                  event.modifierFlags.intersection([.control, .option]) == [.control, .option] else { return }
            self?.toggleEnabled()
        }
    }

    @objc private func presetChanged(_ sender: NSPopUpButton) {
        guard let idString = sender.selectedItem?.representedObject as? String,
              let id = UUID(uuidString: idString) else { return }
        presetStore.select(id)
        loadSelectedAudio()
        refreshPresetUI()
    }

    @objc private func addPreset() {
        presetStore.addPreset()
        loadSelectedAudio()
        refreshPresetUI()
    }

    @objc private func renamePreset() {
        let alert = NSAlert()
        alert.messageText = "เปลี่ยนชื่อ preset"
        let field = NSTextField(string: presetStore.selectedPreset.name)
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: "บันทึก")
        alert.addButton(withTitle: "ยกเลิก")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        presetStore.renameSelected(to: field.stringValue)
        refreshPresetUI()
    }

    @objc private func deletePreset() {
        presetStore.deleteSelected()
        loadSelectedAudio()
        refreshPresetUI()
    }

    @objc private func importSound() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedFileTypes = ["wav", "caf", "aiff", "aif", "m4a"]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try presetStore.replaceSelectedAudio(with: url)
            loadSelectedAudio()
            refreshPresetUI()
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    @objc private func toggleEnabled() {
        settings.isEnabled.toggle()
        rebuildMenu()
    }

    @objc private func togglePrivacy() {
        settings.privacyMode.toggle()
        rebuildMenu()
    }

    @objc private func volumeSliderChanged(_ sender: NSSlider) {
        settings.volume = Float(sender.doubleValue)
        soundEngine?.setVolume(settings.volume)
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if loginItemEnabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch {
            NSLog("Launch at Login could not be changed: \(error.localizedDescription)")
        }
        rebuildMenu()
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

@main
struct tictactoeMain {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.finishLaunching()
        application.run()
    }
}
