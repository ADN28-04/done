import AppKit
import SwiftData
import SwiftUI

/// Une réunion à créer sur un créneau, ou à modifier.
struct MeetingRequest: Identifiable {
    let id = UUID()
    var meeting: Meeting?
    var start: Date?
    var end: Date?
    /// Titre déjà saisi, pour une nouvelle réunion (barre de saisie).
    var title = ""
}

/// Colonne d'un jour, de 8 h à 19 h par défaut : réunions hachurées, blocs de travail en cobalt clair,
/// focus déjà fait en braise claire, heure courante en braise. Un clic ouvre une réunion ou un bloc ;
/// on les glisse pour changer l'heure (ou le jour, au calendrier) et on étire leur bord bas pour la
/// durée, au quart d'heure, jamais vers le passé. Une tâche déposée sur la grille y prend un bloc de
/// travail d'un pomodoro. Aujourd'hui, les créneaux libres de 30 min ou plus peuvent s'afficher en
/// pointillé, avec les pomodoros qui y tiennent. Un clic ailleurs, aujourd'hui ou plus tard, propose
/// une réunion ou un bloc. Blocs au rayon sm ; un bloc de moins de 30 min tient sur une ligne.
/// Partagée par le calendrier et Ma journée.
struct DayTimeline: View {
    static let firstHour = 8
    static let lastHour = 19
    /// La grille s'étire sur la hauteur libre ; en dessous de 44 par heure, elle défile.
    static let minHourHeight: CGFloat = 44

    @Environment(AppModel.self) private var model
    let day: Date
    let now: Date
    let hourHeight: CGFloat
    /// Toutes les sessions enregistrées ; la colonne garde celles du jour.
    let sessions: [FocusSession]
    /// Première et dernière heure de la colonne.
    var firstHour = DayTimeline.firstHour
    var lastHour = DayTimeline.lastHour
    /// Montre les créneaux libres d'aujourd'hui, à partir de maintenant.
    var showsFreeSlots = false
    /// Clic sur un créneau libre (Ma journée : lancer la prochaine action). Sans, le clic passe à la colonne.
    var onFreeSlot: ((DateInterval) -> Void)?
    /// Jours vers lesquels on peut glisser une réunion ou un bloc, en écart avec ce jour (calendrier :
    /// les autres jours de la semaine). Ma journée reste sur le jour.
    var moveDays: ClosedRange<Int> = 0...0
    /// Un élément de la colonne est en train d'être glissé : le calendrier passe la colonne devant ses voisines.
    var onDragging: (Bool) -> Void = { _ in }
    /// Clic sur un bloc de travail.
    var onWorkBlock: (WorkBlock) -> Void = { _ in }
    /// Calendrier : hauteur (dans la fenêtre) du haut de la grille visible. Un bloc de travail glissé
    /// au-dessus quitte la grille et rend sa tâche aux échéances du jour visé (`onReturnToDue`).
    var liftThreshold: CGFloat?
    /// Le jour dont les échéances recevraient le bloc soulevé, ou nil quand il revient sur la grille.
    var onLiftTarget: (Date?) -> Void = { _ in }
    /// Bloc lâché au-dessus de la grille : sa tâche revient aux échéances de ce jour.
    var onReturnToDue: (WorkBlock, Date) -> Void = { _, _ in }
    let onMeeting: (Meeting) -> Void
    let onSlot: (Date) -> Void

    /// Réunion ou bloc en train d'être glissé ou étiré : la dernière position connue du geste.
    @State private var drag: TimelineDrag?
    /// Vrai tant qu'un geste dure. Revient seul à faux à la fin du geste, même quand macOS l'annule
    /// sans prévenir : la dernière position est alors enregistrée, et rien ne reste sélectionné.
    @GestureState private var gestureActive = false
    /// Une tâche glissée survole la grille.
    @State private var dropTargeted = false

    private struct TimelineDrag {
        enum Mode { case move, resize }
        let id: String
        let mode: Mode
        var minutes: Double = 0
        var days = 0
        /// Bloc de travail soulevé au-dessus de la grille, vers les échéances.
        var lifted = false
    }

