import AppKit

/// Appels AppKit utilisés par la logique, regroupés ici.
enum SystemBridge {
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
}
