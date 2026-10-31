import Foundation

/// Clés UserDefaults des réglages, partagées avec `@AppStorage` dans les vues.
enum SettingsKey {
    static let quickMinutes = "rules.quickMinutes"
    static let defaultMinutes = "rules.defaultMinutes"
    static let deepworkMinutes = "rules.deepworkMinutes"
    static let shortBreakMinutes = "rules.shortBreakMinutes"
    static let longBreakMinutes = "rules.longBreakMinutes"
    static let horizonDays = "rules.horizonDays"
    static let dndEnabled = "rules.dndEnabled"
    static let dndOnShortcut = "rules.dndOnShortcut"
    static let dndOffShortcut = "rules.dndOffShortcut"
    static let reviewHour = "rules.reviewHour"
    static let reviewReminder = "rules.reviewReminder"
    static let planSize = "rules.planSize"
    static let meetingReminder = "rules.meetingReminder"
    static let meetingReminderMinutes = "rules.meetingReminderMinutes"
    static let endSound = "rules.endSound"
    /// Raccourci global de la saisie flottante (`CaptureShortcut`).
    static let captureShortcut = "capture.shortcut"
}

/// Règles de choix et de durée. Les valeurs par défaut viennent de docs/spec.md.
struct Rules {
    var quickMinutes = 15
    var defaultMinutes = 25
    var deepworkMinutes = 50
    var shortBreakMinutes = 5
    var longBreakMinutes = 10
    /// Une tâche dont l'échéance tombe dans ce nombre de jours devient candidate.
    /// Datée plus loin, elle n'est pas proposée avant.
    var horizonDays = 3
    /// Active « Ne pas déranger » pendant les sessions de focus.
    var dndEnabled = false
    /// Raccourcis de l'app Raccourcis qui activent et coupent « Ne pas déranger ».
    var dndOnShortcut = "Done Focus On"
    var dndOffShortcut = "Done Focus Off"
    /// Heure à partir de laquelle Done propose le bilan du soir.
    var reviewHour = 17
    /// Notification de rappel du bilan, du lundi au vendredi.
    var reviewReminder = true
    /// Nombre de tâches mises en avant dans le plan du jour.
    var planSize = 3
    /// Notification quelques minutes avant chaque réunion.
    var meetingReminder = true
    var meetingReminderMinutes = 5
    /// Son joué par Done à la fin des sessions et des pauses, même si les notifications
    /// sont bloquées ou masquées par « Ne pas déranger ».
    var endSound = true

    static let maxPlanSize = 5
    /// Étapes ajoutées d'un coup par la feuille « Découper ».
    static let maxSteps = 10
    /// Rallonge d'un pomodoro : par pas de 5 minutes, 10 au plus.
    static let extensionStepMinutes = 5
    static let maxExtensionMinutes = 10
    /// En dessous, on ne lance pas l'étape suivante dans le pomodoro en cours : pause d'abord.
    static let minChainSeconds: TimeInterval = 60

    static var current: Rules {
        let defaults = UserDefaults.standard
        func int(_ key: String, _ fallback: Int) -> Int {
            (defaults.object(forKey: key) as? Int) ?? fallback
        }
        let base = Rules()
        var rules = base
        rules.quickMinutes = int(SettingsKey.quickMinutes, base.quickMinutes)
        rules.defaultMinutes = int(SettingsKey.defaultMinutes, base.defaultMinutes)
        rules.deepworkMinutes = int(SettingsKey.deepworkMinutes, base.deepworkMinutes)
        rules.shortBreakMinutes = int(SettingsKey.shortBreakMinutes, base.shortBreakMinutes)
        rules.longBreakMinutes = int(SettingsKey.longBreakMinutes, base.longBreakMinutes)
        rules.horizonDays = int(SettingsKey.horizonDays, base.horizonDays)
        rules.dndEnabled = (defaults.object(forKey: SettingsKey.dndEnabled) as? Bool) ?? base.dndEnabled
        rules.dndOnShortcut = defaults.string(forKey: SettingsKey.dndOnShortcut) ?? base.dndOnShortcut
        rules.dndOffShortcut = defaults.string(forKey: SettingsKey.dndOffShortcut) ?? base.dndOffShortcut
        rules.reviewHour = int(SettingsKey.reviewHour, base.reviewHour)
        rules.planSize = min(max(int(SettingsKey.planSize, base.planSize), 1), Rules.maxPlanSize)
        rules.reviewReminder = (defaults.object(forKey: SettingsKey.reviewReminder) as? Bool) ?? base.reviewReminder
        rules.meetingReminder = (defaults.object(forKey: SettingsKey.meetingReminder) as? Bool) ?? base.meetingReminder
        rules.meetingReminderMinutes = min(max(int(SettingsKey.meetingReminderMinutes, base.meetingReminderMinutes), 1), 30)
        rules.endSound = (defaults.object(forKey: SettingsKey.endSound) as? Bool) ?? base.endSound
        return rules
    }
}
