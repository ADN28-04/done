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
