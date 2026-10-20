import Foundation
import UserNotifications

/// Notifications de fin de session et de fin de pause.
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
