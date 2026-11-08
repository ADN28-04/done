import Foundation

/// Répétition d'une tâche de premier niveau. Cochée, la tâche laisse place à la suivante, avec les
/// mêmes détails et ses étapes rouvertes. L'échéance suivante se compte depuis la sienne : un
/// reporting du lundi coché mercredi revient lundi prochain. Elle tombe toujours après aujourd'hui.
enum Recurrence: Hashable {
    case daily
    /// Du lundi au vendredi.
    case weekdays
    /// Certains jours de la semaine, numérotés comme `Calendar` : 1 pour dimanche, 2 pour lundi…
    /// Vide : le jour de l'échéance (« chaque semaine »), fixé à l'enregistrement.
    case weekly(Set<Int>)
    /// Toutes les deux semaines, le même jour que l'échéance.
    case biweekly
    /// Chaque mois, ce jour-là, ou le dernier jour d'un mois plus court. 0 : le jour de l'échéance
    /// (« chaque mois »), fixé à l'enregistrement.
    case monthly(Int)

    /// Jours de la semaine dans l'ordre français, lundi d'abord.
    static let weekOrder = [2, 3, 4, 5, 6, 7, 1]

    static func dayName(_ weekday: Int) -> String {
        ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"][(weekday - 1) % 7]
    }

    // MARK: Texte

    /// « Chaque jour », « Jours ouvrés », « Chaque lundi et jeudi », « Chaque mois, le 15 ».
    var label: String {
        switch self {
        case .daily:
            return "Chaque jour"
        case .weekdays:
            return "Jours ouvrés"
        case .weekly(let days):
            let names = Self.weekOrder.filter { days.contains($0) }.map { Self.dayName($0) }
            guard let last = names.last else { return "Chaque semaine" }
            return "Chaque " + (names.count == 1 ? last : names.dropLast().joined(separator: ", ") + " et " + last)
        case .biweekly:
            return "Toutes les deux semaines"
        case .monthly(let day):
            return day == 0 ? "Chaque mois" : "Chaque mois, le \(Format.ordinalDay(day))"
        }
    }

    /// Forme enregistrée dans tasks.json et passée par le connecteur : « daily », « weekdays »,
    /// « weekly:2,5 », « biweekly », « monthly:15 ».
    var raw: String {
        switch self {
        case .daily: "daily"
        case .weekdays: "weekdays"
        case .weekly(let days): "weekly" + (days.isEmpty ? "" : ":" + days.sorted().map(String.init).joined(separator: ","))
        case .biweekly: "biweekly"
        case .monthly(let day): "monthly" + (day == 0 ? "" : ":\(day)")
        }
    }

    init?(raw: String) {
        let parts = raw.trimmingCharacters(in: .whitespaces).lowercased().split(separator: ":", maxSplits: 1).map(String.init)
        guard let kind = parts.first else { return nil }
        let value = parts.count > 1 ? parts[1] : ""
        switch kind {
        case "daily":
            self = .daily
        case "weekdays":
            self = .weekdays
        case "weekly":
            let days = value.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            guard days.allSatisfy({ (1...7).contains($0) }) else { return nil }
            self = .weekly(Set(days))
        case "biweekly":
            self = .biweekly
        case "monthly":
            if value.isEmpty {
                self = .monthly(0)
            } else {
                guard let day = Int(value), (1...31).contains(day) else { return nil }
                self = .monthly(day)
            }
        default:
            return nil
        }
    }

    // MARK: Dates

    /// La répétition rendue précise par l'échéance : « chaque semaine » prend son jour de la semaine,
    /// « chaque mois » son jour du mois.
    func anchored(to due: Date, calendar: Calendar = .current) -> Recurrence {
        switch self {
        case .weekly(let days) where days.isEmpty:
            return .weekly([calendar.component(.weekday, from: due)])
        case .monthly(0):
            return .monthly(calendar.component(.day, from: due))
        default:
            return self
        }
    }

    /// Première date de la répétition à partir de `day` inclus : l'échéance d'une tâche qui devient
    /// récurrente sans en avoir.
    func first(onOrAfter day: Date, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: day)
        if case .biweekly = self { return start }
        return search(from: start, includingStart: true, calendar: calendar) ?? start
    }

    /// Échéance de la tâche suivante : la première date de la répétition après l'échéance actuelle
    /// et après aujourd'hui.
    func next(after due: Date, today: Date, calendar: Calendar = .current) -> Date {
        let dueDay = calendar.startOfDay(for: due)
        let reference = max(dueDay, calendar.startOfDay(for: today))
        if case .biweekly = self {
            var candidate = dueDay
            repeat {
                candidate = calendar.date(byAdding: .day, value: 14, to: candidate) ?? reference.addingTimeInterval(14 * 86_400)
            } while candidate <= reference
            return candidate
        }
        return anchored(to: dueDay, calendar: calendar).search(from: reference, includingStart: false, calendar: calendar)
            ?? calendar.date(byAdding: .day, value: 1, to: reference) ?? reference
    }

    private func search(from start: Date, includingStart: Bool, calendar: Calendar) -> Date? {
        for offset in (includingStart ? 0 : 1)...400 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            if matches(day, calendar: calendar) { return calendar.startOfDay(for: day) }
        }
        return nil
    }

    private func matches(_ day: Date, calendar: Calendar) -> Bool {
        let weekday = calendar.component(.weekday, from: day)
        switch self {
        case .daily:
            return true
        case .weekdays:
            return (2...6).contains(weekday)
        case .weekly(let days):
            return days.isEmpty || days.contains(weekday)
        case .biweekly:
            return true
        case .monthly(let wanted):
            guard wanted > 0, let range = calendar.range(of: .day, in: .month, for: day) else { return true }
            return calendar.component(.day, from: day) == min(wanted, range.count)
        }
    }
}
