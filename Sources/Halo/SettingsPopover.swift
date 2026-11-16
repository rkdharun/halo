import SwiftUI
import Carbon.HIToolbox

struct SettingsPopover: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 0) {
            Text("Settings")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 8)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Bubble Position")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                VStack(spacing: 5) {
                    HStack(spacing: 5) {
                        posBtn(.topLeft)
                        posBtn(.topRight)
                    }
                    HStack(spacing: 5) {
                        posBtn(.bottomLeft)
                        posBtn(.bottomRight)
                    }
                }
            }
            .padding(12)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Opacity")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(settings.windowOpacity * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Slider(value: $settings.windowOpacity, in: 0.3...1.0, step: 0.05)
                    .accentColor(.orange)
            }
            .padding(12)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Show / Hide Shortcut")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                ShortcutRecorder(shortcut: $settings.hotKey)
            }
            .padding(12)
        }
        .frame(width: 210)
    }

    private func posBtn(_ pos: BubblePosition) -> some View {
        Button { settings.bubblePosition = pos } label: {
            Text(pos.rawValue)
                .font(.system(size: 10, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(settings.bubblePosition == pos
                              ? Color.orange.opacity(0.18)
                              : Color.secondary.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(settings.bubblePosition == pos ? Color.orange.opacity(0.6) : Color.clear,
                                lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .foregroundColor(settings.bubblePosition == pos ? .orange : .primary)
    }
}

/// Click, then press the new combination. Esc cancels. The global hotkey is paused while
/// recording so pressing the current combination records it instead of firing it.
private struct ShortcutRecorder: View {
    @Binding var shortcut: HotKeyShortcut
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button { isRecording ? stop() : start() } label: {
            Text(isRecording ? "Type shortcut…" : shortcut.displayString)
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isRecording ? Color.orange.opacity(0.18) : Color.secondary.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(isRecording ? Color.orange.opacity(0.6) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .foregroundColor(isRecording ? .orange : .primary)
        .onDisappear { stop() }

        if !isRecording && !GlobalHotKey.shared.isRegistered {
            Text("This shortcut isn't available — try another.")
                .font(.system(size: 10))
                .foregroundColor(.red)
        }
    }

    private func start() {
        GlobalHotKey.shared.unregister()
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                stop()
            } else if let recorded = HotKeyShortcut(event: event) {
                shortcut = recorded
                stop()
            } else {
                NSSound.beep()  // needs ⌘, ⌥ or ⌃
            }
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
        GlobalHotKey.shared.register(shortcut)
    }
}
