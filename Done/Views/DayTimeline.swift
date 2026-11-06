import SwiftData
import SwiftUI

/// Une réunion à créer sur un créneau, ou à modifier.
struct MeetingRequest: Identifiable {
    let id = UUID()
    var meeting: Meeting?
    var start: Date?
    var end: Date?
}

/// Colonne d'un jour, de 8 h à 19 h : réunions hachurées (un clic les ouvre), focus déjà fait,
/// heure courante. Un clic sur un créneau libre, aujourd'hui ou plus tard, propose une réunion.
/// Partagée par le calendrier et l'écran Aujourd'hui.
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
                ForEach(1..<(Self.lastHour - Self.firstHour), id: \.self) { index in
                    Rectangle()
                        .fill(DoneColor.borderSubtle)
                        .frame(height: 1)
                        .offset(y: CGFloat(index) * hourHeight)
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
                        .offset(y: y(of: now) - 3)
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
        let shape = RoundedRectangle(cornerRadius: DoneRadius.xs, style: .continuous)
        switch block.kind {
        case .meeting(let meeting):
            MeetingBlock(meeting: meeting, now: now, detail: "\(Format.time(meeting.start))–\(Format.time(meeting.end))", fillsHeight: true)
                .clipShape(shape)
                .contentShape(shape)
                .onTapGesture { onMeeting(meeting) }
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
        let start = Calendar.current.date(bySettingHour: Self.firstHour, minute: 0, second: 0, of: day) ?? day
        let minutes = date.timeIntervalSince(start) / 60
        let total = Double(Self.lastHour - Self.firstHour) * 60
        return CGFloat(min(max(minutes, 0), total) / 60) * hourHeight
    }

    /// L'heure sous un point de la grille, à la demi-heure inférieure.
    private func time(at y: CGFloat) -> Date {
        let minutes = Int((Double(y / hourHeight) * 60).rounded(.down))
        let rounded = min(max(minutes / 30 * 30, 0), (Self.lastHour - Self.firstHour) * 60 - 30)
        let start = Calendar.current.date(bySettingHour: Self.firstHour, minute: 0, second: 0, of: day) ?? day
        return start.addingTimeInterval(Double(rounded) * 60)
    }
}

/// Heures de la grille, alignées à droite, chacune servant d'ancre de défilement (`id` = l'heure).
struct HourLabels: View {
    let hourHeight: CGFloat

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(DayTimeline.firstHour..<DayTimeline.lastHour, id: \.self) { hour in
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
}
