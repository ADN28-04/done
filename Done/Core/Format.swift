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

    /// « Semaine du 19 au 25 octobre », ou « du 29 septembre au 5 octobre » à cheval sur deux mois.
    static func weekTitle(_ week: DateInterval) -> String {
        let last = week.end.addingTimeInterval(-1)
        let calendar = Calendar.current
        let sameMonth = calendar.component(.month, from: week.start) == calendar.component(.month, from: last)
        let start = sameMonth ? dayNumber.string(from: week.start) : dayMonth.string(from: week.start)
        return "Semaine du \(start) au \(dayMonth.string(from: last))"
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

    static func due(_ task: TodoistTask, now: Date = .now) -> String? {
        guard let due = task.due, let value = due.value, let day = due.day else { return nil }
        let calendar = Calendar.current
        if day < calendar.startOfDay(for: now) { return "En retard" }
        if calendar.isDate(day, inSameDayAs: now) {
            return due.hasTime ? "Aujourd'hui \(time(value))" : "Aujourd'hui"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(day, inSameDayAs: tomorrow) {
            return "Demain"
        }
        return self.day(day)
    }
}