    /// Hauteur d'une heure pour remplir `available`, sans descendre sous le minimum.
    static func hourHeight(fitting available: CGFloat) -> CGFloat {
        max(minHourHeight, (available / CGFloat(lastHour - firstHour)).rounded(.down))
    }

    static func focusMinutes(on day: Date, in sessions: [FocusSession]) -> Double {
        sessions
            .filter { Calendar.current.isDate($0.startedAt, inSameDayAs: day) }
            .reduce(0) { $0 + $1.focusedSeconds } / 60
    }

    /// Un élément de la grille : réunion, bloc de travail, ou session de focus passée.
    private struct Block: Identifiable {
        enum Kind {
            case meeting(Meeting)
            case work(WorkBlock, task: TodoTask)
            case focus(title: String, minutes: Double)
        }

        let id: String
        let start: Date
        let end: Date
        let kind: Kind

        /// Réunions et blocs se glissent et s'étirent ; le focus passé, non.
        var isEditable: Bool {
            if case .focus = kind { return false }
            return true
        }
    }

    var body: some View {
        let isToday = Calendar.current.isDate(day, inSameDayAs: now)
        let isPast = Calendar.current.startOfDay(for: day) < Calendar.current.startOfDay(for: now)
        let dayBlocks = blocks()
        let lanes = WorkWeek.lanes(dayBlocks.map { WorkWeek.Slot(id: $0.id, start: $0.start, end: $0.end) })
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(dropTargeted ? DoneColor.stateActiveTint : (model.absence(on: day) != nil ? DoneColor.bgSunken : Color.clear))
                ForEach(1..<max(lastHour - firstHour, 2), id: \.self) { index in
                    Rectangle()
                        .fill(DoneColor.borderSubtle)
                        .frame(height: 1)
                        .offset(y: CGFloat(index) * hourHeight)
                }
                if showsFreeSlots && isToday {
                    ForEach(freeSlots(busy: dayBlocks), id: \.start) { slot in
                        freeSlotView(slot)
                            .frame(width: max(width - 8, 0), height: max(y(of: slot.end) - y(of: slot.start) - 4, 0))
                            .offset(x: 4, y: y(of: slot.start) + 2)
                    }
                }
                ForEach(dayBlocks) { block in
                    let lane = lanes[block.id] ?? WorkWeek.Lane(index: 0, count: 1)
                    let laneWidth = (width - 6) / CGFloat(lane.count)
                    // Pendant un geste, l'élément se dessine à sa nouvelle place (et dans la colonne visée).
                    let edit = editing(block)
                    let top = y(of: edit?.range.start ?? block.start)
                    let height = max(y(of: edit?.range.end ?? block.end) - top - 2, 14)
                    blockView(block, width: width)
                        .frame(width: max(laneWidth - 2, 0), height: height)
                        .offset(x: 3 + laneWidth * CGFloat(lane.index) + CGFloat(edit?.days ?? 0) * width, y: top + 1)
                        .zIndex(edit == nil ? 0 : 2)
                }
                if isToday {
                    nowLine
                        .offset(y: y(of: now) - 4)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { location in
                guard !isPast else { return }
                onSlot(time(at: location.y))
            }
            // Une tâche déposée sur la grille y prend un bloc de travail, au quart d'heure.
            .dropDestination(for: String.self) { ids, location in
                let start = quarter(at: location.y)
                guard start >= TimelineEdit.currentQuarter(now) else { return false }
                var added = false
                for id in ids where model.addWorkBlock(taskID: id, start: start) != nil {
                    added = true
                }
                return added
            } isTargeted: { dropTargeted = $0 }
        }
        // Un geste annulé par macOS n'appelle pas sa fin : on la déclenche quand il retombe.
        .onChange(of: gestureActive) { _, active in
            if !active { finishGesture() }
        }
    }

