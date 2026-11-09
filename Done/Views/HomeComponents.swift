import SwiftUI

// Composants de l'écran Ma journée (design system Mymind) : salutation, recherche ⌘K, barre de
// saisie et rail de navigation. La recherche sert déjà dans la barre du haut ; le reste prend place
// avec l'écran Ma journée.

// MARK: Salutation

/// En-tête de Ma journée : la date, puis une phrase qui résume la journée, en grand. La salutation
/// (« Bonjour Adnan, ») est en italique textSecondary, le résumé en textPrimary, en displayXL ;
/// deux lignes au plus, 820 de large au plus.
struct Greeting: View {
    let date: Date
    /// « Salut Adnan, », « Un café d'abord ? » : `DayGreeting.salutation`.
    let salutation: String
    /// « trois tâches et deux réunions aujourd'hui. » : `DaySummary.sentence`.
    let summary: String

    var body: some View {
        let style = DoneTextStyle.displayXL
        VStack(alignment: .leading, spacing: DoneSpace.s12) {
            HStack(spacing: DoneSpace.s6) {
                Image(systemName: "sun.max")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DoneColor.accent)
                Text("\(Self.capitalized(Format.longDay(date))) · semaine \(Calendar(identifier: .iso8601).component(.weekOfYear, from: date))")
                    .font(.sans(13, .semibold))
                    .foregroundStyle(DoneColor.textSecondary)
            }
            (Text(salutation)
                .font(.doneItalic(style))
                .foregroundStyle(DoneColor.textSecondary)
                + Text(" " + summary)
                .font(.done(style))
                .foregroundStyle(DoneColor.textPrimary))
                .tracking(style.size * style.tracking)
                .lineSpacing(max(0, style.lineHeight - style.size * 1.3))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 820, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private static func capitalized(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }
}

// MARK: Recherche

/// Recherche en pilule : 38 de haut, contour borderDefault (focusRing de 2 au focus), loupe de 15,
/// texte body, ⌘K à droite. 240 de large au moins.
struct SearchField: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    var placeholder = "Rechercher"

    var body: some View {
        let isFocused = focused.wrappedValue
        HStack(spacing: DoneSpace.s8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(DoneColor.textSecondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.done(.body))
                .foregroundStyle(DoneColor.textPrimary)
                .focused(focused)
            if text.isEmpty {
                KeyCap(key: "⌘K")
                    .foregroundStyle(DoneColor.textSecondary)
            } else {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(DoneColor.textDisabled)
                }
                .buttonStyle(.plain)
                .help("Effacer")
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, DoneSpace.s12)
        .frame(minWidth: 240)
        .frame(height: 38)
        .background(DoneColor.surfaceDefault, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(isFocused ? DoneColor.focusRing : DoneColor.borderDefault, lineWidth: isFocused ? 2 : 1)
        )
        .animation(DoneMotion.hover, value: isFocused)
    }
}

/// Recherche globale de l'en-tête de Ma journée : ⌘K y mène depuis n'importe quel écran ; les
/// résultats s'ouvrent sous la pilule, groupés (Tâches, Notes, Réunions), cinq au plus par groupe.
/// ↑ ↓ choisissent, Entrée ouvre, Échap ferme. La recherche elle-même est `GlobalSearch` (Core).
struct GlobalSearchBox: View {
    @Environment(AppModel.self) private var model
    /// ⌘K : vrai jusqu'à ce que la recherche ait pris le focus.
    @Binding var focusRequest: Bool

    @State private var query = ""
    @State private var isOpen = false
    @State private var highlighted = 0
    @State private var target: SearchTarget?
    @FocusState private var focused: Bool

    private enum SearchTarget: Identifiable {
        case task(String)
        case note(String)
        case meeting(Meeting)

        var id: String {
            switch self {
            case .task(let id): "task-" + id
            case .note(let id): "note-" + id
            case .meeting(let meeting): "meeting-" + meeting.id
            }
        }
    }

