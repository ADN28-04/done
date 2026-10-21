import Foundation
import UserNotifications

/// Notifications de fin de session et de pause, rappels du bilan et des réunions.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()

    static let focusEnd = "done.focus-end"
    static let breakEnd = "done.break-end"

    private var center: UNUserNotificationCenter { .current() }

    func setUp() {
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func schedule(_ id: String, title: String, body: String, after seconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger), withCompletionHandler: nil)
    }

    /// Notification immédiate, utilisée quand « Ne pas déranger » vient d'être coupé.
    func notifyNow(_ id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
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
}
