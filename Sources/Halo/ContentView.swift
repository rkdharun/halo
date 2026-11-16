import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: NoteStore
    @ObservedObject private var settings = AppSettings.shared
    @State private var isPinned = true

    var body: some View {
        VStack(spacing: 0) {
            FloatingHeader(isPinned: $isPinned)
            Divider().opacity(0.4)
            EditorView(isPinned: $isPinned)
        }
        .background(Color(.windowBackgroundColor))
        .ignoresSafeArea()
        .background(WindowAccessor(isPinned: isPinned, opacity: settings.windowOpacity))
        .environmentObject(settings)
        .onReceive(NotificationCenter.default.publisher(for: .createNote)) { _ in
            store.createNote()
        }
        .onReceive(NotificationCenter.default.publisher(for: .selectPreviousNote)) { _ in
            store.selectPreviousNote()
        }
        .onReceive(NotificationCenter.default.publisher(for: .selectNextNote)) { _ in
            store.selectNextNote()
        }
    }
}