    private var results: GlobalSearch.Results {
        GlobalSearch.run(
            query,
            tasks: model.store.tasks,
            projectName: { model.projectName($0) },
            notes: NoteBook.shared.notes,
            meetings: model.store.meetings
        )
    }

    var body: some View {
        let results = self.results
        let targets = Self.targets(results)
        SearchField(text: $query, focused: $focused)
            .frame(width: 260)
            .onSubmit {
                guard targets.indices.contains(highlighted) else { return }
                open(targets[highlighted])
            }
            .onKeyPress(.downArrow) {
                highlighted = min(highlighted + 1, max(targets.count - 1, 0))
                return .handled
            }
            .onKeyPress(.upArrow) {
                highlighted = max(highlighted - 1, 0)
                return .handled
            }
            .onExitCommand { close(clear: true) }
            .onChange(of: query) {
                highlighted = 0
                isOpen = !query.trimmingCharacters(in: .whitespaces).isEmpty
            }
            .task(id: focusRequest) {
                guard focusRequest else { return }
                // Laisse l'écran se poser avant de donner le focus.
                try? await Task.sleep(for: .milliseconds(60))
                focused = true
                focusRequest = false
            }
            .onChange(of: focused) { _, isFocused in
                if isFocused {
                    isOpen = !query.trimmingCharacters(in: .whitespaces).isEmpty
                } else {
                    // Laisse le temps au clic sur un résultat d'aboutir avant de fermer.
                    Task {
                        try? await Task.sleep(for: .milliseconds(350))
                        if !focused { isOpen = false }
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                if isOpen {
                    resultsPanel(results, targets: targets)
                        .frame(width: 380)
                        .fixedSize(horizontal: false, vertical: true)
                        .offset(y: 46)
                        .transition(.opacity)
                }
            }
            .animation(DoneMotion.appear, value: isOpen)
            .sheet(item: $target) { target in
                switch target {
                case .task(let id):
                    TaskEditorSheet(taskID: id)
                        .environment(model)
                case .note(let id):
                    NoteSheet(noteID: id)
                        .environment(model)
                case .meeting(let meeting):
                    MeetingSheet(meeting: meeting)
                        .environment(model)
                }
            }
    }

    private func resultsPanel(_ results: GlobalSearch.Results, targets: [SearchTarget]) -> some View {
        VStack(alignment: .leading, spacing: DoneSpace.s4) {
            if results.isEmpty {
                Text("Aucun résultat")
                    .doneText(.callout)
                    .foregroundStyle(DoneColor.textSecondary)
                    .padding(DoneSpace.s12)
            } else {
                if !results.tasks.isEmpty {
                    group("Tâches")
                    ForEach(results.tasks) { task in
                        row(symbol: "checkmark.circle", title: task.title, detail: model.projectName(task.projectID), index: index(of: "task-" + task.id, in: targets)) {
                            open(.task(task.id))
                        }
                    }
                }
                if !results.notes.isEmpty {
                    group("Notes")
                    ForEach(results.notes) { note in
                        row(symbol: note.kind.symbol, title: note.title, detail: note.kind.label, index: index(of: "note-" + note.id, in: targets)) {
                            open(.note(note.id))
                        }
                    }
                }
                if !results.meetings.isEmpty {
                    group("Réunions")
                    ForEach(results.meetings) { meeting in
                        row(symbol: "person.2", title: meeting.title, detail: Format.slot(meeting), index: index(of: "meeting-" + meeting.id, in: targets)) {
                            open(.meeting(meeting))
                        }
                    }
                }
            }
        }
        .padding(DoneSpace.s8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .doneCard(radius: DoneRadius.md)
    }

    private func group(_ title: String) -> some View {
        Eyebrow(text: title)
            .padding(.horizontal, DoneSpace.s8)
            .padding(.top, DoneSpace.s6)
    }

    private func row(symbol: String, title: String, detail: String, index: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DoneSpace.s8) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DoneColor.textSecondary)
                    .frame(width: 16)
                Text(title)
                    .doneText(.bodyStrong)
                    .foregroundStyle(DoneColor.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: DoneSpace.s8)
                Text(detail)
                    .doneText(.caption)
                    .foregroundStyle(DoneColor.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, DoneSpace.s8)
            .frame(height: 34)
            .background(index == highlighted ? DoneColor.surfaceSelected : Color.clear, in: Capsule(style: .continuous))
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { inside in
            if inside { highlighted = index }
        }
    }

    private func index(of id: String, in targets: [SearchTarget]) -> Int {
        targets.firstIndex { $0.id == id } ?? -1
    }

    private static func targets(_ results: GlobalSearch.Results) -> [SearchTarget] {
        results.tasks.map { .task($0.id) } + results.notes.map { .note($0.id) } + results.meetings.map { .meeting($0) }
    }

    private func open(_ chosen: SearchTarget) {
        target = chosen
        close(clear: true)
    }

    private func close(clear: Bool) {
        isOpen = false
        focused = false
        if clear { query = "" }
    }
}

// MARK: Barre de saisie

/// Barre de saisie en bas de Ma journée : pilule de 54 ; à gauche un + et le texte, avec un vrai exemple
/// en aide ; à droite le genre en pilules de 38 (Tâche, Note, Réunion) et le bouton d'envoi rond en
/// actionPrimary. Entrée ajoute, ⌘ Entrée
/// ouvre la saisie complète. Après l'ajout, une puce de confirmation reste 2 s au-dessus.
struct CaptureBar: View {
    enum Kind: String, CaseIterable, Identifiable {
        case task, note, meeting

