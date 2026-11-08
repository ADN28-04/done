import SwiftData
import SwiftUI

/// La journée d'un coup d'œil. À gauche, les réunions et le focus déjà fait sur une ligne de temps ;
/// à droite, le plan du jour dans l'ordre, les échéances du jour et les retards hors plan, puis ce qui
/// est déjà coché. Le Plan du jour reste l'écran où l'on choisit ses tâches.
struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \FocusSession.startedAt) private var sessions: [FocusSession]
    var openFocus: () -> Void
    var openPlan: () -> Void

    @State private var editing: TodoTask?
    @State private var meetingRequest: MeetingRequest?
    @State private var showDone = false
    @State private var hovered: String?
    @State private var openedNote: NoteRef?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let now = context.date
            let plan = model.planIDs.compactMap { model.store[$0] }.filter(\.isOpen)
            let due = DayAgenda.dueOrLate(in: model.index.all, plan: model.planIDs, today: now)
            let done = DayAgenda.doneToday(in: model.store.tasks, today: now)
            VStack(alignment: .leading, spacing: 0) {
                header(now: now)
                HStack(alignment: .top, spacing: DoneSpace.s32) {
                    timeline(now: now)
                        .frame(width: 320)
                    ScrollView {
                        VStack(alignment: .leading, spacing: DoneSpace.s24) {
                            planSection(plan)
                            dueSection(due)
                            if !done.isEmpty {
                                doneSection(done)
                            }
                        }
                        .padding(.bottom, DoneSpace.s8)
                        // Une tâche cochée glisse vers « Fait aujourd'hui » au lieu de disparaître d'un coup.
                        .animation(
                            DoneMotion.motion(DoneMotion.travel, reduced: reduceMotion),
                            value: plan.map(\.id) + due.map(\.id) + done.map(\.id)
                        )
                    }
                    .scrollIndicators(.never)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .padding(.top, DoneSpace.s20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, DoneSpace.s40)
        .padding(.top, DoneSpace.s4)
        .padding(.bottom, DoneSpace.s24)
        .sheet(item: $editing) { task in
            TaskEditorSheet(taskID: task.id)
                .environment(model)
        }
        .sheet(item: $meetingRequest) { request in
            MeetingSheet(meeting: request.meeting, start: request.start, end: request.end)
                .environment(model)
        }
        .sheet(item: $openedNote) { ref in
            NoteSheet(noteID: ref.id)
                .environment(model)
        }
    }

    // MARK: En-tête

    private func header(now: Date) -> some View {
        let meetings = model.meetingsToday.count
        let focus = DayTimeline.focusMinutes(on: now, in: sessions)
        var parts = [Format.longDay(now).capitalizedFirst, plural(meetings, "réunion")]
        if focus > 0 { parts.append("\(Format.minutes(focus)) de focus") }
        return VStack(alignment: .leading, spacing: DoneSpace.s4) {
            HStack(alignment: .firstTextBaseline) {
                Text("Aujourd'hui")
                    .doneText(.displayL)
                    .foregroundStyle(DoneColor.textPrimary)
                Spacer()
                Button {
                    openedNote = NoteRef(id: NoteBook.shared.ensureJournal(for: now).id)
                } label: {
                    Label("Note du jour", systemImage: "sun.max")
                }
                .buttonStyle(DoneButtonStyle(compact: true))
                .help("Journal du jour : idées, comptes rendus, en vrac")
            }
            Text(parts.joined(separator: " · "))
                .doneText(.body)
                .foregroundStyle(DoneColor.textSecondary)
            if let absence = model.absence(on: now) {
                Label("\(absence.title) : Done ne propose rien aujourd'hui", systemImage: "sun.max")
                    .doneText(.callout)
                    .foregroundStyle(DoneColor.textSecondary)
                    .padding(.top, DoneSpace.s4)
            }
        }
    }

    // MARK: Ligne de temps

    private func timeline(now: Date) -> some View {
        VStack(alignment: .leading, spacing: DoneSpace.s8) {
            HStack {
                Eyebrow(text: "Réunions")
                Spacer()
                Button {
                    let start = MeetingSheet.nextQuarter(after: now)
                    meetingRequest = MeetingRequest(start: start, end: start.addingTimeInterval(3600))
                } label: {
                    Label("Ajouter", systemImage: "plus")
                }
                .buttonStyle(DoneButtonStyle(kind: .plain, compact: true))
            }
            .padding(.leading, DoneSpace.s2)
            GeometryReader { space in
                let hours = CGFloat(DayTimeline.lastHour - DayTimeline.firstHour)
                let hourHeight = DayTimeline.hourHeight(fitting: space.size.height - 2 * DoneSpace.s8)
                ScrollViewReader { proxy in
                    ScrollView {
                        HStack(alignment: .top, spacing: 0) {
                            HourLabels(hourHeight: hourHeight)
                                .frame(width: 52)
                            DayTimeline(day: now, now: now, hourHeight: hourHeight, sessions: sessions) { meeting in
                                meetingRequest = MeetingRequest(meeting: meeting)
                            } onSlot: { start in
                                meetingRequest = MeetingRequest(start: start, end: start.addingTimeInterval(3600))
                            }
                            .frame(maxWidth: .infinity)
                            .overlay(alignment: .leading) {
                                Rectangle().fill(DoneColor.borderSubtle).frame(width: 1)
                            }
                        }
                        .frame(height: hourHeight * hours)
                        .padding(.vertical, DoneSpace.s8)
                        .padding(.trailing, DoneSpace.s8)
                    }
                    .scrollIndicators(.never)
                    .onAppear {
                        let hour = Calendar.current.component(.hour, from: now) - 1
                        proxy.scrollTo(min(max(hour, DayTimeline.firstHour), DayTimeline.lastHour - 1), anchor: .top)
                    }
                }
            }
            .doneCard(radius: DoneRadius.lg)
        }
    }

    // MARK: Tâches

    private func planSection(_ plan: [TodoTask]) -> some View {
        VStack(alignment: .leading, spacing: DoneSpace.s8) {
            HStack(spacing: DoneSpace.s8) {
                Eyebrow(text: plan.isEmpty ? "Plan du jour" : "Plan du jour · \(plan.count)")
                Spacer()
                if !plan.isEmpty {
                    Button("Lancer le focus", action: openFocus)
                        .buttonStyle(DoneButtonStyle(kind: .primary, compact: true))
                }
                Button(plan.isEmpty ? (model.isPlanFinished ? "Ajouter au plan" : "Choisir mes tâches") : "Modifier le plan", action: openPlan)
                    .buttonStyle(DoneButtonStyle(compact: true))
            }
            .padding(.leading, DoneSpace.s2)
            if plan.isEmpty, model.isPlanFinished {
                NoticeBox(text: "Plan du jour terminé. Tout ce qui était prévu est fait.", tone: .success)
            } else if plan.isEmpty {
                emptyLine("Pas encore de plan pour aujourd'hui.")
            } else {
                card {
                    ForEach(Array(plan.enumerated()), id: \.element.id) { index, task in
                        row(task, number: index + 1)
                    }
                }
            }
        }
    }

    private func dueSection(_ tasks: [TodoTask]) -> some View {
        VStack(alignment: .leading, spacing: DoneSpace.s8) {
            Eyebrow(text: tasks.isEmpty ? "Échéances et retards" : "Échéances et retards · \(tasks.count)")
                .padding(.leading, DoneSpace.s2)
            if tasks.isEmpty {
                emptyLine("Aucune échéance aujourd'hui, et rien en retard.")
            } else {
                card {
                    ForEach(tasks) { task in
                        row(task)
                    }
                }
            }
        }
    }

    private func doneSection(_ tasks: [TodoTask]) -> some View {
        VStack(alignment: .leading, spacing: DoneSpace.s8) {
            Button {
                withAnimation(DoneMotion.motion(DoneMotion.move, reduced: reduceMotion)) { showDone.toggle() }
            } label: {
                HStack(spacing: DoneSpace.s6) {
                    Image(systemName: showDone ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DoneColor.textSecondary)
                    Eyebrow(text: "Fait aujourd'hui · \(tasks.count)")
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.leading, DoneSpace.s2)
            if showDone {
                VStack(spacing: DoneSpace.s2) {
                    ForEach(tasks) { task in
                        HStack(spacing: DoneSpace.s12) {
                            TaskCheckbox(isDone: true) { model.reopen(task) }
                            Text(task.title)
                                .doneText(.bodyStrong)
                                .strikethrough(true, color: DoneColor.stateOnDone)
                                .foregroundStyle(DoneColor.stateOnDone)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if let done = task.completedAt {
                                Text(Format.time(done))
                                    .font(.done(.numericS))
                                    .foregroundStyle(DoneColor.textSecondary)
                            }
                        }
                        .padding(.horizontal, DoneSpace.s12)
                        .frame(minHeight: 40)
                    }
                }
                .padding(DoneSpace.s6)
                .background(DoneColor.stateDone, in: RoundedRectangle(cornerRadius: DoneRadius.lg, style: .continuous))
            }
        }
    }

    private func row(_ task: TodoTask, number: Int? = nil) -> some View {
        let finishing = model.finishing.contains(task.id)
        return HStack(spacing: DoneSpace.s12) {
            if let number {
                NumberTile(position: number)
            }
            TaskCheckbox(isDone: finishing, bursts: true) { toggle(task) }
            TaskRowContent(task: task, isFinishing: finishing)
        }
        .padding(.horizontal, DoneSpace.s12)
        .frame(minHeight: 48)
        .background(hovered == task.id ? DoneColor.surfaceHover : Color.clear, in: RoundedRectangle(cornerRadius: DoneRadius.md, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { editing = task }
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

    /// Cocher laisse une seconde à la ligne pour le montrer ; recliquer pendant ce temps annule.
    private func toggle(_ task: TodoTask) {
        if model.finishing.contains(task.id) {
            model.cancelFinishing(task.id)
        } else {
            model.completeSoon(task)
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: DoneSpace.s2) {
            content()
        }
        .padding(DoneSpace.s6)
        .doneCard(radius: DoneRadius.lg)
    }

    private func emptyLine(_ text: String) -> some View {
        Text(text)
            .doneText(.callout)
            .foregroundStyle(DoneColor.textSecondary)
            .padding(.leading, DoneSpace.s2)
    }
}

private extension String {
    /// « jeudi 6 novembre » devient « Jeudi 6 novembre ».
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