    @ViewBuilder
    private func blockView(_ block: Block, width: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: DoneRadius.sm, style: .continuous)
        let isShort = block.end.timeIntervalSince(block.start) < 30 * 60
        let edit = editing(block)
        // Le créneau visé pendant le geste, ou celui de l'élément.
        let shown = edit.map(\.range) ?? DateInterval(start: block.start, end: max(block.start, block.end))
        switch block.kind {
        case .meeting(let meeting):
            MeetingBlock(
                meeting: meeting,
                now: now,
                detail: "\(Format.time(shown.start))–\(Format.time(shown.end))",
                fillsHeight: true,
                singleLine: shown.duration < 30 * 60
            )
            .clipShape(shape)
            .modifier(EditableBlock(
                shape: shape,
                edit: edit.map { ($0.isAllowed) },
                gesture: moveGesture(block, width: width),
                handle: resizeHandle(block),
                open: { onMeeting(meeting) }
            ))
            .help("\(meeting.title), \(Format.time(meeting.start))–\(Format.time(meeting.end)). Glisser pour déplacer, étirer le bas pour la durée.")
        case .work(let workBlock, let task):
            WorkBlockView(task: task, detail: "\(Format.time(shown.start))–\(Format.time(shown.end))", singleLine: shown.duration < 30 * 60)
                .clipShape(shape)
                .modifier(EditableBlock(
                    shape: shape,
                    edit: edit.map { ($0.isAllowed) },
                    gesture: moveGesture(block, width: width),
                    handle: resizeHandle(block),
                    open: { onWorkBlock(workBlock) }
                ))
                .help("Bloc de travail : \(task.title), \(Format.time(workBlock.start))–\(Format.time(workBlock.end)). Glisser pour déplacer, étirer le bas pour la durée.")
        case .focus(let title, let minutes):
            shape
                .fill(DoneColor.accentTint)
                .overlay(alignment: .topLeading) {
                    Text(title)
                        .font(.sans(11, .semibold))
                        .foregroundStyle(DoneColor.accentText)
                        .lineLimit(1)
                        .padding(.horizontal, DoneSpace.s8)
                        .padding(.top, isShort ? 1 : DoneSpace.s4)
                }
                .clipShape(shape)
                .accessibilityLabel("\(title) : \(Format.minutes(minutes)) de focus")
                // Un clic sur du focus passé tombe sur la colonne, comme un créneau libre.
                .allowsHitTesting(false)
        }
    }

    // MARK: Glisser et étirer

    /// Le geste en cours sur cet élément : la plage visée (celle d'origine si le geste vise le passé),
    /// et le décalage en jours. Un bloc soulevé vers les échéances reste à son heure, pâle, dans la
    /// colonne du jour visé.
    private func editing(_ block: Block) -> (range: DateInterval, days: Int, isAllowed: Bool)? {
        guard block.isEditable, let drag, drag.id == block.id else { return nil }
        let original = DateInterval(start: block.start, end: max(block.start, block.end))
        if drag.lifted { return (original, drag.days, false) }
        if let range = target(of: block, drag) {
            return (range, drag.mode == .move ? drag.days : 0, true)
        }
        return (original, 0, false)
    }

    /// La plage d'un élément à la fin du geste ; nil si le geste vise un moment interdit.
    private func target(of block: Block, _ drag: TimelineDrag) -> DateInterval? {
        let original = DateInterval(start: block.start, end: max(block.start, block.end))
        switch drag.mode {
        case .move:
            return TimelineEdit.moved(original, byMinutes: drag.minutes, days: drag.days, firstHour: firstHour, lastHour: lastHour, now: now)
        case .resize:
            return TimelineEdit.resized(original, byMinutes: drag.minutes, lastHour: lastHour, now: now)
        }
    }

    /// Glisser un élément : vers le haut ou le bas pour l'heure, sur le côté pour un autre jour.
    /// Mesuré dans l'espace de la fenêtre : l'élément bouge sous le doigt sans fausser le geste.
    /// Au calendrier, un bloc de travail poussé au-dessus de la grille rejoint les échéances du jour.
    private func moveGesture(_ block: Block, width: CGFloat) -> AnyGesture<DragGesture.Value> {
        AnyGesture(
            DragGesture(minimumDistance: 4, coordinateSpace: .global)
                .onChanged { value in
                    let columns = Int((value.translation.width / max(width, 1)).rounded())
                    let days = min(max(columns, moveDays.lowerBound), moveDays.upperBound)
                    if drag == nil { onDragging(true) }
                    var lifted = false
                    if case .work = block.kind, let liftThreshold, value.location.y < liftThreshold {
                        lifted = true
                    }
                    drag = TimelineDrag(id: block.id, mode: .move, minutes: Double(value.translation.height / hourHeight) * 60, days: days, lifted: lifted)
                    onLiftTarget(lifted ? targetDay(of: block, days: days) : nil)
                }
                .updating($gestureActive) { _, active, _ in active = true }
                .onEnded { _ in finishGesture() }
        )
    }

    /// Le jour visé par un geste de `days` colonnes.
    private func targetDay(of block: Block, days: Int) -> Date {
        let start = Calendar.current.startOfDay(for: block.start)
        return Calendar.current.date(byAdding: .day, value: days, to: start) ?? start
    }

    /// Bord bas d'un élément : on l'étire pour changer sa durée. Le curseur de redimensionnement est
    /// posé tant que la souris est sur le bord, et la flèche revient dès qu'elle le quitte ou qu'on
    /// relâche (`set` plutôt qu'une pile : il ne peut pas rester coincé).
    private func resizeHandle(_ block: Block) -> AnyView {
        AnyView(
            Color.clear
                .frame(height: 8)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active:
                        NSCursor.resizeUpDown.set()
                    case .ended:
                        if drag?.mode != .resize { NSCursor.arrow.set() }
                    }
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 1, coordinateSpace: .global)
                        .onChanged { value in
                            if drag == nil { onDragging(true) }
                            NSCursor.resizeUpDown.set()
                            drag = TimelineDrag(id: block.id, mode: .resize, minutes: Double(value.translation.height / hourHeight) * 60)
                        }
                        .updating($gestureActive) { _, active, _ in active = true }
                        .onEnded { _ in finishGesture() }
                )
                .accessibilityHidden(true)
        )
    }

    /// Fin du geste, qu'il soit relâché ou annulé : la réunion ou le bloc prend sa nouvelle plage, si
    /// elle est permise et a changé ; le curseur et la sélection reviennent à l'état de repos. Appelée
    /// au relâchement et quand `gestureActive` retombe ; la seconde fois, il n'y a plus rien à faire.
    private func finishGesture() {
        guard let drag else { return }
        self.drag = nil
        onDragging(false)
        onLiftTarget(nil)
        if drag.mode == .resize { NSCursor.arrow.set() }
        guard let block = blocks().first(where: { $0.id == drag.id }) else { return }
        // Bloc lâché au-dessus de la grille : sa tâche revient aux échéances du jour visé.
        if drag.lifted, case .work(let workBlock, _) = block.kind {
            onReturnToDue(workBlock, targetDay(of: block, days: drag.days))
            return
        }
        guard let range = target(of: block, drag),
              range.start != block.start || range.end != block.end else { return }
        switch block.kind {
        case .meeting(var meeting):
            meeting.start = range.start
            meeting.end = range.end
            model.updateMeeting(meeting)
        case .work(var workBlock, _):
            workBlock.start = range.start
            workBlock.end = range.end
            model.updateWorkBlock(workBlock)
        case .focus:
            break
        }
    }

    /// Heure courante : un point et un trait de 2 en braise.
    private var nowLine: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(DoneColor.accent)
                .frame(width: 8, height: 8)
            Rectangle()
                .fill(DoneColor.accent)
                .frame(height: 2)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Créneau libre : pointillé stateWaiting, avec ce qu'il permet. Cliquable avec `onFreeSlot`,
    /// sinon le clic passe à la colonne.
    @ViewBuilder
    private func freeSlotView(_ slot: DateInterval) -> some View {
        if let onFreeSlot {
            freeSlotShape(slot)
                .contentShape(RoundedRectangle(cornerRadius: DoneRadius.sm, style: .continuous))
                .onTapGesture { onFreeSlot(slot) }
                .help("Lancer la prochaine action")
                .accessibilityAddTraits(.isButton)
        } else {
            freeSlotShape(slot)
                .allowsHitTesting(false)
        }
    }

    private func freeSlotShape(_ slot: DateInterval) -> some View {
        let shape = RoundedRectangle(cornerRadius: DoneRadius.sm, style: .continuous)
        let rules = Rules.current
        let count = DayAgenda.pomodoros(fitting: Int(slot.duration / 60), focus: rules.defaultMinutes, pause: rules.shortBreakMinutes)
        let text = count == 0 ? "Libre" : (count == 1 ? "1 pomodoro possible" : "\(count) pomodoros possibles")
        return shape
            .strokeBorder(DoneColor.stateWaiting, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            .overlay(alignment: .topLeading) {
                Text(text)
                    .font(.sans(11, .semibold))
                    .foregroundStyle(DoneColor.textSecondary)
                    .lineLimit(1)
                    .padding(.horizontal, DoneSpace.s8)
                    .padding(.top, DoneSpace.s4)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Libre de \(Format.time(slot.start)) à \(Format.time(slot.end)) : \(text.lowercased())")
    }

    /// Créneaux libres de 30 min ou plus, de maintenant à la fin de la colonne.
    private func freeSlots(busy blocks: [Block]) -> [DateInterval] {
        let end = Calendar.current.date(bySettingHour: lastHour, minute: 0, second: 0, of: day) ?? day
        let start = max(now, Calendar.current.date(bySettingHour: firstHour, minute: 0, second: 0, of: day) ?? day)
        return DayAgenda.freeSlots(busy: blocks.map { DateInterval(start: $0.start, end: max($0.start, $0.end)) }, from: start, to: end)
    }

    private func blocks() -> [Block] {
        let meetings = model.store.meetings(on: day).map {
            Block(id: "meeting-" + $0.id, start: $0.start, end: $0.end, kind: .meeting($0))
        }
        let work = model.store.workBlocks(on: day).compactMap { block -> Block? in
            guard let task = model.store[block.taskID] else { return nil }
            return Block(id: "work-" + block.id, start: block.start, end: block.end, kind: .work(block, task: task))
        }
        let focus = sessions
            .filter { Calendar.current.isDate($0.startedAt, inSameDayAs: day) }
            .compactMap { session -> Block? in
                let end = session.endedAt ?? (session.outcome == .inProgress ? now : session.startedAt.addingTimeInterval(session.focusedSeconds))
                guard end.timeIntervalSince(session.startedAt) >= 60 else { return nil }
                return Block(
                    id: "focus-\(session.startedAt.timeIntervalSince1970)",
                    start: session.startedAt,
                    end: end,
                    kind: .focus(title: session.rootTitle, minutes: session.focusedSeconds / 60)
                )
            }
        return focus + work + meetings
    }

    /// Position verticale d'une heure dans la grille, bornée à la plage affichée.
    private func y(of date: Date) -> CGFloat {
        // Compté depuis le jour de `date` : une réunion glissée vers un autre jour garde son heure.
        let start = Calendar.current.date(bySettingHour: firstHour, minute: 0, second: 0, of: date) ?? day
        let minutes = date.timeIntervalSince(start) / 60
        let total = Double(lastHour - firstHour) * 60
        return CGFloat(min(max(minutes, 0), total) / 60) * hourHeight
    }

    /// L'heure sous un point de la grille, au quart d'heure le plus proche : où commence un bloc déposé.
    private func quarter(at y: CGFloat) -> Date {
        let start = Calendar.current.date(bySettingHour: firstHour, minute: 0, second: 0, of: day) ?? day
        let minutes = max(0, min(Double(y / hourHeight) * 60, Double(lastHour - firstHour) * 60 - Double(TimelineEdit.step)))
        return TimelineEdit.snapped(start.addingTimeInterval(minutes * 60), dayStart: Calendar.current.startOfDay(for: day))
    }

    /// L'heure sous un point de la grille, à la demi-heure inférieure.
    private func time(at y: CGFloat) -> Date {
        let minutes = Int((Double(y / hourHeight) * 60).rounded(.down))
        let rounded = min(max(minutes / 30 * 30, 0), (lastHour - firstHour) * 60 - 30)
        let start = Calendar.current.date(bySettingHour: firstHour, minute: 0, second: 0, of: day) ?? day
        return start.addingTimeInterval(Double(rounded) * 60)
    }
}

/// Heures de la grille, alignées à droite, chacune servant d'ancre de défilement (`id` = l'heure).
/// Avec `now`, l'heure courante s'inscrit en accentText à sa hauteur, et l'heure pleine trop proche
/// s'efface.
struct HourLabels: View {
    let hourHeight: CGFloat
    var firstHour = DayTimeline.firstHour
    var lastHour = DayTimeline.lastHour
    /// L'heure courante, si elle est dans la colonne affichée aujourd'hui.
    var now: Date?

    var body: some View {
        let nowY = now.flatMap(y(of:))
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(firstHour..<max(lastHour, firstHour + 1), id: \.self) { hour in
                let hourY = CGFloat(hour - firstHour) * hourHeight
                Text("\(hour):00")
                    .font(.done(.numericS))
                    .foregroundStyle(DoneColor.textSecondary)
                    .opacity(nowY.map { abs($0 - hourY) < 14 } == true ? 0 : 1)
                    .offset(y: -8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.trailing, DoneSpace.s8)
                    .frame(height: hourHeight)
                    .id(hour)
            }
        }
        .overlay(alignment: .topTrailing) {
            if let now, let nowY {
                Text(Format.time(now))
                    .font(.done(.numericS))
                    .foregroundStyle(DoneColor.accentText)
                    .padding(.trailing, DoneSpace.s8)
                    .offset(y: nowY - 8)
            }
        }
    }

    /// Hauteur de `date` dans la colonne, ou nil hors de la plage.
    private func y(of date: Date) -> CGFloat? {
        let calendar = Calendar.current
        guard let start = calendar.date(bySettingHour: firstHour, minute: 0, second: 0, of: date) else { return nil }
        let minutes = date.timeIntervalSince(start) / 60
        guard minutes >= 0, minutes <= Double(lastHour - firstHour) * 60 else { return nil }
        return CGFloat(minutes / 60) * hourHeight
    }
}

