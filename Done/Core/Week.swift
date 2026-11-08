import Foundation

/// Semaine de travail du calendrier, du lundi au vendredi, et règles d'affichage.
enum WorkWeek {
    /// Les cinq jours ouvrés de la semaine qui contient `date`, chacun au début du jour.
    static func days(containing date: Date) -> [Date] {
        let monday = Stats.week(containing: date).start
        return (0..<5).compactMap { Stats.calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    /// Du lundi au vendredi inclus, pour le titre (« Semaine du 2 au 6 novembre »).
    static func interval(containing date: Date) -> DateInterval {
        let days = days(containing: date)
        let end = Stats.calendar.date(byAdding: .day, value: 1, to: days.last ?? date) ?? date
        return DateInterval(start: days.first ?? date, end: end)
    }

    /// Les tâches ouvertes à montrer un jour : leur échéance, à partir d'aujourd'hui. Aujourd'hui reprend
    /// aussi les tâches en retard, pour les replacer ; un jour passé n'en montre aucune. Les retards
    /// d'abord, puis par priorité.
    static func dueTasks(on day: Date, in tasks: [TodoTask], today: Date, calendar: Calendar = .current) -> [TodoTask] {
        let dayStart = calendar.startOfDay(for: day)
        let todayStart = calendar.startOfDay(for: today)
        guard dayStart >= todayStart else { return [] }
        return tasks
            .filter { task in
                guard task.isOpen, let due = task.due else { return false }
                return dayStart == todayStart ? due <= todayStart : calendar.isDate(due, inSameDayAs: dayStart)
            }
            .sorted { a, b in
                let dueA = a.due ?? dayStart, dueB = b.due ?? dayStart
                if dueA != dueB { return dueA < dueB }
                if a.priority != b.priority { return a.priority < b.priority }
                return a.title.localizedStandardCompare(b.title) == .orderedAscending
            }
    }

    /// Colonne d'un événement parmi ceux qui se chevauchent : son rang et le nombre de colonnes du groupe.
    struct Lane: Equatable {
        let index: Int
        let count: Int
    }

    struct Slot {
        let id: String
        let start: Date
        let end: Date
    }

    /// Place côte à côte les événements qui se chevauchent. Un groupe réunit les événements liés de
    /// proche en proche ; chacun prend la première colonne libre (à début égal, le plus long d'abord),
    /// et tout le groupe partage la même largeur.
    static func lanes(_ slots: [Slot]) -> [String: Lane] {
        var result: [String: Lane] = [:]
        var group: [(id: String, lane: Int)] = []
        var laneEnds: [Date] = []
        var groupEnd = Date.distantPast

        func closeGroup() {
            for item in group { result[item.id] = Lane(index: item.lane, count: laneEnds.count) }
            group = []
            laneEnds = []
        }

        for slot in slots.sorted(by: { $0.start != $1.start ? $0.start < $1.start : $0.end > $1.end }) {
            if slot.start >= groupEnd { closeGroup() }
            let lane = laneEnds.firstIndex { $0 <= slot.start } ?? laneEnds.count
            if lane == laneEnds.count { laneEnds.append(slot.end) } else { laneEnds[lane] = slot.end }
            group.append((slot.id, lane))
            groupEnd = max(groupEnd, slot.end)
        }
        closeGroup()
        return result
    }
}

/// Ce que l'écran Aujourd'hui montre en plus du plan et des réunions.
enum DayAgenda {
    /// Plan du jour bouclé : au moins une tâche en est sortie cochée et il n'y reste aucune tâche
    /// ouverte. Un plan vidé sans rien cocher ne compte pas.
    static func isPlanFinished(plan: [String], done: [String], isOpen: (String) -> Bool) -> Bool {
        !done.isEmpty && !plan.contains(where: isOpen)
    }

    /// Échéances du jour et retards qui ne sont pas dans le plan, les retards d'abord.
    static func dueOrLate(in tasks: [TodoTask], plan: [String], today: Date) -> [TodoTask] {
        WorkWeek.dueTasks(on: today, in: tasks, today: today).filter { !plan.contains($0.id) }
    }

    /// Créneaux libres entre `from` et `to` : ce qui reste hors des moments pris (réunions, focus),
    /// en morceaux d'au moins `minimumMinutes`, dans l'ordre.
    static func freeSlots(busy: [DateInterval], from: Date, to: Date, minimumMinutes: Int = 30) -> [DateInterval] {
        guard from < to else { return [] }
        var slots: [DateInterval] = []
        var cursor = from
        for interval in busy.sorted(by: { $0.start < $1.start }) where interval.end > cursor {
            if interval.start >= to { break }
            if interval.start > cursor { slots.append(DateInterval(start: cursor, end: interval.start)) }
            cursor = max(cursor, interval.end)
        }
        if cursor < to { slots.append(DateInterval(start: cursor, end: to)) }
        return slots.filter { $0.duration >= Double(minimumMinutes) * 60 }
    }

    /// Pomodoros qui tiennent dans un créneau : chacun prend `focus` minutes, suivies d'une pause de
    /// `pause` minutes, sauf le dernier.
    static func pomodoros(fitting minutes: Int, focus: Int, pause: Int) -> Int {
        guard focus > 0, minutes >= focus else { return 0 }
        return (minutes + pause) / (focus + pause)
    }

    /// Tâches cochées dans la journée, les plus récentes d'abord.
    static func doneToday(in tasks: [TodoTask], today: Date, calendar: Calendar = .current) -> [TodoTask] {
        tasks
            .filter { $0.completedAt.map { calendar.isDate($0, inSameDayAs: today) } ?? false }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }
}
