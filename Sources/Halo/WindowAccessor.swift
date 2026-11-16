import SwiftUI
import AppKit

struct WindowAccessor: NSViewRepresentable {
    let isPinned: Bool
    let opacity: Double

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        PassthroughView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            let c = context.coordinator

            // One-time window setup
            if !c.didSetup {
                c.didSetup = true
                window.styleMask.insert(.fullSizeContentView)
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.isMovableByWindowBackground = true
                window.standardWindowButton(.closeButton)?.isHidden = true
                window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                window.standardWindowButton(.zoomButton)?.isHidden = true
                window.minSize = NSSize(width: 50, height: 50)
                WindowManager.shared.attach(window)
            }

            // Only touch the window when a value actually changed — this runs on every
            // SwiftUI update, and re-setting alpha would cut the expand fade short.
            if c.opacity != self.opacity {
                c.opacity = self.opacity
                window.alphaValue = self.opacity
            }

            // Pin level
            if c.isPinned != self.isPinned {
                c.isPinned = self.isPinned
                window.level = self.isPinned ? .floating : .normal
                window.collectionBehavior = self.isPinned
                    ? [.canJoinAllSpaces, .fullScreenAuxiliary]
                    : [.managed, .participatesInCycle]
            }
        }
    }

    class Coordinator {
        var didSetup = false
        var opacity: Double? = nil
        var isPinned: Bool? = nil
    }

    private class PassthroughView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override var acceptsFirstResponder: Bool { false }
    }
}