/// Ce qui rend un élément de la grille modifiable : contour cobalt et ombre pendant le geste, pâle si
/// le geste vise le passé, clic pour l'ouvrir, glisser pour le déplacer, bord bas pour l'étirer.
private struct EditableBlock<Handle: View>: ViewModifier {
    let shape: RoundedRectangle
    /// Pendant un geste : vrai si la plage visée est permise.
    let edit: Bool?
    let gesture: AnyGesture<DragGesture.Value>
    let handle: Handle
    let open: () -> Void

    func body(content: Content) -> some View {
        content
            .overlay {
                if let edit {
                    shape.strokeBorder(DoneColor.focusRing, lineWidth: edit ? 2 : 0)
                }
            }
            // Un geste vers un moment interdit (le passé) : l'élément pâlit et ne bougera pas.
            .opacity(edit.map { $0 ? 1 : 0.5 } ?? 1)
            .shadow(color: edit == nil ? .clear : DoneColor.shadowRaised, radius: 12, y: 6)
            .contentShape(shape)
            .onTapGesture(perform: open)
            .gesture(gesture)
            .overlay(alignment: .bottom) { handle }
    }
}

/// Bloc de travail dans la grille : cobalt clair, le titre de la tâche et le créneau. Une tâche déjà
/// faite passe en gris, barrée.
struct WorkBlockView: View {
    let task: TodoTask
    let detail: String
    var singleLine = false

    var body: some View {
        let done = !task.isOpen
        let title = Text(Image(systemName: "checkmark.square")) + Text(" ") + Text(task.title)
        Group {
            if singleLine {
                HStack(spacing: DoneSpace.s6) {
                    title
                        .font(.sans(12, .semibold))
                        .strikethrough(done)
                        .lineLimit(1)
                    Text(detail)
                        .font(.done(.numericS))
                        .lineLimit(1)
                        .opacity(0.85)
                }
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    title
                        .font(.sans(13, .semibold))
                        .strikethrough(done)
                        .lineLimit(2)
                    Text(detail)
                        .font(.done(.numericS))
                        .opacity(0.85)
                }
            }
        }
        .foregroundStyle(done ? DoneColor.textDisabled : DoneColor.stateActiveText)
        .padding(.horizontal, DoneSpace.s8)
        .padding(.vertical, singleLine ? 1 : DoneSpace.s6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(done ? DoneColor.stateDone : DoneColor.stateActiveTint)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(done ? DoneColor.borderDefault : DoneColor.stateActive)
                .frame(width: 3)
        }
    }
}
