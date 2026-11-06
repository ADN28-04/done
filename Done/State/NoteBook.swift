import Foundation
import Observation

/// Les notes, lues dans leurs fichiers et relues dès que le dossier change : une note modifiée dans
/// un autre éditeur, ou par le connecteur Claude, apparaît sans relancer Done. Chaque modification
/// réécrit le fichier de sa note.
@Observable
@MainActor
final class NoteBook {
    static let shared = NoteBook(storage: .standard)

    /// Les plus récemment modifiées d'abord.
    private(set) var notes: [Note] = []
    var errorMessage: String?

    @ObservationIgnored let storage: NoteStorage
    /// Identifiant de note vers nom de fichier.
    @ObservationIgnored private var files: [String: String] = [:]
    @ObservationIgnored private var watcher: FolderWatcher?
    @ObservationIgnored private var timer: Timer?

    init(storage: NoteStorage) {
        self.storage = storage
        reload()
    }

    /// Au lancement : surveille le dossier, et relit toutes les 30 secondes au cas où un éditeur
    /// réécrit un fichier sur place sans que le dossier le signale.
    func start() {
        reload()
        if watcher == nil {
            watcher = FolderWatcher(folder: storage.folder) { [weak self] in self?.reload() }
            watcher?.start()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
    }

    func reload() {
        var seen = Set<String>()
        var list: [Note] = []
        var map: [String: String] = [:]
        // Deux fichiers avec le même identifiant (une copie faite à la main) : le premier par nom l'emporte.
        for entry in storage.loadAll().sorted(by: { $0.fileName < $1.fileName }) where seen.insert(entry.note.id).inserted {
            list.append(entry.note)
            map[entry.note.id] = entry.fileName
        }
        list.sort { $0.updatedAt > $1.updatedAt }
        files = map
        if list != notes { notes = list }
    }

    // MARK: Lecture

    func note(_ id: String) -> Note? {
        notes.first { $0.id == id }
    }

    func resolve(_ title: String) -> Note? {
        NoteLinks.resolve(title, in: notes)
    }

    func backlinks(to note: Note) -> [Note] {
        NoteLinks.backlinks(to: note, in: notes)
    }

    /// Notes rattachées au projet, hors sa page.
    func notes(forProject id: String) -> [Note] {
        notes.filter { $0.projectID == id && $0.kind != .project }
    }

    func notes(forTask id: String) -> [Note] {
        notes.filter { $0.taskIDs.contains(id) }
    }

    func projectPage(for projectID: String) -> Note? {
        notes.first { $0.kind == .project && $0.projectID == projectID }
    }

    func journal(for day: Date) -> Note? {
        notes.first { $0.kind == .journal && ($0.date.map { Calendar.current.isDate($0, inSameDayAs: day) } ?? false) }
    }

    func meetingNote(for meeting: Meeting) -> Note? {
        notes.first { $0.kind == .meeting && ($0.meetingID == meeting.id || ($0.date == meeting.start && $0.title.hasPrefix(meeting.title))) }
    }

    /// Un titre libre : les liens [[Titre]] doivent désigner une seule note.
    func uniqueTitle(_ title: String, excluding id: String? = nil) -> String {
        NoteLinks.uniqueTitle(title, among: notes, excluding: id)
    }

    // MARK: Écriture

    /// Crée la note, avec un titre rendu unique.
    @discardableResult
    func create(_ note: Note) -> Note {
        var created = note
        created.title = uniqueTitle(note.title)
        write(created)
        return created
    }

    /// Enregistre une modification : date de mise à jour, fichier renommé si le titre a changé.
    func save(_ note: Note) {
        var updated = note
        updated.title = uniqueTitle(note.title, excluding: note.id)
        updated.updatedAt = .now
        write(updated)
    }

    func delete(_ id: String) {
        if let file = files[id] {
            do {
                try storage.trash(file)
            } catch {
                errorMessage = "Note non supprimée : \(error.localizedDescription)"
                return
            }
        }
        files[id] = nil
        notes.removeAll { $0.id == id }
    }

    /// La page de documentation du projet, créée au premier besoin.
    func ensureProjectPage(for project: Project, name: String) -> Note {
        if let page = projectPage(for: project.id) { return page }
        return create(Note(kind: .project, title: name, body: NoteTemplates.projectPage, projectID: project.id))
    }

    /// La note du jour, créée au premier besoin.
    func ensureJournal(for day: Date) -> Note {
        if let note = journal(for: day) { return note }
        let start = Calendar.current.startOfDay(for: day)
        return create(Note(kind: .journal, title: NoteTemplates.journalTitle(start), date: start))
    }

    /// La note d'une réunion, préremplie, créée au premier besoin.
    func ensureMeetingNote(for meeting: Meeting) -> Note {
        if let note = meetingNote(for: meeting) { return note }
        return create(Note(
            kind: .meeting,
            title: NoteTemplates.meetingTitle(meeting),
            body: NoteTemplates.meetingBody(meeting),
            date: meeting.start,
            meetingID: meeting.id
        ))
    }

    private func write(_ note: Note) {
        do {
            let taken = Set(files.filter { $0.key != note.id }.map(\.value))
            files[note.id] = try storage.save(note, currentFile: files[note.id], taken: taken)
            var list = notes.filter { $0.id != note.id }
            list.append(note)
            notes = list.sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            errorMessage = "Note non enregistrée : \(error.localizedDescription)"
        }
    }
}
