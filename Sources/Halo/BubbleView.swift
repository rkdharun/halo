import SwiftUI
import AppKit

struct BubbleView: View {
    @State private var isHovered = false
    @State private var pulse: CGFloat = 1.0
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .fill(Color.orange.opacity(0.22))
                .scaleEffect(pulse)
                .animation(
                    .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                    value: pulse
                )

            // Main circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.orange, Color(red: 1, green: 0.5, blue: 0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .orange.opacity(0.45), radius: 8, y: 3)
                .padding(6)

            // Icon
            Image(systemName: isHovered ? "arrow.up.left.and.arrow.down.right" : "note.text")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .scaleEffect(appeared ? (isHovered ? 1.08 : 1.0) : 0.3)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: isHovered)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onHover { isHovered = $0 }
        .onAppear {
            pulse = 1.15
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { appeared = true }
        }
    }
}

/// Borderless, non-activating panel that shows the bubble. It floats over every app
/// and takes the very first click, so a single click always expands the note.
final class BubblePanel: NSPanel {
    static let size = NSSize(width: 64, height: 64)
    private let onClick: () -> Void

    init(onClick: @escaping () -> Void) {
        self.onClick = onClick
        super.init(contentRect: NSRect(origin: .zero, size: Self.size),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        // Above .floating: other apps' floating panels share that level and can stack over the bubble
        level = .statusBar
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { false }

    func show(at position: BubblePosition, on screen: NSScreen?) {
        let visible = (screen ?? NSScreen.screens[0]).visibleFrame
        setFrame(position.frame(sz: Self.size, in: visible, margin: 20), display: false)
        // Fresh view each time so hover state resets and the pop-in replays
        contentView = BubbleClickView(onClick: onClick)
        orderFrontRegardless()
    }
}

/// Handles clicks and drags for the bubble in AppKit rather than SwiftUI: it accepts
/// the first mouse-down even while another app is active, and tells a click (expand)
/// apart from a drag (move the bubble).
private final class BubbleClickView: NSView {
    private let onClick: () -> Void
    private var dragStart: NSPoint?
    private var originAtDragStart = NSPoint.zero
    private var isDragging = false

    init(onClick: @escaping () -> Void) {
        self.onClick = onClick
        super.init(frame: NSRect(origin: .zero, size: BubblePanel.size))
        let host = NSHostingView(rootView: BubbleView())
        host.frame = bounds
        host.autoresizingMask = [.width, .height]
        addSubview(host)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // Route every click here instead of into the SwiftUI view
    override func hitTest(_ point: NSPoint) -> NSView? { frame.contains(point) ? self : nil }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        dragStart = NSEvent.mouseLocation
        originAtDragStart = window?.frame.origin ?? .zero
        isDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart, let window else { return }
        let p = NSEvent.mouseLocation
        let dx = p.x - start.x, dy = p.y - start.y
        // A little jitter during a click shouldn't turn it into a drag
        guard isDragging || hypot(dx, dy) > 3 else { return }
        isDragging = true
        window.setFrameOrigin(NSPoint(x: originAtDragStart.x + dx, y: originAtDragStart.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        if dragStart != nil && !isDragging { onClick() }
        dragStart = nil
    }
}
