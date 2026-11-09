import Foundation

/// Rappel quand rien n'est lancé : au bout de 20 min sans session ni pause, en semaine de 9 h à 18 h,
/// hors réunion, bloc de travail et jour de congé, une fois par heure au plus. Le rappel propose la
/// prochaine action ; « Pas maintenant » le laisse se taire jusqu'à l'heure suivante.
enum IdleReminder {
    static let idleMinutes = 20
    static let spacingMinutes = 60
    /// Heures de travail, en minutes depuis minuit.
    static let workStart = 9 * 60
    static let workEnd = 18 * 60
    /// Identifiant de la notification.
    static let identifier = "done.idle"

    /// Done doit-il rappeler qu'aucune session n'est lancée ? `idleSince` : depuis quand rien ne tourne
    /// (fin de la dernière session ou pause, ou lancement de Done) ; le compte ne commence pas avant 9 h.
    static func isDue(
        now: Date,
        idleSince: Date,
        lastReminder: Date?,
        store: TaskStore,
        absence: Bool,
        calendar: Calendar = .current
    ) -> Bool {
        let parts = calendar.dateComponents([.weekday, .hour, .minute], from: now)
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        guard (2...6).contains(parts.weekday ?? 1), minute >= workStart, minute < workEnd, !absence else { return false }
        let dayStart = calendar.startOfDay(for: now)
        let startOfWork = dayStart.addingTimeInterval(TimeInterval(workStart) * 60)
        let since = max(idleSince, startOfWork)
        guard now.timeIntervalSince(since) >= TimeInterval(idleMinutes) * 60 else { return false }
        if let lastReminder, now.timeIntervalSince(lastReminder) < TimeInterval(spacingMinutes) * 60 { return false }
        guard !store.meetings.contains(where: { $0.contains(now) }) else { return false }
        guard !store.workBlocks.contains(where: { $0.contains(now) }) else { return false }
        return true
    }

    /// Le texte du rappel, avec la prochaine action quand il y en a une.
    static func message(nextAction: String?) -> (title: String, body: String) {
        let title = "Rien de lancé depuis \(idleMinutes) min"
        guard let nextAction else {
            return (title, "Choisis par quoi commencer, ou fais le plan du jour.")
        }
        return (title, "Prochaine action : « \(nextAction) ». Un pomodoro ?")
    }
}
