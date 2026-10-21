import Foundation

/// Rappel « réunion proche », programmé quelques minutes avant une réunion lue dans Todoist.
struct MeetingReminder: Equatable {
    /// Préfixe des identifiants de notification, pour retrouver les rappels déjà programmés.
    static let prefix = "done.meeting."

    let id: String
    let fireDate: Date
    let title: String
    let body: String

    /// Rappels des réunions à venir, hors blocs de travail. Une réunion trop proche
    /// pour être annoncée à temps n'a pas de rappel.
    static func plan(_ meetings: [Meeting], now: Date, minutes: Int) -> [MeetingReminder] {
        meetings.compactMap { meeting in
            guard !meeting.isFocusBlock else { return nil }
            let fireDate = meeting.start.addingTimeInterval(-TimeInterval(minutes * 60))
            guard fireDate > now else { return nil }
            let name = meeting.title.isEmpty ? "La réunion" : "« \(meeting.title) »"
            return MeetingReminder(
                id: prefix + meeting.id,
                fireDate: fireDate,
                title: "Réunion à \(Format.time(meeting.start))",
                body: "\(name) commence dans \(minutes) min."
            )
        }
    }
}
