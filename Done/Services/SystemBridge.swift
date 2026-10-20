import AppKit

/// Appels AppKit utilisés par la logique, regroupés ici.
@MainActor
enum SystemBridge {
    private static var activity: NSObjectProtocol?

    /// Fait rebondir l'icône du Dock quand une session se termine.
    static func requestAttention() {
        NSApp.requestUserAttention(.informationalRequest)
    }

    static func bringToFront() {
        NSApp.activate()
    }

    static func quit() {
        NSApp.terminate(nil)
    }

    /// Empêche App Nap de ralentir le minuteur quand Done est en arrière-plan.
    static func keepTimerAccurate(_ enabled: Bool) {
        if enabled, activity == nil {
            activity = ProcessInfo.processInfo.beginActivity(
                options: .userInitiatedAllowingIdleSystemSleep,
                reason: "Session de focus en cours"
            )
        } else if !enabled, let current = activity {
            ProcessInfo.processInfo.endActivity(current)
            activity = nil
        }
    }

    static func onTerminate(_ action: @escaping @MainActor () -> Void) {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { action() }
        }
    }

    static func openShortcutsApp() {
        if let url = URL(string: "shortcuts://") {
            NSWorkspace.shared.open(url)
        }
    }
}
