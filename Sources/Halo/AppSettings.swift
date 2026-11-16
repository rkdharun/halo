import SwiftUI

enum BubblePosition: String, CaseIterable {
    case topLeft     = "Top Left"
    case topRight    = "Top Right"
    case bottomLeft  = "Bottom Left"
    case bottomRight = "Bottom Right"
}

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var bubblePosition: BubblePosition {
        didSet { UserDefaults.standard.set(bubblePosition.rawValue, forKey: "bubblePosition") }
    }
    @Published var windowOpacity: Double {
        didSet { UserDefaults.standard.set(windowOpacity, forKey: "windowOpacity") }
    }
    @Published var hotKey: HotKeyShortcut {
        didSet {
            UserDefaults.standard.set(Int(hotKey.keyCode), forKey: "hotKeyCode")
            UserDefaults.standard.set(Int(hotKey.modifiers.rawValue), forKey: "hotKeyModifiers")
            UserDefaults.standard.set(hotKey.key, forKey: "hotKeyName")
        }
    }

    private init() {
        // The app used to be called Mersal Memo (com.mersalmemo.app) — carry its settings over once
        if !UserDefaults.standard.bool(forKey: "didMigrateMersalMemo") {
            UserDefaults.standard.set(true, forKey: "didMigrateMersalMemo")
            if let legacy = UserDefaults(suiteName: "com.mersalmemo.app") {
                for key in ["bubblePosition", "windowOpacity", "hotKeyCode", "hotKeyModifiers", "hotKeyName"] {
                    if let value = legacy.object(forKey: key) { UserDefaults.standard.set(value, forKey: key) }
                }
            }
        }

        let raw = UserDefaults.standard.string(forKey: "bubblePosition") ?? ""
        bubblePosition = BubblePosition(rawValue: raw) ?? .topRight
        let op = UserDefaults.standard.double(forKey: "windowOpacity")
        windowOpacity = op > 0 ? op : 1.0
        if let name = UserDefaults.standard.string(forKey: "hotKeyName") {
            hotKey = HotKeyShortcut(
                keyCode: UInt32(UserDefaults.standard.integer(forKey: "hotKeyCode")),
                modifiers: NSEvent.ModifierFlags(rawValue: UInt(UserDefaults.standard.integer(forKey: "hotKeyModifiers"))),
                key: name)
        } else {
            hotKey = .default
        }
    }
}
