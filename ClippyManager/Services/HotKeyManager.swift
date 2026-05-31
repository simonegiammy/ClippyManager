import Carbon.HIToolbox
import Foundation

// File-scope callback — Carbon requires a plain C function pointer
private var _hotKeyCallback: (() -> Void)?

private func carbonHotKeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    _hotKeyCallback?()
    return noErr
}

final class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    init(callback: @escaping () -> Void) {
        _hotKeyCallback = callback
    }

    func register() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            carbonHotKeyHandler,
            1,
            &eventSpec,
            nil,
            &handlerRef
        )

        // ⌘⇧V
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = fourCC("CLPY")
        hotKeyID.id = 1

        RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref); hotKeyRef = nil }
        if let h = handlerRef  { RemoveEventHandler(h); handlerRef = nil }
        _hotKeyCallback = nil
    }

    deinit { unregister() }

    private func fourCC(_ s: String) -> FourCharCode {
        var result: FourCharCode = 0
        for ch in s.utf8 { result = (result << 8) | FourCharCode(ch) }
        return result
    }
}
