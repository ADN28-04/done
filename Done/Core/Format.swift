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
