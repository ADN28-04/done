import SwiftUI

/// Icône et minuteur dans la barre de menus. `DoneGlyph` est une image « template » du catalogue :
/// macOS la colore selon la barre de menus.
struct MenuBarLabel: View {
    let engine: FocusEngine

    var body: some View {
        switch engine.phase {
        case .idle:
            Image("DoneGlyph")
        case .focusing, .awaitingOutcome:
            Text("\(Image("DoneGlyph")) \(engine.menuBarText)")
                .monospacedDigit()
        case .paused, .interrupted:
            Text("\(Image(systemName: "pause.fill")) \(engine.menuBarText)")
                .monospacedDigit()
        case .onBreak:
            Text("\(Image(systemName: "cup.and.saucer.fill")) \(engine.menuBarText)")
                .monospacedDigit()
        }
    }
}

/// Panneau ouvert au clic sur l'icône, en verre : 300 pt de large.
struct MenuBarView: View {
    @Environment(FocusEngine.self) private var engine
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
            HStack(spacing: 8) {
                primaryControl
                Button("Ouvrir Done") {
                    openWindow(id: "main")
                    SystemBridge.bringToFront()
                }
                .buttonStyle(PillButtonStyle(size: .small, fullWidth: true))
                .keyboardShortcut("o")
            }
            .padding(.top, 16)
            HStack {
                Spacer()
                Button("Quitter Done") { SystemBridge.quit() }
                    .buttonStyle(PillButtonStyle(kind: .plain, size: .mini))
                    .keyboardShortcut("q")
            }
            .padding(.top, 6)
        }
        .padding(18)
        .frame(width: 300)
        .background(Backdrop(style: .wash).opacity(0.6))
    }

    @ViewBuilder
    private var content: some View {
        switch engine.phase {
        case .idle:
            Text("Aucune session en cours")
                .font(.text(15, .semibold))
            Text("Ouvre Done pour lancer la prochaine tâche.")
                .font(.text(12))
                .foregroundStyle(Theme.label2)
                .padding(.top, 4)
        case .awaitingOutcome:
            Text(engine.checkedAction == nil ? "Session terminée" : "Étape cochée")
                .font(.text(15, .semibold))
            Text(engine.checkedAction == nil ? "Ouvre Done pour cocher la tâche ou ajouter du temps." : "Ouvre Done pour enchaîner sur la suite.")
                .font(.text(12))
                .foregroundStyle(Theme.label2)
                .padding(.top, 4)
        case .onBreak:
            caption(engine.breakIsMandatory ? "Pause avant la tâche suivante" : "Pause café")
            timer(engine.breakRemaining, total: engine.breakDuration, fraction: engine.breakRemainingFraction, active: true)
        case .focusing, .paused, .interrupted:
            if let current = engine.current {
                caption(engine.phase == .focusing ? current.projectName : statusCaption)
                Text(current.action.title)
                    .font(.text(15, .semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
                timer(engine.remaining, total: current.planned, fraction: engine.remainingFraction, active: engine.phase == .focusing)
            }
        }
    }

    @ViewBuilder
    private var primaryControl: some View {
        switch engine.phase {
        case .focusing:
            Button("Pause") { engine.pause() }
                .buttonStyle(PillButtonStyle(size: .small, fullWidth: true))
        case .paused, .interrupted:
            Button("Reprendre") { engine.resume() }
                .buttonStyle(PillButtonStyle(kind: .primary, size: .small, fullWidth: true))
        case .onBreak where !engine.breakIsMandatory:
            Button("Passer la pause") { engine.skipBreak() }
                .buttonStyle(PillButtonStyle(size: .small, fullWidth: true))
        case .idle, .awaitingOutcome, .onBreak:
            EmptyView()
        }
    }

    private var statusCaption: String {
        if case .interrupted(let reason) = engine.phase {
            return "Interrompu · \(reason.label)"
        }
        return "En pause"
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.text(12))
            .foregroundStyle(Theme.label2)
    }

    private func timer(_ remaining: TimeInterval, total: TimeInterval, fraction: Double, active: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TimerText(text: Format.clock(remaining), size: 40)
                Text("sur \(Int((total / 60).rounded())) min")
                    .font(.text(13))
                    .foregroundStyle(Theme.label2)
            }
            ProgressBar(fraction: fraction, color: active ? Theme.ring : Theme.label3)
        }
        .padding(.top, 14)
    }
}
