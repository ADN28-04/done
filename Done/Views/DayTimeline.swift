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

/// Colonne d'un jour, de 8 h à 19 h par défaut : réunions hachurées (un clic les ouvre), focus déjà fait
/// en braise claire, heure courante en braise. Aujourd'hui, les créneaux libres de 30 min ou plus
/// peuvent s'afficher en pointillé, avec les pomodoros qui y tiennent. Un clic ailleurs, aujourd'hui
/// ou plus tard, propose une réunion. Blocs au rayon sm ; un bloc de moins de 30 min tient sur une
/// ligne. Partagée par le calendrier et l'écran Aujourd'hui.
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
    let onMeeting: (Meeting) -> Void
    let onSlot: (Date) -> Void

    /// Hauteur d'une heure pour remplir `available`, sans descendre sous le minimum.
    static func hourHeight(fitting available: CGFloat) -> CGFloat {
        max(minHourHeight, (available / CGFloat(lastHour - firstHour)).rounded(.down))
    }

    static func focusMinutes(on day: Date, in sessions: [FocusSession]) -> Double {
        sessions
            .filter { Calendar.current.isDate($0.startedAt, inSameDayAs: day) }
            .reduce(0) { $0 + $1.focusedSeconds } / 60
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
        let isToday = Calendar.current.isDate(day, inSameDayAs: now)
        let isPast = Calendar.current.startOfDay(for: day) < Calendar.current.startOfDay(for: now)
        let dayBlocks = blocks()
        let lanes = WorkWeek.lanes(dayBlocks.map { WorkWeek.Slot(id: $0.id, start: $0.start, end: $0.end) })
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(model.absence(on: day) != nil ? DoneColor.bgSunken : Color.clear)
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
                    let top = y(of: block.start)
                    let height = max(y(of: block.end) - top - 2, 14)
                    blockView(block)
                        .frame(width: max(laneWidth - 2, 0), height: height)
                        .offset(x: 3 + laneWidth * CGFloat(lane.index), y: top + 1)
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
        }
    }

    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        let shape = RoundedRectangle(cornerRadius: DoneRadius.sm, style: .continuous)
        let isShort = block.end.timeIntervalSince(block.start) < 30 * 60
        switch block.kind {
        case .meeting(let meeting):
            MeetingBlock(meeting: meeting, now: now, detail: "\(Format.time(meeting.start))–\(Format.time(meeting.end))", fillsHeight: true, singleLine: isShort)
                .clipShape(shape)
                .contentShape(shape)
                .onTapGesture { onMeeting(meeting) }
                .help("\(meeting.title), \(Format.time(meeting.start))–\(Format.time(meeting.end))")
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
        return focus + meetings
    }

    /// Position verticale d'une heure dans la grille, bornée à la plage affichée.
    private func y(of date: Date) -> CGFloat {
        let start = Calendar.current.date(bySettingHour: firstHour, minute: 0, second: 0, of: day) ?? day
        let minutes = date.timeIntervalSince(start) / 60
        let total = Double(lastHour - firstHour) * 60
        return CGFloat(min(max(minutes, 0), total) / 60) * hourHeight
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