        var id: String { rawValue }

        var title: String {
            switch self {
            case .task: "Tâche"
            case .note: "Note"
            case .meeting: "Réunion"
            }
        }

        var placeholder: String {
            switch self {
            case .task: "Noter une tâche, une note ou une réunion… « Appeler le transporteur demain P2 »"
            case .note: "Une idée, une décision, un nom à retenir"
            case .meeting: "Point fournisseur"
            }
        }

        var symbol: String {
            switch self {
            case .task: "checkmark.square"
            case .note: "doc.text"
            case .meeting: "calendar"
            }
        }
    }

    @Binding var text: String
    @Binding var kind: Kind
    /// Ajoute ; renvoie la confirmation (« Ajoutée dans Inbox »), ou nil si rien n'est ajouté ici.
    let onSubmit: () -> String?
    /// ⌘ Entrée : la saisie complète.
    let onExpand: () -> Void

    @State private var confirmation: String?
    @State private var confirmationCount = 0
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let isEmpty = text.trimmingCharacters(in: .whitespaces).isEmpty
        VStack(alignment: .leading, spacing: DoneSpace.s8) {
            if let confirmation {
                StateChip(kind: .doneToday, title: confirmation)
                    .padding(.leading, DoneSpace.s16)
                    .transition(.opacity)
            }
            HStack(spacing: DoneSpace.s8) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(DoneColor.textSecondary)
                    .padding(.leading, DoneSpace.s12)
                TextField(kind.placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(.done(.body))
                    .foregroundStyle(DoneColor.textPrimary)
                    .focused($focused)
                    .onSubmit(submit)
                    .padding(.trailing, DoneSpace.s8)
                HStack(spacing: DoneSpace.s6) {
                    ForEach(Kind.allCases) { option in
                        Button {
                            kind = option
                        } label: {
                            Label(option.title, systemImage: option.symbol)
                        }
                        .buttonStyle(KindPillStyle(isOn: kind == option))
                    }
                }
                Button(action: submit) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                }
                .buttonStyle(SendButtonStyle())
                .disabled(isEmpty)
                .help("Ajouter (Entrée), ou saisie complète (⌘ Entrée)")
                // ⌘ Entrée, où que soit le focus dans la fenêtre.
                Button("Saisie complète", action: onExpand)
                    .keyboardShortcut(.return, modifiers: .command)
                    .opacity(0)
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, DoneSpace.s8)
            .frame(height: 54)
            .background(DoneColor.surfaceDefault, in: Capsule(style: .continuous))
            .overlay(Capsule(style: .continuous).strokeBorder(DoneColor.borderSubtle, lineWidth: 1))
            .shadow(color: DoneColor.shadowCard, radius: 15, y: 10)
            .shadow(color: DoneColor.shadowCardNear, radius: 1, y: 1)
        }
    }

    private func submit() {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty, let message = onSubmit() else { return }
        confirmationCount += 1
        let current = confirmationCount
        withAnimation(DoneMotion.motion(DoneMotion.appear, reduced: reduceMotion)) { confirmation = message }
        Task {
            try? await Task.sleep(for: .seconds(2))
            guard current == confirmationCount else { return }
            withAnimation(DoneMotion.fade) { confirmation = nil }
        }
    }

    /// Pilule de genre, 38 de haut : surfaceSelected pour le genre choisi, bgSunken pour les autres.
    private struct KindPillStyle: ButtonStyle {
        let isOn: Bool

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.sans(13, .semibold))
                .foregroundStyle(isOn ? DoneColor.textPrimary : DoneColor.textSecondary)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(isOn ? DoneColor.surfaceSelected : DoneColor.bgSunken, in: Capsule(style: .continuous))
                .contentShape(Capsule(style: .continuous))
                .donePress(configuration.isPressed)
                .animation(DoneMotion.hover, value: isOn)
        }
    }

    /// Bouton d'envoi : rond de 38, actionPrimary.
    private struct SendButtonStyle: ButtonStyle {
        @Environment(\.isEnabled) private var isEnabled

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .foregroundStyle(isEnabled ? DoneColor.actionOnPrimary : DoneColor.textDisabled)
                .frame(width: 38, height: 38)
                .background(
                    isEnabled ? (configuration.isPressed ? DoneColor.actionPrimaryPressed : DoneColor.actionPrimary) : DoneColor.actionDisabled,
                    in: Circle()
                )
                .contentShape(Circle())
                .donePress(configuration.isPressed, scale: 0.94)
        }
    }
}

