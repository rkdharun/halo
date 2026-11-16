import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Created before we activate, so it remembers the app we were launched from
        let windows = WindowManager.shared
        NSApp.activate(ignoringOtherApps: true)
        GlobalHotKey.shared.onPress = { windows.toggle() }
        GlobalHotKey.shared.register(AppSettings.shared.hotKey)
    }

    // Dock icon click while collapsed: reopen the existing note window instead of
    // letting SwiftUI create a second one
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        WindowManager.shared.expand()
        return false
    }

    // Hiding the note window behind the bubble counts as "last window closed" too
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !WindowManager.shared.isBubble
    }
}
