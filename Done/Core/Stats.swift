import Foundation

struct BacklogNumbers: Equatable {
    var openTasks = 0
    /// Tâches de premier niveau : les chantiers.
    var openTopLevel = 0
    var averageAgeDays = 0.0
    var oldestAgeDays = 0.0
    var activeCount = 0
}

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

    struct WeekCount: Identifiable {
        var id: Date { weekStart }
        let weekStart: Date
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

    /// Fenêtre de `days` jours finissant aujourd'hui, décalée de `offset` fenêtres vers le passé.
    static func dayWindow(days: Int = 14, offset: Int, now: Date = .now) -> DateInterval {
        let calendar = Stats.calendar
        let today = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1 + offset * days, to: today) ?? today
        let start = calendar.date(byAdding: .day, value: -days, to: end) ?? today
        return DateInterval(start: start, end: end)
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

    // MARK: Backlog

    static func inScope(_ task: TodoistTask, rules: Rules) -> Bool {
        let scope = rules.backlogScope
        return !Planner.isMeeting(task, rules: rules) && (scope.isEmpty || scope.contains(task.projectId))
    }

    static func backlog(_ index: TaskIndex, rules: Rules, now: Date = .now) -> BacklogNumbers {
        let scoped = index.all.filter { inScope($0, rules: rules) }
        let topLevel = scoped.filter { $0.parentId == nil }
        let ages = topLevel.compactMap { task in task.addedAt.map { now.timeIntervalSince($0) / 86_400 } }
        return BacklogNumbers(
            openTasks: scoped.count,
            openTopLevel: topLevel.count,
            averageAgeDays: ages.isEmpty ? 0 : ages.reduce(0, +) / Double(ages.count),
            oldestAgeDays: ages.max() ?? 0,
            // Un chantier actif compte une fois, même si ses sous-tâches portent aussi le label.
            activeCount: Planner.activeChantiers(in: index, rules: rules).count
        )
    }

    /// Chantiers (tâches de premier niveau) cochés dans Todoist, par semaine.
    static func closedPerWeek(_ completed: [TodoistTask], rules: Rules, weeks: Int, now: Date = .now) -> [WeekCount] {
        let calendar = Stats.calendar
        let thisWeek = week(containing: now).start
        let starts = (0..<weeks).compactMap { calendar.date(byAdding: .weekOfYear, value: -$0, to: thisWeek) }
        return starts.reversed().map { start in
            let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
            let count = completed.filter { task in
                guard task.parentId == nil, inScope(task, rules: rules), let done = task.completedAt else { return false }
                return done >= start && done < end
            }.count
            return WeekCount(weekStart: start, count: count)
        }
    }
}
