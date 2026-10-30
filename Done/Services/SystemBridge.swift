import AppKit

/// Appels AppKit utilisés par la logique, regroupés ici.
@MainActor
enum SystemBridge {
    private static var activity: NSObjectProtocol?

    /// Fait rebondir l'icône du Dock quand une session se termine, jusqu'au retour dans Done.
    static func requestAttention() {
        NSApp.requestUserAttention(.criticalRequest)
    }

    /// Son système de macOS (« Glass », « Hero »…), joué par Done lui-même.
    static func playSound(_ name: String) {
        NSSound(named: NSSound.Name(name))?.play()
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

    /// Ouvre les réglages de notifications de Done dans Réglages Système.
    static func openNotificationSettings() {
        let id = Bundle.main.bundleIdentifier ?? ""
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Ouvre une fenêtre du Finder sur le fichier, sélectionné.
    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func openShortcutsApp() {
        if let url = URL(string: "shortcuts://") {
            NSWorkspace.shared.open(url)
        }
    }
}