/// La barre de saisie branchée sur Done : une tâche passe par `QuickEntry` et va dans l'Inbox (ou le
/// projet compris), une note est créée, une réunion ouvre sa feuille avec le titre déjà saisi.
/// ⌘ Entrée ouvre la saisie complète d'une tâche, ou la note créée.
struct HomeCaptureBar: View {
    @Environment(AppModel.self) private var model
    @State private var text = ""
    @State private var kind: CaptureBar.Kind = .task
    @State private var fullCapture = false
    @State private var meetingRequest: MeetingRequest?
    @State private var openedNote: NoteRef?

    var body: some View {
        CaptureBar(text: $text, kind: $kind, onSubmit: submit, onExpand: expand)
            .sheet(isPresented: $fullCapture) {
                CaptureSheet(draft: TaskDraft(title: text)) { text = "" }
                    .environment(model)
            }
            .sheet(item: $meetingRequest) { request in
                MeetingSheet(meeting: request.meeting, start: request.start, end: request.end, title: request.title)
                    .environment(model)
            }
            .sheet(item: $openedNote) { ref in
                NoteSheet(noteID: ref.id)
                    .environment(model)
            }
    }

    private func submit() -> String? {
        let title = text.trimmingCharacters(in: .whitespaces)
        switch kind {
        case .task:
            let draft = TaskDraft(title: title).applying(QuickEntry.parse(title))
            guard let task = model.addTask(draft) else { return nil }
            text = ""
            return "Ajoutée dans \(task.projectID == nil ? "Inbox" : model.projectName(task.projectID))"
        case .note:
            NoteBook.shared.create(Note(kind: .note, title: title))
            text = ""
            return "Note ajoutée"
        case .meeting:
            openMeeting(title)
            return nil
        }
    }

