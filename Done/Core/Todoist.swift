import Foundation

/// Tâche telle que renvoyée par l'API Todoist v1 (`/api/v1/tasks`).
struct TodoistTask: Decodable, Identifiable, Hashable {
    let id: String
    let content: String
    let description: String
    let projectId: String
    let sectionId: String?
    let parentId: String?
    let labels: [String]
    /// Priorité au format API : 4 = P1 (urgent) … 1 = P4 (normal).
    let priority: Int
    let due: TodoistDue?
    let deadline: TodoistDeadline?
    let duration: TodoistDuration?
    let childOrder: Int
    let addedAt: Date?
    let completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, content, description, labels, priority, due, deadline, duration
        case projectId = "project_id"
        case sectionId = "section_id"
        case parentId = "parent_id"
        case childOrder = "child_order"
        case addedAt = "added_at"
        case completedAt = "completed_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        content = try c.decode(String.self, forKey: .content)
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        projectId = try c.decode(String.self, forKey: .projectId)
        sectionId = try c.decodeIfPresent(String.self, forKey: .sectionId)
        parentId = try c.decodeIfPresent(String.self, forKey: .parentId)
        labels = try c.decodeIfPresent([String].self, forKey: .labels) ?? []
        priority = try c.decodeIfPresent(Int.self, forKey: .priority) ?? 1
        due = try c.decodeIfPresent(TodoistDue.self, forKey: .due)
        deadline = try c.decodeIfPresent(TodoistDeadline.self, forKey: .deadline)
        duration = try c.decodeIfPresent(TodoistDuration.self, forKey: .duration)
        childOrder = try c.decodeIfPresent(Int.self, forKey: .childOrder) ?? 0
        addedAt = try c.decodeIfPresent(String.self, forKey: .addedAt).flatMap(TodoistDate.parse)
        completedAt = try c.decodeIfPresent(String.self, forKey: .completedAt).flatMap(TodoistDate.parse)
    }

    /// Priorité telle qu'affichée dans Todoist : 1 pour P1 … 4 pour P4.
    var displayPriority: Int { 5 - priority }

    func hasLabel(_ name: String) -> Bool {
        labels.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
    }
}

struct TodoistDue: Decodable, Hashable {
    /// "2026-10-21", "2026-10-21T09:00:00" (heure locale) ou "2026-10-21T07:00:00Z".
    let date: String
    let string: String?
    let isRecurring: Bool

    enum CodingKeys: String, CodingKey {
        case date, string
        case isRecurring = "is_recurring"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decode(String.self, forKey: .date)
        string = try c.decodeIfPresent(String.self, forKey: .string)
        isRecurring = try c.decodeIfPresent(Bool.self, forKey: .isRecurring) ?? false
    }

    var hasTime: Bool { date.count > 10 }
    var value: Date? { TodoistDate.parse(date) }
    var day: Date? { value.map { Calendar.current.startOfDay(for: $0) } }
}

struct TodoistDeadline: Decodable, Hashable {
    let date: String

    var day: Date? { TodoistDate.parse(date).map { Calendar.current.startOfDay(for: $0) } }
}

struct TodoistDuration: Decodable, Hashable {
    let amount: Int
    /// "minute" ou "day".
    let unit: String

    var minutes: Int { unit == "day" ? amount * 24 * 60 : amount }
}

struct TodoistProject: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let childOrder: Int
    let isInbox: Bool
    let isArchived: Bool

    enum CodingKeys: String, CodingKey {
        case id, name
        case childOrder = "child_order"
        case isInbox = "inbox_project"
        case isArchived = "is_archived"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        childOrder = try c.decodeIfPresent(Int.self, forKey: .childOrder) ?? 0
        isInbox = try c.decodeIfPresent(Bool.self, forKey: .isInbox) ?? false
        isArchived = try c.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
    }
}

/// Formats de date de l'API Todoist.
enum TodoistDate {
    private static func formatter(_ format: String, utc: Bool) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = utc ? TimeZone(identifier: "UTC") : TimeZone.current
        f.dateFormat = format
        return f
    }

    private static let dayFormatter = formatter("yyyy-MM-dd", utc: false)
    private static let localFormatter = formatter("yyyy-MM-dd'T'HH:mm:ss", utc: false)
    private static let utcFormatter = formatter("yyyy-MM-dd'T'HH:mm:ss", utc: true)

    /// Accepte une date seule, une date-heure locale ou une date-heure UTC (avec ou sans fraction de seconde).
    static func parse(_ raw: String) -> Date? {
        if raw.count == 10 { return dayFormatter.date(from: raw) }
        let isUTC = raw.hasSuffix("Z")
        var trimmed = isUTC ? String(raw.dropLast()) : raw
        if let dot = trimmed.firstIndex(of: ".") {
            trimmed = String(trimmed[..<dot])
        }
        return (isUTC ? utcFormatter : localFormatter).date(from: trimmed)
    }

    /// Format attendu par les paramètres `since` et `until` de l'API.
    static func apiString(_ date: Date) -> String {
        utcFormatter.string(from: date) + "Z"
    }
}
