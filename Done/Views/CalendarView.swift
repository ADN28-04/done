import SwiftData
import SwiftUI

/// Semaine de travail, du lundi au vendredi. En haut de chaque jour, les tâches à échéance, à glisser
/// d'un jour à l'autre ; dessous, la grille de 8 h à 19 h avec les réunions (hachurées), le focus déjà
/// fait et l'heure courante. Le menu d'un jour ajoute une réunion ou marque une absence.
struct CalendarView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \FocusSession.startedAt) private var sessions: [FocusSession]

    @State private var weekOffset = 0
    @State private var editing: TodoTask?
    @State private var meetingRequest: MeetingRequest?
    @State private var dropDay: Date?
    @State private var absenceDay: Date?
    @State private var absenceDraft = ""

    private static let firstHour = 8
    private static let lastHour = 19
    /// La grille s'étire sur la hauteur libre ; en dessous de 44 par heure, elle défile.
    private static let minHourHeight: CGFloat = 44
    private static let gutter: CGFloat = 64
    /// Hauteur d'une carte d'échéance, espacement compris.
    private static let dueRow: CGFloat = 30

    /// Une réunion à créer sur un créneau, ou à modifier.
    private struct MeetingRequest: Identifiable {
        let id = UUID()
        var meeting: Meeting?
        var start: Date?
        var end: Date?
    }

    /// Un bloc de la grille : réunion, ou session de focus passée.
    private struct Block: Identifiable {
        enum Kind {
            case meeting(Meeting)
            case focus(title: String, minutes: Double)
        }

        let id: String
        let start: Date
        let end: Date
        let kind: Kind
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let now = context.date
            let days = WorkWeek.days(containing: reference(now))
            // La rangée des échéances suit le jour le plus chargé, jusqu'à cinq cartes ; au-delà, elle défile.
            let busiest = days.map { WorkWeek.dueTasks(on: $0, in: model.index.all, today: now).count }.max() ?? 0
            let dueHeight = min(max(CGFloat(busiest) * Self.dueRow + DoneSpace.s8, 40), 5 * Self.dueRow + DoneSpace.s8)
            VStack(alignment: .leading, spacing: 0) {
                header(days: days, now: now)
                row {
                    ForEach(days, id: \.self) { day in
                        dayHeader(day, now: now)
                    }
                }
                .padding(.top, DoneSpace.s20)
                row {
                    ForEach(days, id: \.self) { day in
                        dueCell(day, now: now, height: dueHeight)
                    }
                } gutter: {
                    Text("Échéances")
                        .doneText(.caption)
                        .foregroundStyle(DoneColor.textSecondary)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.top, DoneSpace.s8)
                }
                Hairline()
                GeometryReader { space in
                    let hours = CGFloat(Self.lastHour - Self.firstHour)
                    let hourHeight = max(Self.minHourHeight, ((space.size.height - 2 * DoneSpace.s8) / hours).rounded(.down))
                    ScrollViewReader { proxy in
                        ScrollView {
                            row {
                                ForEach(days, id: \.self) { day in
                                    dayColumn(day, now: now, hourHeight: hourHeight)
                                }
                            } gutter: {
                                hourLabels(hourHeight)
                            }
                            .frame(height: hourHeight * hours)
                            .padding(.top, DoneSpace.s8)
                            .padding(.bottom, DoneSpace.s8)
                        }
                        .scrollIndicators(.never)
                        .onAppear {
                            let hour = Calendar.current.component(.hour, from: now) - 1
                            proxy.scrollTo(min(max(hour, Self.firstHour), Self.lastHour - 1), anchor: .top)
                        }
                    }
                }
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
        .alert("Absence", isPresented: Binding(get: { absenceDay != nil }, set: { if !$0 { absenceDay = nil } })) {
            TextField("Par exemple Férié : Armistice", text: $absenceDraft)
            Button("Annuler", role: .cancel) { absenceDay = nil }
            Button("Enregistrer") {
                if let day = absenceDay { model.setAbsence(on: day, title: absenceDraft) }
                absenceDay = nil
            }
        } message: {
            Text("Ce jour-là, Done ne propose rien.")
        }
    }

    // MARK: En-tête

    private func header(days: [Date], now: Date) -> some View {
        let week = WorkWeek.interval(containing: reference(now))
        return HStack(alignment: .bottom, spacing: DoneSpace.s8) {
            VStack(alignment: .leading, spacing: DoneSpace.s4) {
                Text(Format.weekTitle(week))
                    .doneText(.displayL)
                    .foregroundStyle(DoneColor.textPrimary)
                Text(summary(days: days, now: now))
                    .doneText(.body)
                    .foregroundStyle(DoneColor.textSecondary)
            }
            Spacer()
            Button { weekOffset -= 1 } label: { Image(systemName: "chevron.left") }
                .buttonStyle(DoneIconButtonStyle())
                .help("Semaine précédente")
            Button("Cette semaine") { weekOffset = 0 }
                .buttonStyle(DoneButtonStyle())
                .disabled(weekOffset == 0)
            Button { weekOffset += 1 } label: { Image(systemName: "chevron.right") }
                .buttonStyle(DoneIconButtonStyle())
                .help("Semaine suivante")
        }
    }

    /// « 4 réunions · 7 échéances · 2 h 10 de focus ».
    private func summary(days: [Date], now: Date) -> String {
        let meetings = days.reduce(0) { $0 + model.store.meetings(on: $1).count }
        let due = days.reduce(0) { $0 + WorkWeek.dueTasks(on: $1, in: model.index.all, today: now).count }
        let focus = days.reduce(0) { $0 + focusMinutes(on: $1) }
        var parts = [plural(meetings, "réunion"), plural(due, "échéance")]
        if focus > 0 { parts.append("\(Format.minutes(focus)) de focus") }
        return parts.joined(separator: " · ")
    }

    // MARK: Jours

    private func dayHeader(_ day: Date, now: Date) -> some View {
        let isToday = Calendar.current.isDate(day, inSameDayAs: now)
        let absence = model.absence(on: day)
        let focus = focusMinutes(on: day)
        return HStack(alignment: .top, spacing: DoneSpace.s4) {
            VStack(alignment: .leading, spacing: DoneSpace.s2) {
                Text("\(Format.weekdayShort(day)) \(Calendar.current.component(.day, from: day))")
                    .font(.sans(15, .semibold).monospacedDigit())
                    .foregroundStyle(isToday ? DoneColor.stateActiveText : DoneColor.textPrimary)
                Group {
                    if let absence {
                        Label(absence.title, systemImage: "sun.max")
                    } else if focus > 0 {
                        Text("\(Format.minutes(focus)) de focus")
                    } else {
                        Text(isToday ? "Aujourd'hui" : " ")
                    }
                }
                .doneText(.caption)
                .foregroundStyle(DoneColor.textSecondary)
                .lineLimit(1)
            }
            Spacer(minLength: 0)
            Menu {
                dayMenu(day, absence: absence, now: now)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .foregroundStyle(DoneColor.textSecondary)
            .help("Ajouter une réunion, marquer une absence")
        }
        .padding(.horizontal, DoneSpace.s8)
        .padding(.bottom, DoneSpace.s8)
        .contentShape(Rectangle())
        .contextMenu { dayMenu(day, absence: absence, now: now) }
    }

    @ViewBuilder
    private func dayMenu(_ day: Date, absence: Absence?, now: Date) -> some View {
        Button("Ajouter une réunion…") {
            let nine = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
            let start = Calendar.current.isDate(day, inSameDayAs: now) ? MeetingSheet.nextQuarter(after: now) : nine
            meetingRequest = MeetingRequest(start: start, end: start.addingTimeInterval(3600))
        }
        Divider()
        Button("Congé") { model.setAbsence(on: day, title: "Congé") }
        Button("Férié") { model.setAbsence(on: day, title: "Férié") }
        Button("Autre absence…") {
            absenceDraft = absence?.title ?? ""
            absenceDay = day
        }
        if absence != nil {
            Divider()
            Button("Retirer l'absence") { model.removeAbsence(on: day) }
        }
    }

    // MARK: Échéances

    private func dueCell(_ day: Date, now: Date, height: CGFloat) -> some View {
        let tasks = WorkWeek.dueTasks(on: day, in: model.index.all, today: now)
        return ScrollView {
            VStack(alignment: .leading, spacing: DoneSpace.s4) {
                ForEach(tasks) { task in
                    dueItem(task, now: now)
                }
            }
            .padding(DoneSpace.s4)
        }
        .scrollIndicators(.never)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(dropDay == day ? DoneColor.stateActiveTint : Color.clear)
        .modifier(DayDrop(day: day, now: now, dropDay: $dropDay) { move($0, to: $1, now: $2) })
    }

    private func dueItem(_ task: TodoTask, now: Date) -> some View {
        let isLate = (task.due ?? now) < Calendar.current.startOfDay(for: now)
        return HStack(spacing: DoneSpace.s4) {
            PriorityChip(priority: task.priority)
            Text(task.title)
                .doneText(.callout)
                .lineLimit(1)
        }
        .foregroundStyle(isLate ? DoneColor.stateRiskText : DoneColor.textPrimary)
        .padding(.horizontal, DoneSpace.s6)
        .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
        .background(DoneColor.surfaceDefault, in: RoundedRectangle(cornerRadius: DoneRadius.sm, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DoneRadius.sm, style: .continuous).strokeBorder(DoneColor.borderSubtle, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { editing = task }
        .draggable(task.id)
        .help(isLate ? "En retard depuis \(Format.chipDate(task.due ?? now).lowercased()) : glisse-la sur un jour" : "\(model.listName(for: task)) · glisse-la sur un autre jour")
    }

    /// Nouvelle échéance pour les tâches déposées. Pas de jour passé.
    private func move(_ ids: [String], to day: Date, now: Date) -> Bool {
        guard Calendar.current.startOfDay(for: day) >= Calendar.current.startOfDay(for: now) else { return false }
        for id in ids {
            guard var task = model.store[id] else { continue }
            task.due = day
            model.update(task)
        }
        return true
    }

    // MARK: Grille

    private func hourLabels(_ hourHeight: CGFloat) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(Self.firstHour..<Self.lastHour, id: \.self) { hour in
                Text("\(hour):00")
                    .font(.done(.numericS))
                    .foregroundStyle(DoneColor.textSecondary)
                    .offset(y: -8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.trailing, DoneSpace.s8)
                    .frame(height: hourHeight)
                    .id(hour)
            }
        }
    }

    private func dayColumn(_ day: Date, now: Date, hourHeight: CGFloat) -> some View {
        let isToday = Calendar.current.isDate(day, inSameDayAs: now)
        let isPast = Calendar.current.startOfDay(for: day) < Calendar.current.startOfDay(for: now)
        let dayBlocks = blocks(on: day, now: now)
        let lanes = WorkWeek.lanes(dayBlocks.map { WorkWeek.Slot(id: $0.id, start: $0.start, end: $0.end) })
        return GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(model.absence(on: day) != nil ? DoneColor.bgSunken : Color.clear)
                ForEach(1..<(Self.lastHour - Self.firstHour), id: \.self) { index in
                    Rectangle()
                        .fill(DoneColor.borderSubtle)
                        .frame(height: 1)
                        .offset(y: CGFloat(index) * hourHeight)
                }
                ForEach(dayBlocks) { block in
                    let lane = lanes[block.id] ?? WorkWeek.Lane(index: 0, count: 1)
                    let laneWidth = (width - 6) / CGFloat(lane.count)
                    let top = y(of: block.start, on: day, hourHeight: hourHeight)
                    let height = max(y(of: block.end, on: day, hourHeight: hourHeight) - top - 2, 14)
                    blockView(block, now: now)
                        .frame(width: max(laneWidth - 2, 0), height: height)
                        .offset(x: 3 + laneWidth * CGFloat(lane.index), y: top + 1)
                }
                if isToday {
                    nowLine
                        .offset(y: y(of: now, on: day, hourHeight: hourHeight) - 3)
                }
            }
            .contentShape(Rectangle())
            // Un clic sur un créneau libre, aujourd'hui ou plus tard, ajoute une réunion d'une heure.
            .onTapGesture(coordinateSpace: .local) { location in
                guard !isPast else { return }
                let start = time(at: location.y, on: day, hourHeight: hourHeight)
                meetingRequest = MeetingRequest(start: start, end: start.addingTimeInterval(3600))
            }
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .leading) {
            Rectangle().fill(DoneColor.borderSubtle).frame(width: 1)
        }
        .background(dropDay == day ? DoneColor.stateActiveTint : Color.clear)
        .modifier(DayDrop(day: day, now: now, dropDay: $dropDay) { move($0, to: $1, now: $2) })
        .clipped()
    }

    @ViewBuilder
    private func blockView(_ block: Block, now: Date) -> some View {
        let shape = RoundedRectangle(cornerRadius: DoneRadius.xs, style: .continuous)
        switch block.kind {
        case .meeting(let meeting):
            MeetingBlock(meeting: meeting, now: now, detail: "\(Format.time(meeting.start))–\(Format.time(meeting.end))", fillsHeight: true)
                .clipShape(shape)
                .contentShape(shape)
                .onTapGesture { meetingRequest = MeetingRequest(meeting: meeting) }
                .help("\(meeting.title), \(Format.time(meeting.start))–\(Format.time(meeting.end))")
        case .focus(let title, let minutes):
            shape
                .fill(DoneColor.stateActiveTint)
                .overlay(alignment: .leading) {
                    Rectangle().fill(DoneColor.stateActive).frame(width: 3)
                }
                .overlay(alignment: .topLeading) {
                    Text(title)
                        .font(.sans(11, .medium))
                        .foregroundStyle(DoneColor.stateActiveText)
                        .lineLimit(1)
                        .padding(.leading, 7)
                        .padding(.top, DoneSpace.s2)
                }
                .clipShape(shape)
                .accessibilityLabel("\(title) : \(Format.minutes(minutes)) de focus")
                // Un clic sur du focus passé tombe sur la colonne, comme un créneau libre.
                .allowsHitTesting(false)
        }
    }

    private var nowLine: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(DoneColor.stateActive)
                .frame(width: 6, height: 6)
            Rectangle()
                .fill(DoneColor.stateActive)
                .frame(height: 1.5)
        }
        .allowsHitTesting(false)
    }

    // MARK: Données

    private func blocks(on day: Date, now: Date) -> [Block] {
        let meetings = model.store.meetings(on: day).map {
            Block(id: "meeting-" + $0.id, start: $0.start, end: $0.end, kind: .meeting($0))
        }
        let focus = focusSessions(on: day).compactMap { session -> Block? in
            let end = session.endedAt ?? (session.outcome == .inProgress ? now : session.startedAt.addingTimeInterval(session.focusedSeconds))
            guard end.timeIntervalSince(session.startedAt) >= 60 else { return nil }
            return Block(
                id: "focus-\(session.startedAt.timeIntervalSince1970)",
                start: session.startedAt,
                end: end,
                kind: .focus(title: session.rootTitle, minutes: session.focusedSeconds / 60)
            )
        }
        return focus + meetings
    }

    private func focusSessions(on day: Date) -> [FocusSession] {
        sessions.filter { Calendar.current.isDate($0.startedAt, inSameDayAs: day) }
    }

    private func focusMinutes(on day: Date) -> Double {
        focusSessions(on: day).reduce(0) { $0 + $1.focusedSeconds } / 60
    }

    /// Un jour de la semaine affichée.
    private func reference(_ now: Date) -> Date {
        // Le week-end, la semaine qui vient est plus utile que celle qui finit.
        let weekday = Calendar(identifier: .gregorian).component(.weekday, from: now)
        let base = weekday == 1 || weekday == 7 ? Stats.calendar.date(byAdding: .day, value: 2, to: now) ?? now : now
        return Stats.calendar.date(byAdding: .weekOfYear, value: weekOffset, to: base) ?? base
    }

    /// Position verticale d'une heure dans la grille, bornée à la plage affichée.
    private func y(of date: Date, on day: Date, hourHeight: CGFloat) -> CGFloat {
        let calendar = Calendar.current
        let start = calendar.date(bySettingHour: Self.firstHour, minute: 0, second: 0, of: day) ?? day
        let minutes = date.timeIntervalSince(start) / 60
        let total = Double(Self.lastHour - Self.firstHour) * 60
        return CGFloat(min(max(minutes, 0), total) / 60) * hourHeight
    }

    /// L'heure sous un point de la grille, à la demi-heure inférieure.
    private func time(at y: CGFloat, on day: Date, hourHeight: CGFloat) -> Date {
        let minutes = Int((Double(y / hourHeight) * 60).rounded(.down))
        let rounded = min(max(minutes / 30 * 30, 0), (Self.lastHour - Self.firstHour) * 60 - 30)
        let start = Calendar.current.date(bySettingHour: Self.firstHour, minute: 0, second: 0, of: day) ?? day
        return start.addingTimeInterval(Double(rounded) * 60)
    }

    // MARK: Mise en page

    /// Une rangée alignée sur les colonnes des jours, avec la gouttière des heures à gauche.
    private func row<Days: View, Gutter: View>(@ViewBuilder days: () -> Days, @ViewBuilder gutter: () -> Gutter) -> some View {
        HStack(alignment: .top, spacing: 0) {
            gutter()
                .frame(width: Self.gutter, alignment: .topLeading)
            days()
        }
    }

    /// Sans gouttière : une marge vide, de hauteur nulle (un `Color.clear` seul prendrait toute la hauteur libre).
    private func row<Days: View>(@ViewBuilder days: () -> Days) -> some View {
        row(days: days) { Color.clear.frame(height: 0) }
    }
}

/// Dépose de tâches sur un jour : la tâche y prend son échéance.
private struct DayDrop: ViewModifier {
    let day: Date
    let now: Date
    @Binding var dropDay: Date?
    let move: ([String], Date, Date) -> Bool

    func body(content: Content) -> some View {
        content.dropDestination(for: String.self) { ids, _ in
            move(ids, day, now)
        } isTargeted: { targeted in
            if targeted {
                dropDay = day
            } else if dropDay == day {
                dropDay = nil
            }
        }
    }
}