    private func expand() {
        let title = text.trimmingCharacters(in: .whitespaces)
        switch kind {
        case .task:
            fullCapture = true
        case .note:
            guard !title.isEmpty else { return }
            openedNote = NoteRef(id: NoteBook.shared.create(Note(kind: .note, title: title)).id)
            text = ""
        case .meeting:
            openMeeting(title)
        }
    }

    private func openMeeting(_ title: String) {
        let start = MeetingSheet.nextQuarter(after: .now)
        meetingRequest = MeetingRequest(start: start, end: start.addingTimeInterval(3600), title: title)
        text = ""
    }
}

// MARK: Rail

/// Les écrans du rail, dans l'ordre, avec leur raccourci.
enum RailDestination: String, CaseIterable, Identifiable {
    case home, calendar, notes, lists, stats, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Ma journée"
        case .calendar: "Calendrier"
        case .notes: "Notes"
        case .lists: "Listes"
        case .stats: "Stats"
        case .settings: "Réglages"
        }
    }

    var symbol: String {
        switch self {
        case .home: "sun.max"
        case .calendar: "calendar"
        case .notes: "doc.text"
        case .lists: "list.bullet"
        case .stats: "chart.bar"
        case .settings: "gearshape"
        }
    }

    var shortcut: String {
        switch self {
        case .home: "⌘1"
        case .calendar: "⌘2"
        case .notes: "⌘3"
        case .lists: "⌘4"
        case .stats: "⌘5"
        case .settings: "⌘,"
        }
    }
}

/// Rail d'icônes à gauche de la fenêtre : 84 de large, boutons ronds de 44 espacés de 10, icônes de 19,
/// sur bgSunken à 70 % avec flou et un trait borderSubtle à droite. En haut, sous les feux de la
/// fenêtre, « Capturer » en braise ; puis les cinq écrans ; en bas, les Réglages et le logo, qui
/// montre le minuteur pendant une session. L'écran affiché est plein actionPrimary, les autres sur
/// surfaceDefault avec shadowCard. Listes porte une pastille braise : les tâches de l'Inbox à trier.
struct Rail: View {
    let selection: RailDestination?
    /// Tâches de l'Inbox à trier : la pastille de Listes, cachée à zéro.
    var inboxCount = 0
    /// Minuteur d'une session en cours (« 18:42 »), à la place du logo.
    var timer: String?
    /// Augmente quand le plan du jour vient d'être bouclé : le soleil de Ma journée fait un éclat.
    var homeBursts = 0
    let onCapture: () -> Void
    let onSelect: (RailDestination) -> Void
    /// Clic sur le minuteur : retour à la session.
    var onTimer: () -> Void = {}

