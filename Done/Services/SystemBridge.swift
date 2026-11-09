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

    /// Un clic hors de tout champ de texte termine la saisie en cours : le champ perd le curseur et
    /// son contour de focus, comme sur le web, au lieu de les garder jusqu'au prochain champ.
    /// Un clic dans un autre champ, ou dans le même, garde le comportement habituel.
    static func endEditingOnOutsideClicks() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            guard let window = event.window, window.firstResponder is NSText else { return event }
            let target = window.contentView?.superview?.hitTest(event.locationInWindow)
                ?? window.contentView?.hitTest(event.locationInWindow)
            if !isTextInput(target) {
                window.makeFirstResponder(nil)
            }
            return event
        }
    }

    private static var outsideClickMonitor: Any?

    /// Un champ de texte, une zone de texte, ou une vue qu'ils contiennent.
    private static func isTextInput(_ view: NSView?) -> Bool {
        var current = view
        while let candidate = current {
            if candidate is NSTextField || candidate is NSTextView { return true }
            current = candidate.superview
        }
        return false
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

    /// Met le texte dans le presse-papiers.
    static func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// Ouvre une fenêtre du Finder sur le fichier, sélectionné.
    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Ouvre Réglages Système › Confidentialité et sécurité › Rappels.
    static func openRemindersSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders") {
            NSWorkspace.shared.open(url)
        }
    }

    static func openShortcutsApp() {
        if let url = URL(string: "shortcuts://") {
            NSWorkspace.shared.open(url)
        }
    }
}
