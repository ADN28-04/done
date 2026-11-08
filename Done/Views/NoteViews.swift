import SwiftUI

/// Désigne une note à ouvrir dans une feuille.
struct NoteRef: Identifiable, Hashable {
    let id: String
}

// MARK: Écran Notes

/// Toutes les notes : à gauche la liste (recherche, filtre par type, création), à droite la note choisie.
struct NotesView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: String?
    @State private var query = ""
    @State private var filter: NoteKind?

    private var book: NoteBook { NoteBook.shared }

    var body: some View {
        HStack(spacing: 0) {
            list
                .frame(width: 300)
            Rectangle()
                .fill(DoneColor.borderSubtle)
                .frame(width: 1)
            Group {
                if let selection, book.note(selection) != nil {
                    NoteDetailView(noteID: selection) { self.selection = $0 }
                        .id(selection)
                } else {
                    VStack(spacing: DoneSpace.s6) {
                        Text("Aucune note ouverte")
                            .doneText(.title)
                            .foregroundStyle(DoneColor.textPrimary)
                        Text("Choisis une note à gauche, ou crée-en une.")
                            .doneText(.callout)
                            .foregroundStyle(DoneColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filtered: [Note] {
        let text = query.trimmingCharacters(in: .whitespaces)
        return book.notes.filter { note in
            (filter == nil || note.kind == filter)
                && (text.isEmpty || note.title.localizedCaseInsensitiveContains(text) || note.body.localizedCaseInsensitiveContains(text))
        }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Notes")
                    .doneText(.displayL)
                    .foregroundStyle(DoneColor.textPrimary)
                Spacer()
                NewNoteMenu { kind in
                    selection = book.create(Note(kind: kind, title: "Nouvelle \(kind.label.lowercased())", date: kind == .meeting ? .now : nil)).id
                }
            }
            HStack(spacing: DoneSpace.s8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DoneColor.textSecondary)
                TextField("Chercher", text: $query)
                    .textFieldStyle(.plain)
            }
            .doneField(focused: false)
            .padding(.top, DoneSpace.s16)
            Menu {
                Button("Tous les types") { filter = nil }
                Divider()
                ForEach(NoteKind.allCases) { kind in
                    Button(kind.plural) { filter = kind }
                }
            } label: {
                Text("Type : \(filter?.plural ?? "tous")")
                    .font(.done(.callout))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .padding(.top, DoneSpace.s8)
            if let message = book.errorMessage {
                NoticeBox(text: message, tone: .error)
                    .padding(.top, DoneSpace.s8)
            }
            ScrollView {
                LazyVStack(spacing: DoneSpace.s2) {
                    ForEach(filtered) { note in
                        NoteRow(note: note, isSelected: note.id == selection) { selection = note.id }
                    }
                }
                .padding(.vertical, DoneSpace.s8)
            }
            .scrollIndicators(.never)
            .padding(.top, DoneSpace.s8)
            if filtered.isEmpty {
                Text(book.notes.isEmpty ? "Pas encore de note. Le bouton + en crée une." : "Aucune note ne correspond.")
                    .doneText(.callout)
                    .foregroundStyle(DoneColor.textSecondary)
                    .padding(.bottom, DoneSpace.s16)
            }
        }
        .padding(.horizontal, DoneSpace.s20)
        .padding(.top, DoneSpace.s4)
        .padding(.bottom, DoneSpace.s16)
    }
}

/// Bouton « + » qui propose les types de note.
struct NewNoteMenu: View {
    var title: String?
    let create: (NoteKind) -> Void

    var body: some View {
        Menu {
            ForEach(NoteKind.creatable) { kind in
                Button {
                    create(kind)
                } label: {
                    Label(kind.label, systemImage: kind.symbol)
                }
            }
        } label: {
            if let title {
                Label(title, systemImage: "plus")
                    .font(.done(.callout))
            } else {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Nouvelle note")
    }
}

/// Ligne de note : icône du type, titre, et une ligne de détails.
struct NoteRow: View {
    @Environment(AppModel.self) private var model
    let note: Note
    var isSelected = false
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: DoneSpace.s8) {
                Image(systemName: note.kind.symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DoneColor.textSecondary)
                    .frame(width: 16)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: DoneSpace.s2) {
                    Text(note.title)
                        .doneText(.bodyStrong)
                        .foregroundStyle(DoneColor.textPrimary)
                        .lineLimit(1)
                    Text(details)
                        .doneText(.caption)
                        .foregroundStyle(DoneColor.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, DoneSpace.s8)
            .padding(.vertical, DoneSpace.s6)
            .background(
                isSelected ? DoneColor.surfaceSelected : (hovered ? DoneColor.surfaceHover : Color.clear),
                in: RoundedRectangle(cornerRadius: DoneRadius.sm, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }

    private var details: String {
        var parts = [note.kind.label]
        if note.projectID != nil, note.kind != .project { parts.append(model.projectName(note.projectID)) }
        parts.append(Format.moment(note.updatedAt))
        return parts.joined(separator: " · ")
    }
}

// MARK: Une note

/// Une note : type, titre, rattachements (projet, étiquettes, date, tâches), contenu en aperçu ou en
/// édition, liens sortants et notes qui la citent. Chaque modification est enregistrée après une
/// courte pause.
struct NoteDetailView: View {
    @Environment(AppModel.self) private var model
    let noteID: String
    /// Ouvre une autre note (lien, rétrolien).
    let open: (String) -> Void

    @State private var draft: Note?
    @State private var editing = false
    @State private var pendingSave: Task<Void, Never>?
    @State private var pickingTask = false
    @State private var confirmDelete = false
    @FocusState private var bodyFocused: Bool

    private var book: NoteBook { NoteBook.shared }

    var body: some View {
        Group {
            if let note = Binding($draft) {
                ScrollView {
                    content(note)
                        .padding(DoneSpace.s24)
                        .frame(maxWidth: 760, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.never)
            } else {
                Text("Cette note n'existe plus.")
                    .doneText(.body)
                    .foregroundStyle(DoneColor.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear(perform: load)
        .onDisappear(perform: saveNow)
        .onChange(of: draft) { scheduleSave() }
        .onChange(of: book.notes) { refreshFromDisk() }
        .sheet(isPresented: $pickingTask) {
            TaskPickerView(title: "Rattacher une tâche") { task in
                if draft?.taskIDs.contains(task.id) == false { draft?.taskIDs.append(task.id) }
            }
            .environment(model)
        }
    }

    @ViewBuilder
    private func content(_ note: Binding<Note>) -> some View {
        let current = note.wrappedValue
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: DoneSpace.s8) {
                Label(current.kind.label, systemImage: current.kind.symbol)
                    .font(.sans(12, .medium))
                    .foregroundStyle(DoneColor.stateActiveText)
                    .padding(.horizontal, DoneSpace.s8)
                    .frame(height: 22)
                    .background(DoneColor.stateActiveTint, in: RoundedRectangle(cornerRadius: DoneRadius.chip, style: .continuous))
                Text("Modifiée \(Format.moment(current.updatedAt).lowercased())")
                    .doneText(.caption)
                    .foregroundStyle(DoneColor.textSecondary)
                Spacer()
                Menu {
                    Button("Supprimer la note…", role: .destructive) { confirmDelete = true }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .semibold))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .foregroundStyle(DoneColor.textSecondary)
            }
            TextField("Titre", text: note.title)
                .textFieldStyle(.plain)
                .font(.done(.displayM))
                .foregroundStyle(DoneColor.textPrimary)
                .onSubmit(saveNow)
                .padding(.top, DoneSpace.s12)
            details(note)
                .padding(.top, DoneSpace.s16)
            bodySection(note)
                .padding(.top, DoneSpace.s20)
            links(current)
                .padding(.top, DoneSpace.s24)
        }
        .confirmationDialog("Supprimer « \(current.title) » ?", isPresented: $confirmDelete) {
            Button("Supprimer la note", role: .destructive) {
                pendingSave?.cancel()
                book.delete(current.id)
                draft = nil
            }
        } message: {
            Text("Le fichier part à la corbeille.")
        }
    }

    // MARK: Rattachements

    private func details(_ note: Binding<Note>) -> some View {
        let current = note.wrappedValue
        let fixedProject = current.kind == .project
        let components: DatePickerComponents = current.kind == .meeting ? [.date, .hourAndMinute] : .date
        return VStack(spacing: 0) {
            if NoteKind.creatable.contains(current.kind) {
                DetailRow("Type") {
                    Menu {
                        ForEach(NoteKind.creatable) { kind in
                            Button(kind.label) { note.wrappedValue.kind = kind }
                        }
                    } label: {
                        Text(current.kind.label)
                            .font(.done(.body))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                Hairline().padding(.horizontal, DoneSpace.s16)
            }
            DetailRow("Projet") {
                Menu {
                    Button("Aucun") { note.wrappedValue.projectID = nil }
                    ForEach(model.projects) { project in
                        Button(model.projectName(project.id)) { note.wrappedValue.projectID = project.id }
                    }
                } label: {
                    Text(current.projectID == nil ? "Aucun" : model.projectName(current.projectID))
                        .font(.done(.body))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .disabled(fixedProject)
                .help(fixedProject ? "Une page de projet reste attachée à son projet" : "Rattacher la note à un projet")
            }
            Hairline().padding(.horizontal, DoneSpace.s16)
            DetailRow("Étiquettes") {
                TagEditor(tags: note.tags)
            }
            if current.kind == .meeting || current.kind == .journal {
                Hairline().padding(.horizontal, DoneSpace.s16)
                DetailRow(current.kind == .meeting ? "Date" : "Jour") {
                    DatePicker(
                        "Date",
                        selection: Binding(get: { current.date ?? .now }, set: { note.wrappedValue.date = $0 }),
                        displayedComponents: components
                    )
                    .labelsHidden()
                }
            }
            Hairline().padding(.horizontal, DoneSpace.s16)
            DetailRow("Tâches") {
                HStack(spacing: DoneSpace.s6) {
                    ForEach(current.taskIDs, id: \.self) { id in
                        taskToken(id, note: note)
                    }
                    Button("Rattacher…") { pickingTask = true }
                        .buttonStyle(DoneButtonStyle(kind: .plain, compact: true))
                }
            }
        }
        .doneCard()
    }

    private func taskToken(_ id: String, note: Binding<Note>) -> some View {
        let task = model.store[id]
        return HStack(spacing: DoneSpace.s4) {
            Text(task?.title ?? "Tâche supprimée")
                .lineLimit(1)
                .strikethrough(task?.isOpen == false)
            Button {
                note.wrappedValue.taskIDs.removeAll { $0 == id }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .frame(width: 12, height: 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Détacher la tâche")
        }
        .font(.sans(12, .medium))
        .foregroundStyle(DoneColor.stateActiveText)
        .padding(.leading, 7)
        .padding(.trailing, 5)
        .frame(maxWidth: 180)
        .frame(height: 22)
        .background(DoneColor.stateActiveTint, in: RoundedRectangle(cornerRadius: DoneRadius.chip, style: .continuous))
        .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: Contenu

    private func bodySection(_ note: Binding<Note>) -> some View {
        VStack(alignment: .leading, spacing: DoneSpace.s8) {
            HStack(spacing: DoneSpace.s8) {
                Eyebrow(text: "Contenu")
                Spacer()
                if editing {
                    Menu {
                        ForEach(book.notes.filter { $0.id != note.wrappedValue.id }.prefix(40)) { other in
                            Button(other.title) { note.wrappedValue.body += (note.wrappedValue.body.isEmpty ? "" : " ") + "[[\(other.title)]]" }
                        }
                    } label: {
                        Label("Lier une note", systemImage: "link")
                            .font(.done(.callout))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("Ajoute [[Titre]] à la fin du texte")
                }
                Button(editing ? "Terminer" : "Modifier") {
                    editing.toggle()
                    if editing { bodyFocused = true } else { saveNow() }
                }
                .buttonStyle(DoneButtonStyle(compact: true))
                .keyboardShortcut("e", modifiers: .command)
                .help("⌘E")
            }
            .padding(.leading, DoneSpace.s2)
            if editing {
                TextEditor(text: note.body)
                    .font(.done(.body))
                    .foregroundStyle(DoneColor.textPrimary)
                    .scrollContentBackground(.hidden)
                    .focused($bodyFocused)
                    .padding(DoneSpace.s8)
                    .frame(minHeight: 320)
                    .background(DoneColor.surfaceDefault, in: RoundedRectangle(cornerRadius: DoneRadius.sm, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: DoneRadius.sm, style: .continuous).strokeBorder(DoneColor.focusRing, lineWidth: 2))
                Text("Markdown : # titre, - liste, - [ ] case, **gras**, *italique*, [[Titre]] pour lier une note.")
                    .doneText(.caption)
                    .foregroundStyle(DoneColor.textSecondary)
            } else if note.wrappedValue.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    editing = true
                    bodyFocused = true
                } label: {
                    Text("Note vide. Clique pour écrire.")
                        .doneText(.body)
                        .foregroundStyle(DoneColor.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                        .padding(DoneSpace.s12)
                        .overlay(
                            RoundedRectangle(cornerRadius: DoneRadius.md, style: .continuous)
                                .strokeBorder(DoneColor.stateWaiting, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                MarkdownView(text: note.wrappedValue.body) { line in
                    note.wrappedValue.body = MarkdownBlocks.toggleTask(in: note.wrappedValue.body, line: line)
                } onOpenLink: { title in
                    openLink(title)
                }
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    editing = true
                    bodyFocused = true
                }
                .help("Double-clic pour modifier")
            }
        }
    }

    // MARK: Liens

    @ViewBuilder
    private func links(_ note: Note) -> some View {
        let outgoing = NoteLinks.titles(in: note.body)
        let backlinks = book.backlinks(to: note)
        if !outgoing.isEmpty || !backlinks.isEmpty {
            VStack(alignment: .leading, spacing: DoneSpace.s16) {
                if !outgoing.isEmpty {
                    VStack(alignment: .leading, spacing: DoneSpace.s4) {
                        Eyebrow(text: "Liens")
                            .padding(.leading, DoneSpace.s2)
                        ForEach(outgoing, id: \.self) { title in
                            if let target = book.resolve(title) {
                                NoteRow(note: target) { open(target.id) }
                            } else {
                                Button {
                                    openLink(title)
                                } label: {
                                    Label("Créer « \(title) »", systemImage: "plus")
                                        .font(.done(.callout))
                                }
                                .buttonStyle(DoneButtonStyle(kind: .plain, compact: true))
                            }
                        }
                    }
                }
                if !backlinks.isEmpty {
                    VStack(alignment: .leading, spacing: DoneSpace.s4) {
                        Eyebrow(text: "Citée dans")
                            .padding(.leading, DoneSpace.s2)
                        ForEach(backlinks) { other in
                            NoteRow(note: other) { open(other.id) }
                        }
                    }
                }
            }
        }
    }

    /// Ouvre la note du titre, ou la crée si elle n'existe pas encore.
    private func openLink(_ title: String) {
        saveNow()
        if let target = book.resolve(title) {
            open(target.id)
        } else {
            let created = book.create(Note(title: title, projectID: draft?.projectID))
            open(created.id)
        }
    }

    // MARK: Enregistrement

    private func load() {
        draft = book.note(noteID)
    }

    /// Le fichier a changé (autre éditeur, Claude) : on prend sa version, sauf pendant l'édition du texte.
    private func refreshFromDisk() {
        guard !editing, let stored = book.note(noteID) else { return }
        if let draft, Self.sameContent(stored, draft) { return }
        pendingSave?.cancel()
        draft = stored
    }

    private func scheduleSave() {
        guard let draft, let stored = book.note(draft.id), !Self.sameContent(draft, stored) else { return }
        pendingSave?.cancel()
        pendingSave = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            saveNow()
        }
    }

    private func saveNow() {
        pendingSave?.cancel()
        guard let draft, let stored = book.note(draft.id), !Self.sameContent(draft, stored) else { return }
        book.save(draft)
    }

    /// Même contenu, la date de mise à jour mise à part.
    private static func sameContent(_ a: Note, _ b: Note) -> Bool {
        var copy = a
        copy.updatedAt = b.updatedAt
        return copy == b
    }
}

/// Une note dans une feuille, depuis un projet, une réunion, Aujourd'hui ou une tâche. Les liens ouvrent
/// la note suivante dans la même feuille, avec un retour.
struct NoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var path: [String]

    init(noteID: String) {
        _path = State(initialValue: [noteID])
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if path.count > 1 {
                    Button {
                        path.removeLast()
                    } label: {
                        Label("Retour", systemImage: "chevron.left")
                    }
                    .buttonStyle(DoneButtonStyle(kind: .plain, compact: true))
                }
                Spacer()
                Button("Fermer") { dismiss() }
                    .buttonStyle(DoneButtonStyle(compact: true))
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, DoneSpace.s16)
            .padding(.top, DoneSpace.s12)
            if let current = path.last {
                NoteDetailView(noteID: current) { path.append($0) }
                    .id(current)
            }
        }
        .frame(width: 760, height: 680)
        .background(DoneColor.bgCanvas)
    }
}

// MARK: Dans les autres écrans

/// En haut de la vue d'un projet : sa page de documentation (début du texte) et les notes rattachées.
struct ProjectNotesCard: View {
    @Environment(AppModel.self) private var model
    let project: Project
    @State private var opened: NoteRef?

    private var book: NoteBook { NoteBook.shared }

    var body: some View {
        let page = book.projectPage(for: project.id)
        let notes = book.notes(forProject: project.id)
        VStack(alignment: .leading, spacing: DoneSpace.s8) {
            HStack(spacing: DoneSpace.s8) {
                Eyebrow(text: notes.isEmpty ? "Documentation" : "Documentation · \(notes.count + (page == nil ? 0 : 1))")
                Spacer()
                Button(page == nil ? "Créer la page du projet" : "Ouvrir la page") {
                    opened = NoteRef(id: book.ensureProjectPage(for: project, name: model.projectName(project.id)).id)
                }
                .buttonStyle(DoneButtonStyle(kind: .plain, compact: true))
                NewNoteMenu(title: "Note") { kind in
                    let created = book.create(Note(kind: kind, title: "Nouvelle \(kind.label.lowercased())", projectID: project.id, date: kind == .meeting ? .now : nil))
                    opened = NoteRef(id: created.id)
                }
            }
            if let page, !page.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                MarkdownView(text: Self.excerpt(page.body))
                    .frame(maxHeight: 120, alignment: .top)
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture { opened = NoteRef(id: page.id) }
                    .help("Ouvrir la page du projet")
            }
            if !notes.isEmpty {
                VStack(spacing: DoneSpace.s2) {
                    ForEach(notes.prefix(4)) { note in
                        NoteRow(note: note) { opened = NoteRef(id: note.id) }
                    }
                }
                if notes.count > 4 {
                    Text("Et \(notes.count - 4) autre\(notes.count - 4 > 1 ? "s" : "") dans Notes.")
                        .doneText(.caption)
                        .foregroundStyle(DoneColor.textSecondary)
                        .padding(.leading, DoneSpace.s8)
                }
            }
        }
        .padding(DoneSpace.s12)
        .doneCard(radius: DoneRadius.lg)
        .sheet(item: $opened) { ref in
            NoteSheet(noteID: ref.id)
                .environment(model)
        }
    }

    /// Les premières lignes, sans les titres de section vides du modèle.
    private static func excerpt(_ body: String) -> String {
        body.components(separatedBy: "\n").prefix(8).joined(separator: "\n")
    }
}

/// Dans la fiche d'une tâche : les notes qui y sont rattachées.
struct TaskNotesList: View {
    @Environment(AppModel.self) private var model
    let taskID: String
    @State private var opened: NoteRef?

    var body: some View {
        let notes = NoteBook.shared.notes(forTask: taskID)
        if !notes.isEmpty {
            VStack(alignment: .leading, spacing: DoneSpace.s8) {
                Eyebrow(text: "Notes · \(notes.count)")
                    .padding(.leading, DoneSpace.s2)
                VStack(spacing: DoneSpace.s2) {
                    ForEach(notes) { note in
                        NoteRow(note: note) { opened = NoteRef(id: note.id) }
                    }
                }
                .padding(DoneSpace.s6)
                .doneCard()
            }
            .sheet(item: $opened) { ref in
                NoteSheet(noteID: ref.id)
                    .environment(model)
            }
        }
    }
}
