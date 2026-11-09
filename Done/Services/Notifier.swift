import Foundation
import UserNotifications

/// Notifications de fin de session et de pause, rappels du bilan et des réunions.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()

    static let focusEnd = "done.focus-end"
    static let breakEnd = "done.break-end"
    /// Rappel d'un bloc de travail, avec ses deux boutons.
    static let workBlockCategory = "done.workblock"
    static let startAction = "done.workblock.start"
    static let postponeAction = "done.workblock.postpone"
    static let moveAction = "done.workblock.move"

    /// Réponse à un rappel de bloc : l'identifiant du bloc et la réponse (« Lancer le pomodoro »,
    /// « Décaler de 30 min », « Déplacer… » ou un clic sur la notification). Appelé sur le fil principal.
    var onWorkBlock: ((String, WorkBlockReminder.Answer) -> Void)?

    /// Ce que macOS permet à Done, affiché dans les Réglages.
    enum Permission: Equatable {
        case allowed
        case notDetermined
        case denied
        /// Autorisées, mais avec le style « Aucun » : rien ne s'affiche.
        case silent
        /// macOS a refusé la demande elle-même, par exemple pour une app mal signée.
        case failed(String)
    }

    private var center: UNUserNotificationCenter { .current() }
    /// Erreur renvoyée par la demande d'autorisation, au lieu d'un oui ou d'un non.
    private var authorizationError: String?

    func setUp() {
        center.delegate = self
        let start = UNNotificationAction(identifier: Self.startAction, title: "Lancer le pomodoro", options: [.foreground])
        // Décaler se fait sans ouvrir Done : la notification suffit.
        let postpone = UNNotificationAction(identifier: Self.postponeAction, title: "Décaler de \(WorkBlockReminder.postponeMinutes) min", options: [])
        let move = UNNotificationAction(identifier: Self.moveAction, title: "Déplacer…", options: [.foreground])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.workBlockCategory, actions: [start, postpone, move], intentIdentifiers: [], options: []),
        ])
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] _, error in
            let message = error?.localizedDescription
            DispatchQueue.main.async { self?.authorizationError = message }
        }
    }

    @MainActor
    func permission() async -> Permission {
        if let authorizationError { return .failed(authorizationError) }
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        default: return settings.alertStyle == UNAlertStyle.none ? .silent : .allowed
        }
    }

    @MainActor
    func requestPermission() async -> Permission {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
            authorizationError = nil
        } catch {
            authorizationError = error.localizedDescription
        }
        return await permission()
    }

    /// Envoie une notification tout de suite. Renvoie le message d'erreur de macOS, ou `nil`.
    func sendTest() async -> String? {
        let content = UNMutableNotificationContent()
        content.title = "Test de Done"
        content.body = "Les notifications de fin de session arriveront comme celle-ci."
        content.sound = .default
        do {
            try await center.add(UNNotificationRequest(identifier: "done.test", content: content, trigger: nil))
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// `sound` à `false` quand Done joue déjà son propre son de fin.
    func schedule(_ id: String, title: String, body: String, after seconds: TimeInterval, sound: Bool = true) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound ? .default : nil
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger), withCompletionHandler: nil)
    }

    /// Notification immédiate, utilisée quand « Ne pas déranger » vient d'être coupé.
    func notifyNow(_ id: String, title: String, body: String, sound: Bool = true) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound ? .default : nil
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil), withCompletionHandler: nil)
    }

    /// Rappel du bilan du soir, du lundi au vendredi à l'heure choisie.
    func updateReviewReminder(enabled: Bool, hour: Int) {
        let ids = (2...6).map { "done.review.\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        guard enabled else { return }
        for weekday in 2...6 {
            let content = UNMutableNotificationContent()
            content.title = "Bilan du soir"
            content.body = "Deux minutes pour clore la journée et préparer demain."
            content.sound = .default
            var time = DateComponents()
            time.weekday = weekday
            time.hour = hour
            time.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
            center.add(UNNotificationRequest(identifier: "done.review.\(weekday)", content: content, trigger: trigger), withCompletionHandler: nil)
        }
    }

    /// Remplace les rappels « réunion proche » déjà programmés par ceux-ci.
    func updateMeetingReminders(_ reminders: [MeetingReminder]) {
        let center = self.center
        let wanted = Set(reminders.map(\.id))
        center.getPendingNotificationRequests { requests in
            let stale = requests.map(\.identifier).filter { $0.hasPrefix(MeetingReminder.prefix) && !wanted.contains($0) }
            center.removePendingNotificationRequests(withIdentifiers: stale)
        }
        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            let moment = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reminder.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: moment, repeats: false)
            center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger), withCompletionHandler: nil)
        }
    }

    /// Remplace les rappels de blocs de travail déjà programmés par ceux-ci.
    func updateWorkBlockReminders(_ reminders: [WorkBlockReminder]) {
        let center = self.center
        let wanted = Set(reminders.map(\.id))
        center.getPendingNotificationRequests { requests in
            let stale = requests.map(\.identifier).filter { $0.hasPrefix(WorkBlockReminder.prefix) && !wanted.contains($0) }
            center.removePendingNotificationRequests(withIdentifiers: stale)
        }
        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            content.categoryIdentifier = Self.workBlockCategory
            let moment = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reminder.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: moment, repeats: false)
            center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger), withCompletionHandler: nil)
        }
    }

    func cancel(_ ids: String...) {
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // Affiche aussi la notification quand Done est au premier plan.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // Bouton d'un rappel de bloc, ou clic sur le rappel : Done s'ouvre et lance le pomodoro, ou montre le bloc.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        let action = response.actionIdentifier
        if let blockID = WorkBlockReminder.blockID(fromNotification: identifier), action != UNNotificationDismissActionIdentifier {
            let answer: WorkBlockReminder.Answer = switch action {
            case Self.startAction: .start
            case Self.postponeAction: .postpone
            default: .move
            }
            DispatchQueue.main.async { [weak self] in self?.onWorkBlock?(blockID, answer) }
        }
        completionHandler()
    }
}
