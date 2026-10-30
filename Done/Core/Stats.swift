import Foundation

enum Stats {
    struct DayFocus: Identifiable {
        var id: Date { day }
        let day: Date
        let minutes: Double
        let sessions: Int
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

    // MARK: Focus

    static func totalMinutes(_ sessions: [SessionFact]) -> Double {
        sessions.reduce(0) { $0 + $1.focusedSeconds } / 60
    }

    static func byDay(_ sessions: [SessionFact], in week: DateInterval) -> [DayFocus] {
        let calendar = Stats.calendar
        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: week.start) else { return nil }
            let items = sessions.filter { calendar.isDate($0.startedAt, inSameDayAs: day) }
            return DayFocus(day: day, minutes: totalMinutes(items), sessions: items.count)
        }
    }

    static func byProject(_ sessions: [SessionFact]) -> [ProjectFocus] {
        Dictionary(grouping: sessions, by: \.projectName)
            .map { ProjectFocus(name: $0.key.isEmpty ? "Sans projet" : $0.key, minutes: totalMinutes($0.value)) }
            .sorted { $0.minutes > $1.minutes }
    }

    static func interruptions(_ sessions: [SessionFact]) -> [ReasonCount] {
        let all = sessions.flatMap(\.interruptions)
        return InterruptionReason.allCases.map { reason in
            ReasonCount(reason: reason, count: all.filter { $0 == reason }.count)
        }
    }
}
