import Carbon.HIToolbox
import Foundation

/// Raccourcis proposés pour la saisie flottante. Pas d'enregistreur libre : quelques combinaisons
/// que macOS n'utilise pas par défaut, choisies dans les réglages.
enum CaptureShortcut: String, CaseIterable, Identifiable {
    case controlOptionN
    case controlOptionT
    case controlOptionSpace
    case off

    static let standard = CaptureShortcut.controlOptionN

    var id: String { rawValue }

    var label: String {
        switch self {
        case .controlOptionN: "⌃⌥N"
        case .controlOptionT: "⌃⌥T"
        case .controlOptionSpace: "⌃⌥Espace"
        case .off: "Désactivé"
        }
    }

    /// Le raccourci enregistré dans les réglages, ou celui par défaut.
    static var current: CaptureShortcut {
        UserDefaults.standard.string(forKey: SettingsKey.captureShortcut).flatMap(CaptureShortcut.init(rawValue:)) ?? .standard
    }

    /// Code de touche et modificateurs Carbon, `nil` si désactivé.
    fileprivate var keys: (code: UInt32, modifiers: UInt32)? {
        let modifiers = UInt32(controlKey | optionKey)
        switch self {
        case .controlOptionN: return (UInt32(kVK_ANSI_N), modifiers)
        case .controlOptionT: return (UInt32(kVK_ANSI_T), modifiers)
        case .controlOptionSpace: return (UInt32(kVK_Space), modifiers)
        case .off: return nil
        }
    }
}

/// Raccourci clavier global, actif même quand Done n'est pas au premier plan. Passe par
/// `RegisterEventHotKey` (Carbon) : aucune autorisation d'accessibilité à demander.
@MainActor
enum GlobalHotKey {
    private static var hotKey: EventHotKeyRef?
    private static var handler: EventHandlerRef?
    private static var action: (() -> Void)?

    /// Remplace le raccourci actif. Renvoie faux si macOS refuse la combinaison, déjà prise par une autre app.
    @discardableResult
    static func register(_ shortcut: CaptureShortcut, action: @escaping () -> Void) -> Bool {
        unregister()
        guard let keys = shortcut.keys else { return true }
        self.action = action
        if handler == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), hotKeyPressed, 1, &spec, nil, &handler)
        }
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x444F_4E45), id: 1) // « DONE »
        let status = RegisterEventHotKey(keys.code, keys.modifiers, id, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return false }
        hotKey = ref
        return true
    }

    static func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
    }

    fileprivate static func fire() {
        action?()
    }
}

/// Rappel Carbon, sans contexte capturé : il repasse sur le fil principal.
private func hotKeyPressed(_ call: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    Task { @MainActor in GlobalHotKey.fire() }
    return noErr
}
