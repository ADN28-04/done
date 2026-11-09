import Foundation

/// Réunion récurrente : le modèle d'une série (titre, horaire, répétition). Done en crée les
/// occurrences, de vraies réunions (`Meeting.seriesID`), pour la semaine en cours et la suivante :
/// le reste de l'app (rappels, prochaine action, connecteur) ne voit que des réunions ordinaires.
/// Une occurrence déplacée, renommée ou supprimée ne change qu'elle, et ne revient pas.
struct MeetingSeries: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    /// Jour de la première occurrence (clé de jour, « 2026-11-09 »).
    var firstDay: String
    /// Début, en minutes depuis minuit.
    var startMinute: Int
    var durationMinutes: Int
    /// Répétition sous forme brute (`Recurrence.raw`), ancrée sur le premier jour : « weekly:2 ».
    var recurrenceRaw: String
    /// Dernier jour (clé) jusqu'où les occurrences ont été créées : une occurrence supprimée n'est
    /// pas recréée.
    var filledThrough: String?

    var recurrence: Recurrence? { Recurrence(raw: recurrenceRaw) }
}

extension TaskStore {
    /// Jusqu'où Done crée les occurrences : la fin de la semaine prochaine (exclue).
    static func meetingHorizon(now: Date, calendar: Calendar = Stats.calendar) -> Date {
        let week = Stats.week(containing: now)
        return calendar.date(byAdding: .day, value: 7, to: week.end) ?? week.end.addingTimeInterval(7 * 86_400)
    }

    /// La série d'une occurrence.
    func series(of meeting: Meeting) -> MeetingSeries? {
        guard let id = meeting.seriesID else { return nil }
        return meetingSeries.first { $0.id == id }
    }

    /// Nouvelle réunion récurrente : la série, puis ses occurrences jusqu'à la fin de la semaine
    /// prochaine. Renvoie la première occurrence.
    @discardableResult
    mutating func addMeetingSeries(title: String, start: Date, end: Date, recurrence: Recurrence, now: Date, calendar: Calendar = .current) -> Meeting? {
        guard end > start else { return nil }
        let rule = recurrence.anchored(to: start, calendar: calendar)
        let first = rule.first(onOrAfter: start, calendar: calendar)
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let series = MeetingSeries(
            id: UUID().uuidString,
            title: trimmed.isEmpty ? "Réunion" : trimmed,
            firstDay: Format.dayKey(first),
            startMinute: Self.minuteOfDay(start, calendar: calendar),
            durationMinutes: max(1, Int((end.timeIntervalSince(start) / 60).rounded())),
            recurrenceRaw: rule.raw,
            filledThrough: nil
        )
        meetingSeries.append(series)
        fillMeetingSeries(now: now, calendar: calendar)
        return meetings.filter { $0.seriesID == series.id }.min { $0.start < $1.start }
    }

    /// Rend récurrente une réunion simple : elle devient la première occurrence de la série.
    mutating func makeRecurring(_ meetingID: String, recurrence: Recurrence, now: Date, calendar: Calendar = .current) {
        guard let i = meetings.firstIndex(where: { $0.id == meetingID }), meetings[i].seriesID == nil else { return }
        let meeting = meetings[i]
        let rule = recurrence.anchored(to: meeting.start, calendar: calendar)
        let day = Format.dayKey(meeting.start)
        let series = MeetingSeries(
            id: UUID().uuidString,
            title: meeting.title,
            firstDay: day,
            startMinute: Self.minuteOfDay(meeting.start, calendar: calendar),
            durationMinutes: max(1, Int((meeting.end.timeIntervalSince(meeting.start) / 60).rounded())),
            recurrenceRaw: rule.raw,
            filledThrough: day
        )
        meetingSeries.append(series)
        meetings[i].seriesID = series.id
        fillMeetingSeries(now: now, calendar: calendar)
    }

    /// « Toutes les suivantes » : la série prend ce titre, cet horaire et cette répétition à partir de
    /// cette occurrence, qui garde son identifiant (et sa note). Les occurrences suivantes sont
    /// recréées ; celles d'avant restent telles quelles.
    mutating func updateMeetingSeries(from occurrence: Meeting, title: String, start: Date, end: Date, recurrence: Recurrence, now: Date, calendar: Calendar = .current) {
        guard end > start, let id = occurrence.seriesID,
              let i = meetingSeries.firstIndex(where: { $0.id == id }),
              let k = meetings.firstIndex(where: { $0.id == occurrence.id }) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? meetingSeries[i].title : trimmed
        meetings[k].title = name
        meetings[k].start = start
        meetings[k].end = end
        let from = calendar.startOfDay(for: min(occurrence.start, start))
        meetings.removeAll { $0.seriesID == id && $0.id != occurrence.id && $0.start >= from }
        let day = Format.dayKey(start)
        meetingSeries[i] = MeetingSeries(
            id: id,
            title: name,
            firstDay: day,
            startMinute: Self.minuteOfDay(start, calendar: calendar),
            durationMinutes: max(1, Int((end.timeIntervalSince(start) / 60).rounded())),
            recurrenceRaw: recurrence.anchored(to: start, calendar: calendar).raw,
            filledThrough: day
        )
        fillMeetingSeries(now: now, calendar: calendar)
    }

    /// « Ne plus répéter » : cette occurrence et celles d'avant restent, en réunions simples ; les
    /// suivantes sont retirées, et la série oubliée.
    mutating func endMeetingSeries(at occurrence: Meeting) {
        guard let id = occurrence.seriesID else { return }
        meetings.removeAll { $0.seriesID == id && $0.start > occurrence.start }
        for i in meetings.indices where meetings[i].seriesID == id {
            meetings[i].seriesID = nil
        }
        meetingSeries.removeAll { $0.id == id }
    }

    /// Crée les occurrences qui manquent, de la semaine en cours jusqu'à la fin de la semaine
    /// prochaine. Ce qui a déjà été créé une fois (`filledThrough`) ne l'est pas de nouveau.
    mutating func fillMeetingSeries(now: Date, calendar: Calendar = .current) {
        let horizon = Self.meetingHorizon(now: now)
        let weekStart = Stats.week(containing: now).start
        guard let lastDay = calendar.date(byAdding: .day, value: -1, to: horizon) else { return }
        for i in meetingSeries.indices {
            let series = meetingSeries[i]
            guard let rule = series.recurrence, let first = Format.date(fromDayKey: series.firstDay) else { continue }
            let filled = series.filledThrough.flatMap(Format.date(fromDayKey:))
            var day = rule.first(onOrAfter: first, calendar: calendar)
            var steps = 0
            while day < horizon, steps < 2_000 {
                let isNew = filled.map { day > $0 } ?? true
                if isNew, day >= calendar.startOfDay(for: weekStart),
                   let start = calendar.date(byAdding: .minute, value: series.startMinute, to: day) {
                    meetings.append(Meeting(
                        id: UUID().uuidString,
                        title: series.title,
                        start: start,
                        end: start.addingTimeInterval(TimeInterval(series.durationMinutes) * 60),
                        seriesID: series.id
                    ))
                }
                day = rule.next(after: day, today: day, calendar: calendar)
                steps += 1
            }
            if filled.map({ $0 < lastDay }) ?? true {
                meetingSeries[i].filledThrough = Format.dayKey(lastDay)
            }
        }
    }

    private static func minuteOfDay(_ date: Date, calendar: Calendar) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}
