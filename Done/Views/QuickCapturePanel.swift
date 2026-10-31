import AppKit
import SwiftUI

/// Saisie flottante, ouverte par le raccourci global par-dessus n'importe quelle app. Elle prend le
/// clavier sans activer Done : en la fermant, on retrouve l'app d'avant. Un clic ailleurs la masque
/// en gardant la saisie ; Annuler ou Échap l'efface.
@MainActor
final class QuickCapturePanel {
    static let shared = QuickCapturePanel()

    private var panel: CapturePanel?
    private let state = QuickCaptureState()
    private var model: AppModel?
    /// Faux si macOS a refusé le raccourci choisi (déjà pris par une autre app).
    private(set) var shortcutIsActive = true

    private init() {}

    /// À appeler une fois au lancement : branche le modèle et le raccourci des réglages.
    func configure(model: AppModel) {
        self.model = model
        applyShortcut()
    }

    /// Branche le raccourci choisi dans les réglages. Renvoie faux s'il est déjà pris.
    @discardableResult
    func applyShortcut() -> Bool {
        shortcutIsActive = GlobalHotKey.register(CaptureShortcut.current) { [weak self] in self?.toggle() }
        return shortcutIsActive
    }

    /// Le raccourci ouvre la saisie, ou la masque si elle a déjà le clavier.
    func toggle() {
        if let panel, panel.isVisible, panel.isKeyWindow {
            close(clearing: false)
        } else {
            show()
        }
    }

    /// Ouvre la saisie, éventuellement préremplie (titre et liste tapés dans la barre de menus).
    func show(prefill: TaskDraft? = nil) {
        guard let model else { return }
        if let prefill { state.draft = prefill }
        let panel = panel ?? makePanel(model: model)
        self.panel = panel
        if !panel.isVisible {
            if let content = panel.contentView { panel.setContentSize(content.fittingSize) }
            place(panel)
        }
        panel.makeKeyAndOrderFront(nil)
        state.focusRequest += 1
    }

    private func close(clearing: Bool) {
        if clearing { state.draft = TaskDraft() }
        panel?.orderOut(nil)
    }

    private func makePanel(model: AppModel) -> CapturePanel {
        let panel = CapturePanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 480),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            panel.standardWindowButton(button)?.isHidden = true
        }
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.onCancel = { [weak self] in self?.close(clearing: true) }
        panel.onResignKey = { [weak self, weak panel] in
            // Un menu ou le calendrier de l'échéance ne comptent pas : seulement un clic ailleurs.
            guard let panel, panel.childWindows?.isEmpty ?? true, NSApp.keyWindow?.parent !== panel else { return }
            self?.close(clearing: false)
        }
        let root = QuickCaptureView(state: state) { [weak self] in self?.close(clearing: true) }
            .environment(model)
            .font(.done(.body))
            .foregroundStyle(DoneColor.textPrimary)
            .tint(DoneColor.stateActive)
        panel.contentView = NSHostingView(rootView: root)
        return panel
    }

    /// Au centre de l'écran où se trouve la souris, un peu au-dessus du milieu.
    private func place(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main else {
            panel.center()
            return
        }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2, y: visible.minY + visible.height * 0.6 - size.height / 2))
    }
}

/// Saisie en cours, gardée entre deux ouvertures de la fenêtre.
@Observable
@MainActor
private final class QuickCaptureState {
    var draft = TaskDraft()
    var focusRequest = 0
}

private struct QuickCaptureView: View {
    @Bindable var state: QuickCaptureState
    let onClose: () -> Void

    var body: some View {
        CaptureForm(draft: $state.draft, focusRequest: state.focusRequest, onCancel: onClose, onAdded: { _ in onClose() })
            .padding(DoneSpace.s24)
            .frame(width: 560)
            .fixedSize(horizontal: false, vertical: true)
            .background(DoneColor.bgCanvas)
    }
}

/// Fenêtre sans activation de l'app, qui accepte quand même le clavier.
private final class CapturePanel: NSPanel {
    var onCancel: (() -> Void)?
    var onResignKey: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Échap, quand aucun champ ne l'a pris.
    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    override func resignKey() {
        super.resignKey()
        // Après coup : le menu ou la fenêtre qui prend le clavier est alors connu.
        DispatchQueue.main.async { [weak self] in self?.onResignKey?() }
    }
}
