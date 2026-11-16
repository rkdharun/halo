import AppKit

/// Switches between the note window and the bubble. The bubble lives in its own small
/// panel, so collapsing only hides the note window — the editor is never resized or
/// rebuilt, which keeps expanding instant and preserves the cursor and unsaved text.
final class WindowManager {
    static let shared = WindowManager()

    private(set) var isBubble = false
    private weak var noteWindow: NSWindow?
    private lazy var bubblePanel = BubblePanel { [weak self] in self?.expand() }
    // Most recent other frontmost app — focus goes back to it on collapse
    private var previousApp: NSRunningApplication?

    private init() {
        if let front = NSWorkspace.shared.frontmostApplication, front != .current { previousApp = front }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app != NSRunningApplication.current else { return }
            self?.previousApp = app
        }
    }

    func attach(_ window: NSWindow) {
        noteWindow = window
    }

    /// Hotkey: bring the note forward, or tuck it back into the bubble if it's already in front.
    func toggle() {
        if !isBubble, NSApp.isActive, noteWindow?.isVisible == true {
            collapse()
        } else {
            expand()
        }
    }

    func expand() {
        guard let window = noteWindow else { return }
        isBubble = false
        bubblePanel.orderOut(nil)
        if !window.isVisible { window.alphaValue = 0 }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            window.animator().alphaValue = AppSettings.shared.windowOpacity
        }
    }

    func collapse() {
        guard let window = noteWindow, !isBubble, NSApp.modalWindow == nil else { return }
        isBubble = true
        bubblePanel.show(at: AppSettings.shared.bubblePosition, on: window.screen ?? NSScreen.main)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.1
            window.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            // Reopened before the fade finished — leave it on screen
            guard self?.isBubble == true else { return }
            window.orderOut(nil)
        }
        if NSApp.isActive { previousApp?.activate(options: []) }
    }
}

extension BubblePosition {
    func frame(sz: NSSize, in visible: NSRect, margin: CGFloat) -> NSRect {
        switch self {
        case .topLeft:
            return NSRect(x: visible.minX + margin,
                          y: visible.maxY - sz.height - margin,
                          width: sz.width, height: sz.height)
        case .topRight:
            return NSRect(x: visible.maxX - sz.width - margin,
                          y: visible.maxY - sz.height - margin,
                          width: sz.width, height: sz.height)
        case .bottomLeft:
            return NSRect(x: visible.minX + margin,
                          y: visible.minY + margin,
                          width: sz.width, height: sz.height)
        case .bottomRight:
            return NSRect(x: visible.maxX - sz.width - margin,
                          y: visible.minY + margin,
                          width: sz.width, height: sz.height)
        }
    }
}
