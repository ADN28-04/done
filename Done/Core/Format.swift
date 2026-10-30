import Foundation

enum Format {
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEE d MMM"
        return f
    }()

    /// 1499 s → "25:00".
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    /// 80 → "1 h 20", 45 → "45 min".
    static func minutes(_ minutes: Double) -> String {
        let rounded = Int(minutes.rounded())
        if minutes > 0 && rounded == 0 { return "moins d'1 min" }
        if rounded < 60 { return "\(rounded) min" }
        let rest = rounded % 60
        return rest == 0 ? "\(rounded / 60) h" : "\(rounded / 60) h \(String(format: "%02d", rest))"
    }

    static func time(_ date: Date) -> String { timeFormatter.string(from: date) }

    static func day(_ date: Date) -> String { dayFormatter.string(from: date) }

    /// Moment d'une note : « aujourd'hui à 15:40 », « hier à 15:40 », sinon « mar. 21 oct. ».
    static func moment(_ date: Date, now: Date = .now) -> String {
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: now) { return "aujourd'hui à \(time(date))" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return "hier à \(time(date))"
        }
        return day(date)
    }

    private static func french(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = format
        return f
    }

    private static let dayNumber = french("d")
    private static let dayMonth = french("d MMMM")
    private static let dayShortMonth = french("d MMM")

    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Clé de jour locale, comparable comme du texte : « 2026-10-21 ».
    static func dayKey(_ date: Date) -> String {
        dayKeyFormatter.string(from: date)
    }

    /// Début du jour local d'une clé de jour. `nil` si la clé est mal formée.
    static func date(fromDayKey key: String) -> Date? {
        dayKeyFormatter.date(from: key).map { Calendar.current.startOfDay(for: $0) }
    }

    /// « Semaine du 19 au 25 octobre », ou « du 29 septembre au 5 octobre » à cheval sur deux mois.
    static func weekTitle(_ week: DateInterval) -> String {
        "Semaine \(span(week))"
    }

    /// « Du 19 au 25 octobre ».
    static func weekRange(_ week: DateInterval) -> String {
        "D" + span(week).dropFirst()
    }

    private static func span(_ week: DateInterval) -> String {
        let last = week.end.addingTimeInterval(-1)
        let calendar = Calendar.current
        let sameMonth = calendar.component(.month, from: week.start) == calendar.component(.month, from: last)
        let start = sameMonth ? dayNumber.string(from: week.start) : dayMonth.string(from: week.start)
        return "du \(start) au \(dayMonth.string(from: last))"
    }

    /// Jour abrégé, semaine commençant le lundi : Lun, Mar… Dim.
    static func weekdayShort(_ date: Date) -> String {
        let names = ["Dim", "Lun", "Mar", "Mer", "Jeu", "Ven", "Sam"]
        return names[Calendar(identifier: .gregorian).component(.weekday, from: date) - 1]
    }

    /// « 8 oct. » pour les axes des graphiques.
    static func shortDate(_ date: Date) -> String {
        dayShortMonth.string(from: date)
    }

    /// Initiale du jour, semaine commençant le lundi : L M M J V S D.
    static func weekdayInitial(_ date: Date) -> String {
        let letters = ["D", "L", "M", "M", "J", "V", "S"]
        return letters[Calendar(identifier: .gregorian).component(.weekday, from: date) - 1]
    }

    /// Numéro de semaine ISO : « S43 ».
    static func weekNumber(_ date: Date) -> String {
        "S\(Calendar(identifier: .iso8601).component(.weekOfYear, from: date))"
    }

    /// Graduation en heures : 0, « 1 h », « 2 h »…
    static func hours(_ minutes: Double) -> String {
        minutes == 0 ? "0" : "\(Int((minutes / 60).rounded())) h"
    }

    /// Créneau d'une réunion : « 10:00–11:00 », précédé du jour quand ce n'est pas aujourd'hui.
    static func slot(_ meeting: Meeting, now: Date = .now) -> String {
        let range = "\(time(meeting.start))–\(time(meeting.end))"
        let calendar = Calendar.current
        if calendar.isDate(meeting.start, inSameDayAs: now) { return range }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(meeting.start, inSameDayAs: tomorrow) {
            return "Demain \(range)"
        }
        return "\(day(meeting.start)) \(range)"
    }

    /// Date d'une puce : « Auj. », « Demain », « Hier », sinon « mar. 3 nov. ».
    static func chipDate(_ day: Date, now: Date = .now) -> String {
        let calendar = Calendar.current
        if calendar.isDate(day, inSameDayAs: now) { return "Auj." }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(day, inSameDayAs: tomorrow) {
            return "Demain"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(day, inSameDayAs: yesterday) {
            return "Hier"
        }
        return self.day(day)
    }

    /// Échéance dépassée : le jour est avant aujourd'hui.
    static func isOverdue(_ day: Date, now: Date = .now) -> Bool {
        day < Calendar.current.startOfDay(for: now)
    }

    static func due(_ task: TodoTask, now: Date = .now) -> String? {
        guard let day = task.due else { return nil }
        let calendar = Calendar.current
        if day < calendar.startOfDay(for: now) { return "En retard" }
        if calendar.isDate(day, inSameDayAs: now) { return "Aujourd'hui" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(day, inSameDayAs: tomorrow) {
            return "Demain"
        }
        return self.day(day)
    }
}
