import SwiftData
import SwiftUI

/// Ma journée (⌘1), l'écran d'arrivée : la salutation en haut, avec la recherche et « Capturer » ;
/// six cartes en trois colonnes (1,25 / 1 / 1) sur deux rangées (prochaine action, ligne de temps,
/// plan du jour ; échéances, notes, focus du jour) ; la barre de saisie en bas. Sous 1 150 de large
/// utile, la grille passe à deux colonnes et défile, la carte Notes en dernier. Le clavier des
/// listes (↑ ↓, Espace, ↩) parcourt le plan puis les échéances.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(FocusEngine.self) private var engine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \FocusSession.startedAt) private var sessions: [FocusSession]
    @AppStorage(SettingsKey.firstName) private var firstName = ""
    /// ⌘K : la recherche prend le focus.
    @Binding var searchRequested: Bool
    let onCapture: () -> Void
    let open: (RootView.Screen) -> Void

    @State private var ignoreMeetings = false
    @State private var showPlan = false
    @State private var editing: TodoTask?
    @State private var meetingRequest: MeetingRequest?
    @State private var openedNote: NoteRef?
    @State private var planDropTarget = false
    @FocusState private var listFocused: Bool
    @State private var selectedID: String?
    @State private var hovered: String?

    private static let spacing: CGFloat = 16

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            let suggestion = Planner.suggest(
                plan: model.planIDs,
                index: model.index,
                meetings: model.meetingsToday,
                rules: model.rules,
                now: now,
                ignoreMeetings: ignoreMeetings
            )
            let plan = model.planIDs.compactMap { model.store[$0] }.filter(\.isOpen)
            let due = DayAgenda.dueOrLate(in: model.index.all, plan: model.planIDs, today: now)
            let order = (plan + due).map(\.id)
            VStack(alignment: .leading, spacing: DoneSpace.s20) {
                header(now: now, openTasks: plan.count)
                    // Les résultats de la recherche passent par-dessus les cartes.
                    .zIndex(1)
                GeometryReader { proxy in
                    ScrollView {
                        grid(size: proxy.size, now: now, suggestion: suggestion, plan: plan, due: due)
                    }
                    .scrollIndicators(.never)
                    .scrollClipDisabled()
                }
                .focusable()
                .focusEffectDisabled()
                .focused($listFocused)
                .onKeyPress(keys: [.upArrow, .downArrow]) { press in
                    selectedID = ListSelection.step(selectedID, by: press.key == .upArrow ? -1 : 1, in: order)
                    return .handled
                }
                .onKeyPress(.space) {
                    guard let selectedID, let task = model.store[selectedID] else { return .ignored }
                    toggle(task)
                    return .handled
                }
                .onKeyPress(.return) {
                    guard let selectedID, let task = model.store[selectedID] else { return .ignored }
                    editing = task
                    return .handled
                }
                .onChange(of: order) { old, new in
                    selectedID = ListSelection.keep(selectedID, old: old, new: new)
                }
                .onChange(of: listFocused) {
                    if listFocused, selectedID == nil { selectedID = order.first }
                }
                HomeCaptureBar()
            }
            .padding(.horizontal, 36)
            .padding(.top, 30)
            .padding(.bottom, DoneSpace.s20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // À l'ouverture, les cartes ont le focus : les raccourcis des listes marchent tout de suite.
        .onAppear {
            listFocused = true
            // La semaine a pu avancer : les réunions récurrentes de la semaine prochaine arrivent.
            model.refreshMeetingSeries()
        }
        .sheet(isPresented: $showPlan) {
            PlanSheet()
                .environment(model)
        }
        .sheet(item: $editing) { task in
            TaskEditorSheet(taskID: task.id)
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

    // MARK: En-tête

    private func header(now: Date, openTasks: Int) -> some View {
        let calendar = Calendar.current
        let meetings = model.meetingsToday
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now
        let facts = DaySummary.Facts(
            absence: model.absence(on: now)?.title,
            openTasks: openTasks,
            hasPlan: model.todayPlan != nil,
            planFinished: model.isPlanFinished,
            meetingsLeft: meetings.filter { $0.end > now }.count,
            afternoonFree: calendar.component(.hour, from: now) < 12 && !meetings.contains { $0.end > noon }
        )
        let name = DaySummary.firstName(setting: firstName, fullName: NSFullUserName())
        return HStack(alignment: .top, spacing: DoneSpace.s16) {
            Greeting(
                date: now,
                salutation: DaySummary.salutation(at: now, name: name),
                summary: DaySummary.sentence(facts, at: now)
            )
            Spacer(minLength: DoneSpace.s16)
            HStack(spacing: 10) {
                GlobalSearchBox(focusRequest: $searchRequested)
                Button(action: onCapture) {
                    HStack(spacing: DoneSpace.s8) {
                        Image(systemName: "plus")
                        Text("Capturer")
                        KeyCap(key: "⌘N")
                    }
                }
                .buttonStyle(DoneButtonStyle())
                .help("Nouvelle tâche avec tous ses détails (⌘N)")
            }
        }
    }

    // MARK: Grille

    @ViewBuilder
    private func grid(size: CGSize, now: Date, suggestion: Suggestion, plan: [TodoTask], due: [TodoTask]) -> some View {
        let spacing = Self.spacing
        if size.width >= 1150 {
            let unit = (size.width - 2 * spacing) / 3.25
            let rowHeight = max((size.height - spacing) / 2, 260)
            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    nextActionCard(suggestion: suggestion, now: now)
                        .frame(width: unit * 1.25, height: rowHeight)
                    timelineCard(now: now, suggestion: suggestion)
                        .frame(width: unit, height: rowHeight)
                    planCard(plan)
                        .frame(width: unit, height: rowHeight)
                }
                HStack(spacing: spacing) {
                    dueCard(due)
                        .frame(width: unit * 1.25, height: rowHeight)
                    notesCard(now: now)
                        .frame(width: unit, height: rowHeight)
                    focusCard(now: now)
                        .frame(width: unit, height: rowHeight)
                }
            }
        } else {
            let column = (size.width - spacing) / 2
            let rowHeight: CGFloat = 300
            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    nextActionCard(suggestion: suggestion, now: now)
                        .frame(width: column, height: rowHeight)
                    timelineCard(now: now, suggestion: suggestion)
                        .frame(width: column, height: rowHeight)
                }
                HStack(spacing: spacing) {
                    planCard(plan)
                        .frame(width: column, height: rowHeight)
                    dueCard(due)
                        .frame(width: column, height: rowHeight)
                }
                HStack(spacing: spacing) {
                    focusCard(now: now)
                        .frame(width: column, height: rowHeight)
                    notesCard(now: now)
                        .frame(width: column, height: rowHeight)
                }
            }
            .padding(.bottom, DoneSpace.s8)
        }
    }

    // MARK: 1. Prochaine action

    private func nextActionCard(suggestion: Suggestion, now: Date) -> some View {
        NextActionCard(
            suggestion: suggestion,
            now: now,
            ignoreMeetings: $ignoreMeetings,
            openPlan: { showPlan = true },
            openInbox: { open(.lists(.inbox)) }
        )
    }

    /// Lance la prochaine action proposée, ou la pause due avant de changer de tâche.
    private func startNext(_ suggestion: Suggestion, now: Date) {
        guard suggestion.status == .ready, let action = suggestion.action, let root = suggestion.planTask else { return }
        if engine.needsBreak(before: root, now: now), let pause = engine.breakDue?.remainingMinutes(now: now) {
            engine.takeBreak(minutes: pause, mandatory: true)
        } else {
            engine.start(action: action, root: root, minutes: suggestion.minutes)
        }
    }

    // MARK: 2. Ligne de temps

    private func timelineCard(now: Date, suggestion: Suggestion) -> some View {
        let hour = Calendar.current.component(.hour, from: now)
        // De l'heure courante moins une jusqu'à 19:00 (ou un peu plus tard le soir).
        let first = min(max(hour - 1, 0), 21)
        let last = min(max(DayTimeline.lastHour, first + 2), 23)
        let hourHeight: CGFloat = 40
        return WidgetCard(title: "Ma journée", link: "Calendrier", onLink: { open(.calendar) }) {
            ScrollView {
                HStack(alignment: .top, spacing: 0) {
                    HourLabels(hourHeight: hourHeight, firstHour: first, lastHour: last, now: now)
                        .frame(width: 46)
                    DayTimeline(
                        day: now,
                        now: now,
                        hourHeight: hourHeight,
                        sessions: sessions,
                        firstHour: first,
                        lastHour: last,
                        showsFreeSlots: true,
                        onFreeSlot: suggestion.status == .ready ? { _ in startNext(suggestion, now: now) } : nil
                    ) { meeting in
                        meetingRequest = MeetingRequest(meeting: meeting)
                    } onSlot: { start in
                        meetingRequest = MeetingRequest(start: start, end: start.addingTimeInterval(3600))
                    }
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(DoneColor.borderSubtle).frame(width: 1)
                    }
                }
                .frame(height: hourHeight * CGFloat(last - first))
                .padding(.vertical, DoneSpace.s8)
            }
            .scrollIndicators(.never)
        }
    }

    // MARK: 3. Plan du jour

    private func planCard(_ plan: [TodoTask]) -> some View {
        let doneTasks = (model.todayPlan?.doneIDs ?? []).compactMap { model.store[$0] }.filter { !$0.isOpen }
        let total = doneTasks.count + plan.count
        return WidgetCard(title: "Plan du jour", link: total == 0 ? "Choisir" : "Modifier", onLink: { showPlan = true }) {
            VStack(alignment: .leading, spacing: DoneSpace.s12) {
                if total > 0 {
                    ProgressBar(fraction: Double(doneTasks.count) / Double(total))
                }
                if plan.isEmpty, model.isPlanFinished {
                    NoticeBox(text: "Plan du jour terminé. Tout ce qui était prévu est fait.", tone: .success)
                }
                if total == 0 {
                    emptyLine("Pas encore de plan. Glisse ici une tâche des échéances, ou choisis-les.")
                }
                ScrollView {
                    VStack(spacing: DoneSpace.s2) {
                        ForEach(doneTasks) { task in
                            doneRow(task)
                        }
                        ForEach(Array(plan.enumerated()), id: \.element.id) { index, task in
                            row(task, number: index + 1)
                        }
                    }
                    .animation(DoneMotion.motion(DoneMotion.travel, reduced: reduceMotion), value: plan.map(\.id) + doneTasks.map(\.id))
                }
                .scrollIndicators(.never)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: DoneRadius.lg, style: .continuous)
                .strokeBorder(DoneColor.focusRing, lineWidth: planDropTarget ? 2 : 0)
        }
        // Une tâche glissée depuis les échéances (ou une liste) rejoint le plan.
        .dropDestination(for: String.self) { ids, _ in
            ids.forEach { model.addToPlan($0) }
            return !ids.isEmpty
        } isTargeted: { planDropTarget = $0 }
    }

    private func doneRow(_ task: TodoTask) -> some View {
        HStack(spacing: DoneSpace.s12) {
            TaskCheckbox(isDone: true) { model.reopen(task) }
            TaskTitle(title: task.title, isFinishing: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            StateChip(kind: .doneToday, title: "Fait")
        }
        .padding(.horizontal, DoneSpace.s12)
        .frame(minHeight: 40)
    }

    // MARK: 4. Échéances et retards

    private func dueCard(_ due: [TodoTask]) -> some View {
        WidgetCard(title: "Échéances et retards", link: "Tout voir", onLink: { open(.calendar) }) {
            if due.isEmpty {
                emptyLine("Aucune échéance aujourd'hui, et rien en retard.")
            } else {
                ScrollView {
                    VStack(spacing: DoneSpace.s2) {
                        ForEach(due) { task in
                            row(task)
                                .draggable(task.id)
                        }
                    }
                    .animation(DoneMotion.motion(DoneMotion.travel, reduced: reduceMotion), value: due.map(\.id))
                }
                .scrollIndicators(.never)
            }
        }
    }

    // MARK: Lignes

    private func row(_ task: TodoTask, number: Int? = nil) -> some View {
        let finishing = model.finishing.contains(task.id)
        return HStack(spacing: DoneSpace.s12) {
            TaskCheckbox(isDone: finishing, bursts: true) { toggle(task) }
            if let number {
                NumberTile(position: number)
            }
            TaskRowContent(task: task, isFinishing: finishing)
        }
        .padding(.horizontal, DoneSpace.s12)
        .frame(minHeight: 48)
        .background(rowBackground(task.id), in: RoundedRectangle(cornerRadius: DoneRadius.md, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            selectedID = task.id
            listFocused = true
            editing = task
        }
        .onHover { inside in
            if inside {
                hovered = task.id
            } else if hovered == task.id {
                hovered = nil
            }
        }
        // Les pétales passent par-dessus les lignes voisines.
        .zIndex(finishing ? 1 : 0)
        .transition(taskRowTransition(reduced: reduceMotion))
    }

    /// Ligne choisie au clavier en surface.selected, survol en surface.hover.
    private func rowBackground(_ id: String) -> Color {
        if listFocused, selectedID == id { return DoneColor.surfaceSelected }
        return hovered == id ? DoneColor.surfaceHover : Color.clear
    }

    /// Cocher laisse une seconde à la ligne pour le montrer ; recliquer pendant ce temps annule.
    private func toggle(_ task: TodoTask) {
        if model.finishing.contains(task.id) {
            model.cancelFinishing(task.id)
        } else {
            model.completeSoon(task)
        }
    }

    private func emptyLine(_ text: String) -> some View {
        Text(text)
            .doneText(.callout)
            .foregroundStyle(DoneColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: 5. Notes

    private func notesCard(now: Date) -> some View {
        let book = NoteBook.shared
        let journal = book.journal(for: now)
        let others = Array(book.notes.filter { $0.id != journal?.id }.prefix(5))
        return WidgetCard(title: "Notes", link: "Toutes les notes", onLink: { open(.notes) }) {
            ScrollView {
                MasonryLayout(columns: 2, spacing: 10) {
                    if let journal {
                        NoteCard(note: journal) { openedNote = NoteRef(id: journal.id) }
                    } else {
                        NewNoteTile(title: "Journal du jour…") {
                            openedNote = NoteRef(id: book.ensureJournal(for: now).id)
                        }
                    }
                    ForEach(others) { note in
                        NoteCard(note: note) { openedNote = NoteRef(id: note.id) }
                    }
                    NewNoteTile {
                        openedNote = NoteRef(id: book.create(Note(kind: .note, title: "Nouvelle note")).id)
                    }
                }
            }
            .scrollIndicators(.never)
        }
    }

    // MARK: 6. Focus aujourd'hui

    private func focusCard(now: Date) -> some View {
        let calendar = Calendar.current
        let today = sessions.filter { calendar.isDate($0.startedAt, inSameDayAs: now) }.map(\.fact)
        let minutes = DayTimeline.focusMinutes(on: now, in: sessions)
        let pomodoros = Stats.pomodoros(today, on: now)
        let checked = DayAgenda.doneToday(in: model.store.tasks, today: now).count
        let inbox = model.openCount(in: .inbox)
        return WidgetCard(title: "Focus aujourd'hui", link: "Stats", onLink: { open(.stats) }) {
            VStack(alignment: .leading, spacing: DoneSpace.s12) {
                Text(minutes > 0 ? Format.minutes(minutes) : "0 min")
                    .doneText(.numericL)
                    .foregroundStyle(DoneColor.textPrimary)
                HStack(spacing: DoneSpace.s6) {
                    ForEach(0..<min(pomodoros, 8), id: \.self) { _ in
                        Circle().fill(DoneColor.accent).frame(width: 10, height: 10)
                    }
                    if pomodoros < 8 {
                        Circle()
                            .strokeBorder(DoneColor.borderDefault, lineWidth: 1.5)
                            .frame(width: 10, height: 10)
                    }
                    Text(pomodoros > 0 ? "\(Format.ordinal(pomodoros)) pomodoro" : "Pas encore de pomodoro")
                        .font(.sans(12, .semibold))
                        .foregroundStyle(pomodoros > 0 ? DoneColor.accentText : DoneColor.textSecondary)
                        .padding(.leading, DoneSpace.s4)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(pomodoros) pomodoro\(pomodoros > 1 ? "s" : "") aujourd'hui")
                VStack(spacing: DoneSpace.s8) {
                    statLine("Tâches cochées", checked)
                    Hairline()
                    statLine("Inbox à trier", inbox)
                }
                Spacer(minLength: 0)
                weekBars(now: now)
            }
        }
    }

    private func statLine(_ title: String, _ value: Int) -> some View {
        HStack {
            Text(title)
                .doneText(.callout)
                .foregroundStyle(DoneColor.textSecondary)
            Spacer()
            Text("\(value)")
                .doneText(.numericM)
                .foregroundStyle(DoneColor.textPrimary)
        }
    }

    /// Focus des jours de la semaine : barres cobalt claires, aujourd'hui en plein.
    private func weekBars(now: Date) -> some View {
        let calendar = Calendar.current
        let week = Stats.week(containing: now)
        let byDay = Stats.byDay(sessions.filter { week.contains($0.startedAt) }.map(\.fact), in: week)
        var days = WorkWeek.days(containing: now)
        if !days.contains(where: { calendar.isDate($0, inSameDayAs: now) }) {
            days.append(calendar.startOfDay(for: now))
        }
        let minutes = days.map { day in byDay.first { calendar.isDate($0.day, inSameDayAs: day) }?.minutes ?? 0 }
        let most = max(minutes.max() ?? 0, 1)
        return HStack(alignment: .bottom, spacing: DoneSpace.s6) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                let isToday = calendar.isDate(day, inSameDayAs: now)
                VStack(spacing: DoneSpace.s4) {
                    RoundedRectangle(cornerRadius: DoneRadius.xs, style: .continuous)
                        .fill(isToday ? DoneColor.stateActive : DoneColor.stateActiveTint)
                        .frame(height: max(4, 32 * CGFloat(minutes[index] / most)))
                        .frame(height: 32, alignment: .bottom)
                    Text(Format.weekdayInitial(day))
                        .font(.done(.numericS))
                        .foregroundStyle(isToday ? DoneColor.textPrimary : DoneColor.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .help("\(Format.longDay(day)) : \(Format.minutes(minutes[index]))")
            }
        }
    }
}

// MARK: Carte widget

/// Carte widget de Ma journée : étiquette à gauche (avec un accessoire éventuel), lien à droite en
/// stateActiveText qui ouvre l'écran complet, puis le contenu. Marges 22 × 20, rayon lg, shadowCard.
struct WidgetCard<Accessory: View, Content: View>: View {
    let title: String
    var link: String?
    var onLink: () -> Void = {}
    @ViewBuilder let accessory: Accessory
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DoneSpace.s12) {
            HStack(spacing: DoneSpace.s8) {
                Eyebrow(text: title)
                accessory
                Spacer(minLength: DoneSpace.s8)
                if let link {
                    Button(link, action: onLink)
                        .buttonStyle(.plain)
                        .font(.sans(12, .semibold))
                        .foregroundStyle(DoneColor.stateActiveText)
                }
            }
            .frame(minHeight: 22)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, DoneSpace.s20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .doneCard()
    }
}

extension WidgetCard where Accessory == EmptyView {
    init(title: String, link: String? = nil, onLink: @escaping () -> Void = {}, @ViewBuilder content: () -> Content) {
        self.title = title
        self.link = link
        self.onLink = onLink
        self.accessory = EmptyView()
        self.content = content()
    }
}

// MARK: Prochaine action

/// Carte « Prochaine action » : l'étape proposée en displayL, sa tâche, ses puces, l'anneau de la durée
/// (un clic la change), « Lancer le focus », « Découper… », et le temps libre avant la prochaine
/// réunion. Selon la journée : bilan du soir, jour de congé, pas de plan, plan terminé ou bloqué,
/// pas le temps avant une réunion.
private struct NextActionCard: View {
    @Environment(AppModel.self) private var model
    @Environment(FocusEngine.self) private var engine
    let suggestion: Suggestion
    let now: Date
    @Binding var ignoreMeetings: Bool
    let openPlan: () -> Void
    let openInbox: () -> Void

    @State private var customMinutes: MinutesOverride?
    @State private var showDurations = false
    @State private var showPicker = false
    @State private var breakdownTask: TodoTask?
    @State private var showReview = false
    /// « Plus tard » sur le bilan du soir : la prochaine action revient jusqu'à la prochaine ouverture.
    @State private var reviewLater = false
    /// Jour d'absence : on peut quand même demander une tâche.
    @State private var workAnyway = false

    private struct MinutesOverride {
        let taskID: String
        let minutes: Int
    }

    var body: some View {
        Group {
            if model.isReviewDue && !reviewLater {
                review
            } else if let absence = model.absence(on: now), !workAnyway {
                absent(absence)
            } else {
                switch suggestion.status {
                case .ready:
                    ready
                case .planEmpty:
                    planEmpty
                case .allBlocked:
                    allBlocked
                case .noTimeBeforeMeeting:
                    noTime
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            TaskPickerView(title: "Changer de tâche") { model.putFirst($0.id) }
                .environment(model)
        }
        .sheet(item: $breakdownTask) { task in
            BreakdownSheet(task: task)
                .environment(model)
        }
        .sheet(isPresented: $showReview) {
            ReviewSheet()
                .environment(model)
                .modelContext(model.context)
        }
    }

    // MARK: Prête

    @ViewBuilder
    private var ready: some View {
        if let action = suggestion.action, let root = suggestion.planTask {
            let minutes = customMinutes.flatMap { $0.taskID == action.id ? $0.minutes : nil } ?? suggestion.minutes
            let pause = engine.needsBreak(before: root, now: now) ? engine.breakDue?.remainingMinutes(now: now) : nil
            WidgetCard(title: "Prochaine action") {
                positionChip
            } content: {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: DoneSpace.s16) {
                        VStack(alignment: .leading, spacing: DoneSpace.s8) {
                            Text(action.title)
                                .doneText(.displayL)
                                .foregroundStyle(DoneColor.textPrimary)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(contextLine(action: action, root: root))
                                .doneText(.callout)
                                .foregroundStyle(DoneColor.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        durationRing(minutes: minutes, action: action, root: root)
                    }
                    TaskChips(task: action)
                        .padding(.top, DoneSpace.s12)
                    if let resume = model.resumeNote(for: action.id) {
                        Text("Où tu en étais : \(resume.text)")
                            .doneText(.callout)
                            .foregroundStyle(DoneColor.textSecondary)
                            .lineLimit(2)
                            .padding(.top, DoneSpace.s8)
                    }
                    if let note = suggestion.note {
                        Text(note)
                            .doneText(.callout)
                            .foregroundStyle(DoneColor.stateActiveText)
                            .lineLimit(2)
                            .padding(.top, DoneSpace.s8)
                    }
                    Spacer(minLength: DoneSpace.s12)
                    if let pause {
                        Text("Tu changes de tâche : \(pause) min de pause d'abord.")
                            .doneText(.callout)
                            .foregroundStyle(DoneColor.stateActiveText)
                            .padding(.bottom, DoneSpace.s8)
                    }
                    HStack(alignment: .bottom, spacing: DoneSpace.s8) {
                        if let pause {
                            Button("Démarrer la pause · \(pause) min") {
                                engine.takeBreak(minutes: pause, mandatory: true)
                            }
                            .buttonStyle(DoneButtonStyle(kind: .primary))
                        } else {
                            Button {
                                engine.start(action: action, root: root, minutes: minutes)
                            } label: {
                                Label("Lancer le focus", systemImage: "play.fill")
                            }
                            .buttonStyle(DoneButtonStyle(kind: .primary))
                        }
                        if Planner.canBreakDown(action: action, root: root) {
                            Button("Découper…") { breakdownTask = action }
                                .buttonStyle(DoneButtonStyle())
                                .help(Planner.needsBreakdown(action: action, root: root, in: model.index)
                                    ? "Cette tâche n'a pas encore de sous-tâche"
                                    : "Ajouter une étape plus petite sous cette action")
                        }
                        Menu {
                            Button("Changer de tâche…") { showPicker = true }
                            if suggestion.position > 0 {
                                Button("Passer, la mettre en fin de plan") { model.skip(root.id) }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .fixedSize()
                        .help("Autres choix")
                        Spacer(minLength: DoneSpace.s8)
                        freeTime
                    }
                }
            }
        }
    }

    /// « • Tâche 1 sur 3 », ou « Hors plan », en accentText sur accentTint.
    private var positionChip: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(DoneColor.accent)
                .frame(width: 5, height: 5)
            Text(suggestion.position > 0 ? "Tâche \(suggestion.position) sur \(suggestion.planCount)" : "Hors plan")
        }
        .font(.sans(12, .semibold))
        .foregroundStyle(DoneColor.accentText)
        .padding(.horizontal, DoneSpace.s8)
        .frame(height: 22)
        .background(DoneColor.accentTint, in: Capsule(style: .continuous))
        .fixedSize()
    }

    /// La tâche de l'étape et sa place (« étape 2 sur 5 »), ou la liste de la tâche.
    private func contextLine(action: TodoTask, root: TodoTask) -> String {
        guard action.id != root.id else { return model.listName(for: root) }
        let steps = model.store.tasks
            .filter { $0.parentID == action.parentID }
            .sorted { $0.position < $1.position }
        if let index = steps.firstIndex(where: { $0.id == action.id }), action.parentID == root.id {
            return "\(root.title) · étape \(index + 1) sur \(steps.count)"
        }
        return root.title
    }

    /// Anneau de 86 en braise, la durée au centre ; un clic propose une autre durée.
    private func durationRing(minutes: Int, action: TodoTask, root: TodoTask) -> some View {
        let kind = action.kind == .normal ? root.kind : action.kind
        return Button {
            showDurations = true
        } label: {
            ZStack {
                ProgressRing(fraction: 1, color: DoneColor.pomodoroFocus, lineWidth: 6)
                VStack(spacing: 0) {
                    Text("\(minutes):00")
                        .font(.sans(19, .semibold).monospacedDigit())
                        .foregroundStyle(DoneColor.textPrimary)
                    Text(kind == .normal ? "Session" : kind.label)
                        .doneText(.caption)
                        .foregroundStyle(DoneColor.textSecondary)
                }
            }
            .frame(width: 86, height: 86)
            .contentShape(Circle())
        }
        .buttonStyle(DonePressStyle(scale: 0.96))
        .help("Changer la durée")
        .popover(isPresented: $showDurations, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: DoneSpace.s2) {
                ForEach(Self.durationOptions(including: minutes), id: \.self) { value in
                    Button {
                        customMinutes = MinutesOverride(taskID: action.id, minutes: value)
                        showDurations = false
                    } label: {
                        Text("\(value) min")
                            .font(value == minutes ? .sans(13, .bold) : .done(.body))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(DoneButtonStyle(kind: .plain, fullWidth: true, compact: true))
                }
            }
            .padding(DoneSpace.s8)
            .frame(width: 120)
        }
    }

    private static func durationOptions(including minutes: Int) -> [Int] {
        Array(Set([5, 10, 15, 20, 25, 30, 40, 45, 50, 60, 75, 90, minutes])).sorted()
    }

    /// « Avant 14:00 · 1 h 20 de libre », ou la réunion en cours.
    @ViewBuilder
    private var freeTime: some View {
        let meetings = model.meetingsToday
        if let ongoing = meetings.first(where: { $0.contains(now) }) {
            VStack(alignment: .trailing, spacing: 0) {
                Text("En réunion")
                    .doneText(.caption)
                    .foregroundStyle(DoneColor.textSecondary)
                Text("jusqu'à \(Format.time(ongoing.end))")
                    .font(.sans(13, .semibold))
                    .foregroundStyle(DoneColor.textPrimary)
            }
        } else if let next = meetings.first(where: { $0.start > now }) {
            VStack(alignment: .trailing, spacing: 0) {
                Text("Avant \(Format.time(next.start))")
                    .doneText(.caption)
                    .foregroundStyle(DoneColor.textSecondary)
                (Text(Format.minutes(next.start.timeIntervalSince(now) / 60))
                    .font(.sans(13, .bold))
                    .foregroundStyle(DoneColor.textPrimary)
                    + Text(" de libre")
                    .font(.done(.callout))
                    .foregroundStyle(DoneColor.textSecondary))
            }
            .help("Prochaine réunion : \(next.title)")
        }
    }

    // MARK: Autres états

    private var review: some View {
        WidgetCard(title: "Bilan du soir") {
            message(
                "C'est l'heure du bilan du soir",
                "Regarde ce qui est fait, choisis ce qui revient demain."
            ) {
                Button("Faire le bilan") { showReview = true }
                    .buttonStyle(DoneButtonStyle(kind: .primary))
                Button("Plus tard") { reviewLater = true }
                    .buttonStyle(DoneButtonStyle(kind: .plain))
            }
        }
    }

    private func absent(_ absence: Absence) -> some View {
        WidgetCard(title: "Prochaine action") {
            message("Jour de congé", "\(absence.title). Done ne propose rien aujourd'hui.") {
                Button("Travailler quand même") { workAnyway = true }
                    .buttonStyle(DoneButtonStyle())
            }
        }
    }

    @ViewBuilder
    private var planEmpty: some View {
        if model.isPlanFinished {
            WidgetCard(title: "Prochaine action") {
                message("Plan du jour terminé", "Tout ce qui était prévu est fait.") {
                    Button("Ajouter au plan", action: openPlan)
                        .buttonStyle(DoneButtonStyle())
                }
            }
        } else if model.index.all.isEmpty {
            WidgetCard(title: "Prochaine action") {
                message("Ta liste est vide", "Note ce que tu as à faire dans la barre du bas, ou avec ⌘N, puis choisis par quoi commencer.") {
                    Button("Ouvrir l'Inbox", action: openInbox)
                        .buttonStyle(DoneButtonStyle())
                }
            }
        } else {
            WidgetCard(title: "Prochaine action") {
                message(
                    "Pas encore de plan pour aujourd'hui",
                    "Choisis tes \(model.rules.planSize) tâches les plus importantes. Ça prend moins de deux minutes."
                ) {
                    Button("Préparer le plan", action: openPlan)
                        .buttonStyle(DoneButtonStyle(kind: .primary))
                }
            }
        }
    }

    private var allBlocked: some View {
        let count = model.planIDs.compactMap { model.index[$0] }.count
        return WidgetCard(title: "Prochaine action") {
            message(
                "Ton plan est bloqué pour l'instant",
                count > 1 ? "Aucune des \(count) tâches ne peut avancer pour l'instant." : "Cette tâche ne peut pas avancer pour l'instant."
            ) {
                Button("Revoir le plan", action: openPlan)
                    .buttonStyle(DoneButtonStyle(kind: .primary))
                Button("Faire une pause") { engine.takeBreak(minutes: model.rules.shortBreakMinutes) }
                    .buttonStyle(DoneButtonStyle())
            }
        }
    }

    private var noTime: some View {
        let available = suggestion.minutesBeforeMeeting ?? 0
        let title = suggestion.nextMeeting.map { "\($0.title) à \(Format.time($0.start))" } ?? "Réunion à venir"
        return WidgetCard(title: "Prochaine action") {
            message(title, "Il reste \(Format.minutes(Double(available))). Aucune tâche du plan ne tient dans ce temps.") {
                if let preparation = suggestion.preparation {
                    Button(preparation.title) {
                        engine.start(action: preparation, root: model.index.root(of: preparation), minutes: max(5, available))
                    }
                    .buttonStyle(DoneButtonStyle(kind: .primary))
                }
                Button("Faire une pause") { engine.takeBreak(minutes: max(1, available)) }
                    .buttonStyle(DoneButtonStyle())
                Button("Ignorer la réunion") { ignoreMeetings = true }
                    .buttonStyle(DoneButtonStyle(kind: .plain))
            }
        }
    }

    /// Un état sans action proposée : un titre, une phrase, des boutons en bas.
    private func message<Actions: View>(_ title: String, _ text: String, @ViewBuilder actions: () -> Actions) -> some View {
        VStack(alignment: .leading, spacing: DoneSpace.s8) {
            Text(title)
                .doneText(.displayM)
                .foregroundStyle(DoneColor.textPrimary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Text(text)
                .doneText(.callout)
                .foregroundStyle(DoneColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: DoneSpace.s12)
            HStack(spacing: DoneSpace.s8) {
                actions()
            }
        }
    }
}

// MARK: Feuille du plan

/// « Modifier » du plan du jour : l'écran Plan du jour, en feuille.
private struct PlanSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Fermer") { dismiss() }
                    .buttonStyle(DoneButtonStyle(compact: true))
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, DoneSpace.s16)
            .padding(.top, DoneSpace.s12)
            PlanView(onValidate: { dismiss() })
        }
        .frame(width: 1000, height: 680)
        .background(DoneColor.bgCanvas)
    }
}
