import ApplicationServices
import Foundation

final class KeyboardMonitor {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private let onKeyDown: () -> Void

    init(onKeyDown: @escaping () -> Void) {
        self.onKeyDown = onKeyDown
    }

    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    func start() {
        guard tap == nil, hasAccessibilityPermission else { return }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, _, userInfo in
                guard type == .keyDown, let userInfo else { return nil }
                Unmanaged<KeyboardMonitor>.fromOpaque(userInfo).takeUnretainedValue().onKeyDown()
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
    }

    deinit { stop() }
}
