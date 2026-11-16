import AppKit

class NoteStore: ObservableObject {
    @Published var notes: [Note] = []
    @Published var selectedNoteId: UUID?

    // In-flight edits: not @Published so typing doesn't trigger view re-renders
    private var pendingContent: [UUID: String] = [:]
    private var saveWorkItem: DispatchWorkItem?
    private var titleSaveWorkItem: DispatchWorkItem?
    private let storageURL: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("Halo")
        // The app used to be called Mersal Memo — carry its notes over on first launch
        let legacyDir = support.appendingPathComponent("MersalMemo")
        var migrated = false
        if !FileManager.default.fileExists(atPath: dir.path),
           FileManager.default.fileExists(atPath: legacyDir.path) {
            migrated = (try? FileManager.default.moveItem(at: legacyDir, to: dir)) != nil
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("notes.json")
        load()

        // Pasted images are linked by absolute path — point them at the moved folder
        if migrated {
            let oldImages = legacyDir.appendingPathComponent("images").path
            let newImages = dir.appendingPathComponent("images").path
            for i in notes.indices where notes[i].content.contains(oldImages) {
                notes[i].content = notes[i].content.replacingOccurrences(of: oldImages, with: newImages)
            }
            save()
        }

        // Typing is saved on a debounce — don't lose the last edits when the app quits
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: nil
        ) { [weak self] _ in self?.flushAll() }

        if notes.isEmpty {
            let welcome = Note(content: "Welcome to Halo\n\nStart typing to write your first note.\n\nTips:\n• ⌘N — new note\n• ⌘⇧P — pin window on top of all apps\n• Right-click a note to delete it")
            notes = [welcome]
            selectedNoteId = welcome.id
            save()
        } else {
            selectedNoteId = notes.first?.id
        }
    }

    func note(for id: UUID) -> Note? {
        notes.first { $0.id == id }
    }

    func createNote() {
        let note = Note()
        notes.insert(note, at: 0)
        selectedNoteId = note.id
        save()
    }

    // Title is updated immediately (it's @Published) but save is debounced
    func updateTitle(_ title: String, for noteId: UUID) {
        guard let idx = notes.firstIndex(where: { $0.id == noteId }) else { return }
        notes[idx].title = title
        notes[idx].updatedAt = Date()
        titleSaveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.save() }
        titleSaveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
    }

    func selectPreviousNote() {
        guard let id = selectedNoteId,
              let idx = notes.firstIndex(where: { $0.id == id }),
              idx > 0 else { return }
        selectedNoteId = notes[idx - 1].id
    }

    func selectNextNote() {
        guard let id = selectedNoteId,
              let idx = notes.firstIndex(where: { $0.id == id }),
              idx < notes.count - 1 else { return }
        selectedNoteId = notes[idx + 1].id
    }

    func createNoteWithContent(_ content: String) {
        let note = Note(content: content)
        notes.insert(note, at: 0)
        selectedNoteId = note.id
        save()
    }

    func deleteNote(_ note: Note) {
        pendingContent.removeValue(forKey: note.id)
        guard let idx = notes.firstIndex(where: { $0.id == note.id }) else { return }
        notes.remove(at: idx)
        selectedNoteId = notes.isEmpty ? nil : notes[min(idx, notes.count - 1)].id
        save()
    }

    // Called on every keystroke — stores content without publishing (no re-render)
    func updateContent(_ content: String, for noteId: UUID) {
        pendingContent[noteId] = content
        scheduleSave(for: noteId)
    }

    // Called before switching notes to persist any in-flight edits
    func flushPending(for noteId: UUID, content: String) {
        guard notes.firstIndex(where: { $0.id == noteId }) != nil else { return }
        pendingContent[noteId] = content
        commitPending(for: noteId)
    }

    private func commitPending(for noteId: UUID) {
        guard let content = pendingContent[noteId],
              let idx = notes.firstIndex(where: { $0.id == noteId }) else { return }
        notes[idx].content = content
        notes[idx].updatedAt = Date()
        pendingContent.removeValue(forKey: noteId)
        save()
    }

    // Commits every in-flight edit and writes to disk immediately
    func flushAll() {
        saveWorkItem?.cancel()
        titleSaveWorkItem?.cancel()
        for (id, content) in pendingContent {
            guard let idx = notes.firstIndex(where: { $0.id == id }) else { continue }
            notes[idx].content = content
            notes[idx].updatedAt = Date()
        }
        pendingContent.removeAll()
        save()
    }

    private func scheduleSave(for noteId: UUID) {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.commitPending(for: noteId)
        }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: item)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL) else { return }
        guard let decoded = try? JSONDecoder().decode([Note].self, from: data) else {
            // Unreadable file: set it aside rather than letting the welcome note overwrite it
            let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let backup = storageURL.deletingLastPathComponent()
                .appendingPathComponent("notes-unreadable-\(stamp).json")
            try? FileManager.default.moveItem(at: storageURL, to: backup)
            return
        }
        notes = decoded
        selectedNoteId = notes.first?.id
    }
}