    var body: some View {
        VStack(spacing: 10) {
            Button(action: onCapture) {
                Image(systemName: "plus")
                    .font(.system(size: 19, weight: .medium))
            }
            .buttonStyle(RailButtonStyle(fill: DoneColor.accent, foreground: DoneColor.onAccent, hasShadow: true))
            .help("Capturer (⌘N)")
            .accessibilityLabel("Capturer")
            .padding(.bottom, DoneSpace.s6)
            ForEach(RailDestination.allCases.filter { $0 != .settings }) { destination in
                item(destination)
            }
            Spacer(minLength: DoneSpace.s16)
            item(.settings)
            logo
                .padding(.top, DoneSpace.s6)
        }
        .padding(.top, 52)
        .padding(.bottom, DoneSpace.s20)
        .frame(width: 84)
        .frame(maxHeight: .infinity)
        .background(DoneColor.bgSunken.opacity(0.7))
        .background(.ultraThinMaterial)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(DoneColor.borderSubtle)
                .frame(width: 1)
        }
    }

    private func item(_ destination: RailDestination) -> some View {
        let isSelected = selection == destination
        return Button {
            onSelect(destination)
        } label: {
            Image(systemName: destination.symbol)
                .font(.system(size: 19, weight: .regular))
        }
        .buttonStyle(RailButtonStyle(
            fill: isSelected ? DoneColor.actionPrimary : DoneColor.surfaceDefault,
            foreground: isSelected ? DoneColor.actionOnPrimary : DoneColor.textPrimary,
            hasShadow: !isSelected
        ))
        .overlay(alignment: .topTrailing) {
            if destination == .lists && inboxCount > 0 {
                Text(inboxCount > 99 ? "99+" : "\(inboxCount)")
                    .font(.sans(10, .bold).monospacedDigit())
                    .foregroundStyle(DoneColor.onAccent)
                    .padding(.horizontal, 5)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(DoneColor.accent, in: Capsule(style: .continuous))
                    .offset(x: 4, y: -4)
                    .accessibilityHidden(true)
            }
        }
        .background {
            if destination == .home {
                SunBurst(count: homeBursts, distance: 30, scale: 0.7)
            }
        }
        .help("\(destination.title) (\(destination.shortcut))")
        .accessibilityLabel(destination == .lists && inboxCount > 0 ? "\(destination.title), \(inboxCount) dans l'Inbox" : destination.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var logo: some View {
        if let timer {
            Button(action: onTimer) {
                Text(timer)
                    .font(.done(.numericS))
                    .foregroundStyle(DoneColor.textPrimary)
                    .frame(width: 56, height: 28)
                    .background(DoneColor.surfaceDefault, in: Capsule(style: .continuous))
                    .overlay(Capsule(style: .continuous).strokeBorder(DoneColor.borderSubtle, lineWidth: 1))
                    .contentShape(Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Revenir à la session (⌘1)")
        } else {
            DoneAppIcon(size: 32)
                .accessibilityHidden(true)
        }
    }

    /// Bouton rond de 44 du rail, qui se tasse à l'appui.
    private struct RailButtonStyle: ButtonStyle {
        let fill: Color
        let foreground: Color
        let hasShadow: Bool

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .foregroundStyle(foreground)
                .frame(width: 44, height: 44)
                .background(fill, in: Circle())
                .overlay(Circle().fill(DoneColor.textPrimary.opacity(configuration.isPressed ? 0.08 : 0)))
                .shadow(color: hasShadow ? DoneColor.shadowCard : .clear, radius: 15, y: 10)
                .shadow(color: hasShadow ? DoneColor.shadowCardNear : .clear, radius: 1, y: 1)
                .contentShape(Circle())
                .donePress(configuration.isPressed, scale: 0.94)
        }
    }
}

// MARK: Aperçus

#Preview("Salutation") {
    Greeting(
        date: .now,
        salutation: DayGreeting.salutation(at: .now, name: "Camille"),
        summary: DaySummary.sentence(
            DaySummary.sentence(.init(openTasks: 3, hasPlan: true, meetingsLeft: 2)),
            after: DayGreeting.salutation(at: .now, name: "Camille")
        )
    )
    .padding(36)
    .frame(width: 1000)
    .background(DoneCanvas())
}

/// La barre de saisie seule, avec son propre état, pour l'aperçu.
private struct CaptureBarPreview: View {
    @State private var text = ""
    @State private var kind = CaptureBar.Kind.task

    var body: some View {
        CaptureBar(text: $text, kind: $kind, onSubmit: { "Ajoutée dans Inbox" }, onExpand: {})
    }
}

#Preview("Barre de saisie") {
    CaptureBarPreview()
        .padding(36)
        .frame(width: 760)
        .background(DoneCanvas())
}

#Preview("Rail") {
    Rail(selection: .home, inboxCount: 4, onCapture: {}, onSelect: { _ in })
        .frame(height: 760)
        .background(DoneCanvas())
}
