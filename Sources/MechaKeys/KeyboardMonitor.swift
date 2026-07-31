import ApplicationServices
import Foundation

final class KeyboardMonitor {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private let onKeyDown: () -> Void
    private var currentModifierFlags: CGEventFlags = []

    init(onKeyDown: @escaping () -> Void) {
        self.onKeyDown = onKeyDown
    }

    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    func start() {
        guard tap == nil, hasAccessibilityPermission else { return }
        let mask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)
        )
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return nil }
                let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(userInfo).takeUnretainedValue()

                switch type {
                case .keyDown:
                    monitor.onKeyDown()
                case .flagsChanged:
                    monitor.handleModifierFlagsChanged(event: event)
                default:
                    break
                }
                return nil
            },
            userInfo: pointer
        )
        guard let tap else {
            NSLog("tictactoe: unable to create keyboard event tap; Accessibility permission may need a restart")
            return
        }
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes) }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        source = nil
        tap = nil
        currentModifierFlags = []
    }

    private func handleModifierFlagsChanged(event: CGEvent?) {
        guard let event else { return }
        let modifierMask: CGEventFlags = [
            .maskCommand,
            .maskShift,
            .maskAlphaShift,
            .maskAlternate,
            .maskControl,
            .maskSecondaryFn
        ]
        let nextModifierFlags = event.flags.intersection(modifierMask)
        let newlyPressedFlags = nextModifierFlags.subtracting(currentModifierFlags)
        currentModifierFlags = nextModifierFlags

        if !newlyPressedFlags.isEmpty {
            onKeyDown()
        }
    }

    deinit { stop() }
}
