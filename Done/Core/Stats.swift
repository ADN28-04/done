import Foundation

enum Stats {
    struct DayFocus: Identifiable {
        var id: Date { day }
        let day: Date
        let minutes: Double
        let sessions: Int
        /// Minuteurs menés au bout ce jour-là (`pomodoros(_:on:)`).
        var pomodoros = 0
    }

    struct ProjectFocus: Identifiable {
        var id: String { name }
        let name: String
        let minutes: Double
    }

    struct ReasonCount: Identifiable {
        var id: String { reason.rawValue }
        let reason: InterruptionReason
        let count: Int
    }

    /// Semaines du lundi au dimanche.
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        return calendar
    }

    static func week(containing date: Date) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: date, duration: 7 * 86_400)
    }

    // MARK: Pomodoros

    /// Pomodoros du jour : sessions dont le minuteur est allé au bout, rallonges comprises. Une tâche
    /// cochée avant la fin ou une session arrêtée ne compte pas. Une seconde de marge pour l'arrondi.
    static func pomodoros(_ sessions: [SessionFact], on day: Date) -> Int {
        sessions.filter { calendar.isDate($0.startedAt, inSameDayAs: day) && isPomodoro($0) }.count
    }

    static func isPomodoro(_ session: SessionFact) -> Bool {
        session.plannedSeconds > 0 && session.focusedSeconds >= session.plannedSeconds - 1
    }

    /// Série : jours d'affilée avec au moins un pomodoro, en remontant depuis `day`. Le jour même ne la
    /// casse pas (il n'est pas fini), ni un week-end ou un jour de congé sans pomodoro : ils ne comptent
    /// simplement pas.
    static func streak(_ sessions: [SessionFact], through day: Date, isDayOff: (Date) -> Bool = { _ in false }) -> Int {
        let calendar = Stats.calendar
        let days = Set(sessions.filter(isPomodoro).map { calendar.startOfDay(for: $0.startedAt) })
        guard let first = days.min() else { return 0 }
        var current = calendar.startOfDay(for: day)
        var count = 0
        var isFirst = true
        while current >= first {
            if days.contains(current) {
                count += 1
            } else if !isFirst && !calendar.isDateInWeekend(current) && !isDayOff(current) {
                break
            }
            isFirst = false
            guard let previous = calendar.date(byAdding: .day, value: -1, to: current) else { break }
            current = previous
        }
        return count
    }

    /// Pomodoros par jour avec au moins une session, à une décimale : « 2,5 », « 3 », « 0 ».
    static func perWorkedDay(_ days: [DayFocus]) -> String {
        let worked = days.filter { $0.sessions > 0 }.count
        guard worked > 0 else { return "0" }
        let pomodoros = days.reduce(0) { $0 + $1.pomodoros }
        let average = (Double(pomodoros) / Double(worked) * 10).rounded() / 10
        return average == average.rounded() ? "\(Int(average))" : String(format: "%.1f", average).replacingOccurrences(of: ".", with: ",")
    }

    // MARK: Focus

    /// L'écart avec la semaine d'avant : « 45 min de plus qu'à ce moment la semaine dernière » pour la
    /// semaine en cours (comparée jusqu'au même moment), « Autant que la semaine d'avant » pour une passée.
    static func comparison(total: Double, previous: Double, isCurrent: Bool) -> String {
        if total == 0 && previous == 0 {
            return isCurrent ? "Pas encore de focus cette semaine." : "Aucune session cette semaine-là."
        }
        if previous == 0 { return isCurrent ? "Rien à ce moment la semaine dernière." : "Rien la semaine d'avant." }
        let reference = isCurrent ? "qu'à ce moment la semaine dernière" : "que la semaine d'avant"
        let difference = total - previous
        if abs(difference) < 1 { return "Autant \(reference)." }
        return "\(Format.minutes(abs(difference))) de \(difference > 0 ? "plus" : "moins") \(reference)."
    }

    static func totalMinutes(_ sessions: [SessionFact]) -> Double {
        sessions.reduce(0) { $0 + $1.focusedSeconds } / 60
    }

    static func byDay(_ sessions: [SessionFact], in week: DateInterval) -> [DayFocus] {
        let calendar = Stats.calendar
        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: week.start) else { return nil }
            let items = sessions.filter { calendar.isDate($0.startedAt, inSameDayAs: day) }
            return DayFocus(day: day, minutes: totalMinutes(items), sessions: items.count, pomodoros: pomodoros(items, on: day))
        }
    }

    /// La meilleure journée de la semaine : le plus de focus. Aucune sans focus ; la première en cas d'égalité.
    static func bestDay(_ days: [DayFocus]) -> Date? {
        guard let best = days.max(by: { $0.minutes < $1.minutes }), best.minutes > 0 else { return nil }
        return days.first { $0.minutes == best.minutes }?.day
    }

    static func byProject(_ sessions: [SessionFact]) -> [ProjectFocus] {
        Dictionary(grouping: sessions, by: \.projectName)
            .map { ProjectFocus(name: $0.key.isEmpty ? "Sans projet" : $0.key, minutes: totalMinutes($0.value)) }
            .sorted { $0.minutes > $1.minutes }
    }

    // MARK: Heures

    /// Minutes de focus par heure de la journée (24 valeurs) : chaque session s'étale depuis son début.
    static func byHour(_ sessions: [SessionFact], calendar: Calendar = .current) -> [Double] {
        var minutes = Array(repeating: 0.0, count: 24)
        for session in sessions {
            var cursor = session.startedAt
            var left = session.focusedSeconds
            var steps = 0
            while left > 0, steps < 48, let hour = calendar.dateInterval(of: .hour, for: cursor) {
                let chunk = min(left, hour.end.timeIntervalSince(cursor))
                minutes[calendar.component(.hour, from: cursor)] += chunk / 60
                left -= chunk
                cursor = hour.end
                steps += 1
            }
        }
        return minutes
    }

    /// Les heures d'affilée les plus concentrées (deux par défaut) : 9..<11 pour « de 9 h à 11 h ».
    /// Rien sans focus ; la plus tôt en cas d'égalité ; une heure vide au bord de la plage en sort.
    static func bestHours(_ byHour: [Double], span: Int = 2) -> Range<Int>? {
        guard span > 0, byHour.count >= span else { return nil }
        var best: (start: Int, total: Double)?
        for start in 0...(byHour.count - span) {
            let total = byHour[start..<start + span].reduce(0, +)
            if total > (best?.total ?? 0) { best = (start, total) }
        }
        guard let best else { return nil }
        var lower = best.start
        var upper = best.start + span
        while upper - lower > 1, byHour[lower] == 0 { lower += 1 }
        while upper - lower > 1, byHour[upper - 1] == 0 { upper -= 1 }
        return lower..<upper
    }

    // MARK: Interruptions

    static func interruptions(_ sessions: [SessionFact]) -> [ReasonCount] {
        let all = sessions.flatMap(\.interruptions)
        return InterruptionReason.allCases.map { reason in
            ReasonCount(reason: reason, count: all.filter { $0 == reason }.count)
        }
    }
}
