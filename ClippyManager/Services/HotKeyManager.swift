import Carbon.HIToolbox
import Foundation

/// Registers global hotkeys via Carbon (sandbox-safe, no Accessibility needed):
///   • ⌃⌘V        → toggle the shelf
///   • ⌃⌘0…9      → paste the Nth most recent clip
private final class HotKeyDispatch {
    static let shared = HotKeyDispatch()
    var onToggle: (() -> Void)?
    var onRecent: ((Int) -> Void)?
}

private func carbonHotKeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    var hkID = EventHotKeyID()
    GetEventParameter(event, EventParamName(kEventParamDirectObject),
                      EventParamType(typeEventHotKeyID), nil,
                      MemoryLayout<EventHotKeyID>.size, nil, &hkID)
    if hkID.id == 1 {
        HotKeyDispatch.shared.onToggle?()
    } else if hkID.id >= 100 && hkID.id <= 109 {
        HotKeyDispatch.shared.onRecent?(Int(hkID.id) - 100)
    }
    return noErr
}

final class HotKeyManager {
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var handlerRef: EventHandlerRef?

    init(onToggle: @escaping () -> Void, onRecent: @escaping (Int) -> Void) {
        HotKeyDispatch.shared.onToggle = onToggle
        HotKeyDispatch.shared.onRecent = onRecent
    }

    func register() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(GetApplicationEventTarget(), carbonHotKeyHandler, 1, &spec, nil, &handlerRef)

        let mods = UInt32(controlKey | cmdKey)

        // ⌃⌘V → toggle
        registerKey(keyCode: UInt32(kVK_ANSI_V), modifiers: mods, id: 1)

        // ⌃⌘0…9 → recent
        let digitKeys: [(Int, Int)] = [
            (0, kVK_ANSI_0), (1, kVK_ANSI_1), (2, kVK_ANSI_2), (3, kVK_ANSI_3),
            (4, kVK_ANSI_4), (5, kVK_ANSI_5), (6, kVK_ANSI_6), (7, kVK_ANSI_7),
            (8, kVK_ANSI_8), (9, kVK_ANSI_9)
        ]
        for (digit, key) in digitKeys {
            registerKey(keyCode: UInt32(key), modifiers: mods, id: UInt32(100 + digit))
        }
    }

    private func registerKey(keyCode: UInt32, modifiers: UInt32, id: UInt32) {
        var hkID = EventHotKeyID()
        hkID.signature = fourCC("CLPY")
        hkID.id = id
        var ref: EventHotKeyRef?
        RegisterEventHotKey(keyCode, modifiers, hkID, GetApplicationEventTarget(), 0, &ref)
        hotKeyRefs.append(ref)
    }

    func unregister() {
        hotKeyRefs.forEach { if let r = $0 { UnregisterEventHotKey(r) } }
        hotKeyRefs.removeAll()
        if let h = handlerRef { RemoveEventHandler(h); handlerRef = nil }
        HotKeyDispatch.shared.onToggle = nil
        HotKeyDispatch.shared.onRecent = nil
    }

    deinit { unregister() }

    private func fourCC(_ s: String) -> FourCharCode {
        var result: FourCharCode = 0
        for ch in s.utf8 { result = (result << 8) | FourCharCode(ch) }
        return result
    }
}
