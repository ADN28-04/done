import Foundation

/// Glisser et étirer un élément dans la grille horaire (réunion, et plus tard bloc de travail) : les
/// heures s'alignent sur le quart d'heure, l'élément reste dans les heures de la grille, garde au
/// moins un quart d'heure, et ne part jamais vers un moment déjà passé.
enum TimelineEdit {
    /// Pas d'alignement, en minutes.
    static let step = 15
    /// Durée minimale, en minutes.
    static let minimumMinutes = 15

    /// La nouvelle plage après un déplacement de `minutes` (vers le bas si positif) et de `days` jours.
    /// La durée ne change pas ; le début s'aligne sur le quart d'heure le plus proche, puis la plage est
    /// ramenée entre `firstHour` et `lastHour` du jour visé. Nil si elle commencerait dans le passé
    /// (avant le quart d'heure en cours).
    static func moved(
        _ interval: DateInterval,
        byMinutes minutes: Double,
        days: Int,
        firstHour: Int,
        lastHour: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> DateInterval? {
        guard let shifted = calendar.date(byAdding: .day, value: days, to: interval.start) else { return nil }
        let duration = interval.duration
        let dayStart = calendar.startOfDay(for: shifted)
        guard
            let gridStart = calendar.date(bySettingHour: firstHour, minute: 0, second: 0, of: dayStart),
            let gridEnd = calendar.date(byAdding: .hour, value: lastHour, to: dayStart)
        else { return nil }
        var start = snapped(shifted.addingTimeInterval(minutes * 60), dayStart: dayStart)
        // Ramène la plage dans la grille, sans changer sa durée.
        if start.addingTimeInterval(duration) > gridEnd { start = gridEnd.addingTimeInterval(-duration) }
        if start < gridStart { start = gridStart }
        guard start >= currentQuarter(now, calendar: calendar) else { return nil }
        return DateInterval(start: start, duration: duration)
    }

    /// La nouvelle plage après avoir étiré la fin de `minutes` (vers le bas si positif). La fin s'aligne
    /// sur le quart d'heure le plus proche, garde au moins un quart d'heure après le début et ne dépasse
    /// pas `lastHour`. Nil si la fin tomberait dans le passé.
    static func resized(
        _ interval: DateInterval,
        byMinutes minutes: Double,
        lastHour: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> DateInterval? {
        let dayStart = calendar.startOfDay(for: interval.start)
        guard let gridEnd = calendar.date(byAdding: .hour, value: lastHour, to: dayStart) else { return nil }
        var end = snapped(interval.end.addingTimeInterval(minutes * 60), dayStart: dayStart)
        let shortest = interval.start.addingTimeInterval(Double(minimumMinutes) * 60)
        if end < shortest { end = shortest }
        if end > gridEnd { end = max(gridEnd, shortest) }
        guard end > now else { return nil }
        return DateInterval(start: interval.start, end: end)
    }

    /// `date` au quart d'heure le plus proche, compté depuis minuit.
    static func snapped(_ date: Date, dayStart: Date) -> Date {
        let minutes = date.timeIntervalSince(dayStart) / 60
        let rounded = (minutes / Double(step)).rounded() * Double(step)
        return dayStart.addingTimeInterval(rounded * 60)
    }

    /// Le début du quart d'heure en cours : on peut encore poser un élément à 10:30 à 10:37.
    static func currentQuarter(_ now: Date, calendar: Calendar = .current) -> Date {
        let dayStart = calendar.startOfDay(for: now)
        let minutes = Int(now.timeIntervalSince(dayStart) / 60)
        return dayStart.addingTimeInterval(Double(minutes / step * step) * 60)
    }
}
