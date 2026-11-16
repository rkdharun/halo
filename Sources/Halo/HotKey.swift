import AppKit
import Carbon.HIToolbox

/// A key combination for the system-wide show/hide hotkey.
struct HotKeyShortcut: Equatable {
    var keyCode: UInt32
    var modifiers: NSEvent.ModifierFlags
    var key: String   // display name, e.g. "N", "Space"

    static let `default` = HotKeyShortcut(keyCode: UInt32(kVK_ANSI_N), modifiers: [.control, .option], key: "N")

    var displayString: String {
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option)  { s += "⌥" }
        if modifiers.contains(.shift)   { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        return s + key
    }

    fileprivate var carbonModifiers: UInt32 {
        var m = 0
        if modifiers.contains(.command) { m |= cmdKey }
        if modifiers.contains(.option)  { m |= optionKey }
        if modifiers.contains(.control) { m |= controlKey }
        if modifiers.contains(.shift)   { m |= shiftKey }
        return UInt32(m)
    }
}

extension HotKeyShortcut {
    /// Builds a shortcut from a key press; nil unless ⌘, ⌥ or ⌃ is held.
    init?(event: NSEvent) {
        let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !mods.isDisjoint(with: [.command, .option, .control]) else { return nil }
        let name = Self.specialKeys[Int(event.keyCode)]
            ?? (event.charactersIgnoringModifiers ?? "?").uppercased()
        self.init(keyCode: UInt32(event.keyCode), modifiers: mods, key: name)
    }

    private static let specialKeys: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫",
        kVK_ForwardDelete: "⌦", kVK_LeftArrow: "←", kVK_RightArrow: "→",
        kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]
}

/// System-wide hotkey via Carbon's RegisterEventHotKey: fires whichever app is frontmost
/// and, unlike an NSEvent global monitor, needs no Accessibility permission.
final class GlobalHotKey {
    static let shared = GlobalHotKey()

    var onPress: () -> Void = {}
    // False when the system refused the last combination (e.g. it's reserved)
    private(set) var isRegistered = false
    private var hotKeyRef: EventHotKeyRef?

    private init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        // Carbon delivers hotkey events on the main thread
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            GlobalHotKey.shared.onPress()
            return noErr
        }, 1, &spec, nil, nil)
    }

    func register(_ shortcut: HotKeyShortcut) {
        unregister()
        let id = EventHotKeyID(signature: OSType(0x4D4D454D), id: 1)  // 'MMEM'
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.carbonModifiers, id,
                                         GetApplicationEventTarget(), 0, &hotKeyRef)
        isRegistered = status == noErr
    }

    func unregister() {
        guard let ref = hotKeyRef else { return }
        UnregisterEventHotKey(ref)
        hotKeyRef = nil
        isRegistered = false
    }
}
