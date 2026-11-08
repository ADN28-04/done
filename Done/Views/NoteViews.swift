import SwiftUI

/// Désigne une note à ouvrir dans une feuille.
struct NoteRef: Identifiable, Hashable {
    let id: String
}

// MARK: Écran Notes

/// Toutes les notes : en tête la recherche, le filtre par type et la création ; dessous, la mosaïque
/// des cartes de note. Une note ouverte prend toute la largeur, avec « Retour » vers la mosaïque.
struct NotesView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: String?
    @State private var query = ""
    @State private var filter: NoteKind?
    @FocusState private var searchFocused: Bool

    private var book: NoteBook { NoteBook.shared }

    var body: some View {
        Group {
            if let selection, book.note(selection) != nil {
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        self.selection = nil
                    } label: {
                        Label("Toutes les notes", systemImage: "chevron.left")
                    }
                    .buttonStyle(DoneButtonStyle(kind: .plain, compact: true))
                    .padding(.horizontal, DoneSpace.s20)
                    .padding(.top, DoneSpace.s4)
                    NoteDetailView(noteID: selection) { self.selection = $0 }
                        .id(selection)
                }
            } else {
                mosaic
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var filtered: [Note] {
        let text = query.trimmingCharacters(in: .whitespaces)
        return book.notes.filter { note in
            (filter == nil || note.kind == filter)
                && (text.isEmpty || note.title.localizedCaseInsensitiveContains(text) || note.body.localizedCaseInsensitiveContains(text))
        }
    }

    private var mosaic: some View {
        VStack(alignment: .leading, spacing: DoneSpace.s16) {
            HStack(alignment: .center, spacing: DoneSpace.s12) {
                Text("Notes")
                    .doneText(.displayL)
                    .foregroundStyle(DoneColor.textPrimary)
                Spacer(minLength: DoneSpace.s16)
                HStack(spacing: DoneSpace.s8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DoneColor.textSecondary)
                    TextField("Chercher dans les notes", text: $query)
                        .textFieldStyle(.plain)
                        .focused($searchFocused)
                }
                .doneField(focused: searchFocused)
                .frame(maxWidth: 260)
                Menu {
                    Button("Tous les types") { filter = nil }
                    Divider()
                    ForEach(NoteKind.allCases) { kind in
                        Button(kind.plural) { filter = kind }
                    }
                } label: {
                    Text("Type : \(filter?.plural.lowercased() ?? "tous")")
                        .font(.done(.callout))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                NewNoteMenu(title: "Nouvelle") { kind in create(kind) }
            }
            if let message = book.errorMessage {
                NoticeBox(text: message, tone: .error)
            }
            GeometryReader { proxy in
                ScrollView {
                    if filtered.isEmpty && !(filter == nil && query.isEmpty) {
                        Text("Aucune note ne correspond.")
                            .doneText(.callout)
                            .foregroundStyle(DoneColor.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    // Quatre colonnes au plus, 220 de large au moins.
                    MasonryLayout(columns: max(2, min(4, Int(proxy.size.width / 220))), spacing: 10) {
                        ForEach(filtered) { note in
                            NoteCard(note: note) { selection = note.id }
                        }
                        if filter == nil && query.isEmpty {
                            NewNoteTile { create(.note) }
                        }
                    }
                    .padding(.bottom, DoneSpace.s24)
                }
                .scrollIndicators(.never)
            }
        }
        .padding(.horizontal, DoneSpace.s32)
        .padding(.top, DoneSpace.s4)
    }

    private func create(_ kind: NoteKind) {
        selection = book.create(Note(kind: kind, title: "Nouvelle \(kind.label.lowercased())", date: kind == .meeting ? .now : nil)).id
    }
}

/// Mosaïque : chaque carte va dans la colonne la plus courte, de gauche à droite, avec le même écart
/// entre colonnes et entre cartes.
struct MasonryLayout: Layout {
    var columns: Int
    var spacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 800
        return CGSize(width: width, height: arrange(width: width, subviews: subviews).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = arrange(width: bounds.width, subviews: subviews).frames
        for (subview, frame) in zip(subviews, frames) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (frames: [CGRect], height: CGFloat) {
        let count = max(columns, 1)
        let columnWidth = max((width - spacing * CGFloat(count - 1)) / CGFloat(count), 0)
        // Bas de chaque colonne ; nil tant qu'elle est vide.
        var bottoms = [CGFloat?](repeating: nil, count: count)
        var frames: [CGRect] = []
        for subview in subviews {
            let column = bottoms.indices.min { (bottoms[$0] ?? 0) < (bottoms[$1] ?? 0) } ?? 0
            let height = subview.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil)).height
            let top = bottoms[column].map { $0 + spacing } ?? 0
            frames.append(CGRect(x: CGFloat(column) * (columnWidth + spacing), y: top, width: columnWidth, height: height))
            bottoms[column] = top + height
        }
        return (frames, bottoms.compactMap { $0 }.max() ?? 0)
    }
}

/// Carte de note de la mosaïque : étiquette du type en pilule, titre en serif, extrait sur trois lignes
/// et jusqu'à trois cases, cliquables. Teinte de carte selon le type ; le journal et les notes simples
/// montrent leur texte en noteMono, comme un brouillon. Rayon md, marges 16 × 14.
struct NoteCard: View {
    let note: Note
    let open: () -> Void
    @State private var hovered = false

    /// Une case de la note, avec sa ligne dans le texte.
    private struct Todo: Identifiable {
        let checked: Bool
        let text: String
        let line: Int
        var id: Int { line }
    }

    private var book: NoteBook { NoteBook.shared }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DoneRadius.md, style: .continuous)
        let blocks = MarkdownBlocks.parse(note.body)
        let todos = Array(blocks.compactMap(Self.todo).prefix(3))
        let excerpt = Self.excerpt(blocks)
        let isMono = note.kind == .journal || note.kind == .note
        VStack(alignment: .leading, spacing: DoneSpace.s8) {
            TagPill(title: note.kind.label, color: note.kind.tagColor)
            Text(note.title)
                .doneText(.noteTitle)
                .foregroundStyle(DoneColor.textPrimary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            if !excerpt.isEmpty {
                Text(excerpt)
                    .doneText(isMono ? .noteMono : .callout)
                    .foregroundStyle(isMono ? DoneColor.textPrimary : DoneColor.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(todos) { todo in
                HStack(spacing: DoneSpace.s8) {
                    TaskCheckbox(isDone: todo.checked) { toggle(todo.line) }
                        .scaleEffect(14.0 / 18.0)
                        .frame(width: 14, height: 14)
                    Text(MarkdownView.inline(todo.text))
                        .font(.sans(12))
                        .strikethrough(todo.checked, color: DoneColor.stateOnDone)
                        .foregroundStyle(DoneColor.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, DoneSpace.s16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(note.kind.cardTint, in: shape)
        .overlay {
            if !note.kind.isTinted || hovered {
                shape.strokeBorder(hovered ? DoneColor.borderDefault : DoneColor.borderSubtle, lineWidth: 1)
            }
        }
        .contentShape(shape)
        .onTapGesture(perform: open)
        .onHover { hovered = $0 }
        .animation(DoneMotion.hover, value: hovered)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Ouvrir", open)
        .help("Ouvrir « \(note.title) »")
    }

    private func toggle(_ line: Int) {
        var updated = note
        updated.body = MarkdownBlocks.toggleTask(in: note.body, line: line)
        book.save(updated)
    }

    private static func todo(_ block: MarkdownBlock) -> Todo? {
        if case let .task(checked, _, text, line) = block { return Todo(checked: checked, text: text, line: line) }
        return nil
    }

    /// Le texte de la note, sans mise en forme ni cases : de quoi remplir trois lignes.
    private static func excerpt(_ blocks: [MarkdownBlock]) -> String {
        var parts: [String] = []
        for block in blocks {
            let line: String? = switch block {
            case .heading(_, let value), .paragraph(let value), .bullet(_, let value), .numbered(_, _, let value), .quote(let value): value
            case .code(let code): code
            case .task, .rule: nil
            }
            if let line {
                parts.append(String(MarkdownView.inline(line).characters))
            }
            if parts.joined(separator: " ").count > 240 { break }
        }
        return parts.joined(separator: " ")
    }
}

/// Dernière tuile de la mosaïque : « Nouvelle note… » (ou un autre libellé), en pointillé.
struct NewNoteTile: View {
    var title = "Nouvelle note…"
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DoneRadius.md, style: .continuous)
        Button(action: action) {
            Label(title, systemImage: "plus")
                .font(.sans(13, .semibold))
                .foregroundStyle(hovered ? DoneColor.textPrimary : DoneColor.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(hovered ? DoneColor.surfaceHover : Color.clear, in: shape)
                .overlay(shape.strokeBorder(DoneColor.stateWaiting, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(DoneMotion.hover, value: hovered)
    }
}

extension NoteKind {
    /// Carte teintée, sans liseré ; les autres sont sur surfaceDefault avec un liseré.
    var isTinted: Bool {
        switch self {
        case .note, .decision: false
        default: true
        }
    }

    /// Teinte de la carte de note.
    var cardTint: Color {
        switch self {
        case .journal: DoneColor.cardBlush
        case .meeting: DoneColor.cardSlate
        case .person: DoneColor.cardSage
        case .reference, .project: DoneColor.cardParchment
        case .note, .decision: DoneColor.surfaceDefault
        }
    }

    /// Couleur de l'étiquette du type (TagPill) : 4,5:1 sur la teinte de la carte.
    var tagColor: Color {
        switch self {
        case .note: DoneColor.accentText
        case .meeting: DoneColor.stateActiveText
        case .decision: DoneColor.tagPink
        case .journal: DoneColor.tagYellow
        case .person: DoneColor.successText
        case .reference, .project: DoneColor.textSecondary
        }
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
        .doneCard(radius: DoneRadius.md, flat: true)
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
                .doneCard(radius: DoneRadius.md, flat: true)
            }
            .sheet(item: $opened) { ref in
                NoteSheet(noteID: ref.id)
                    .environment(model)
            }
        }
    }
}
