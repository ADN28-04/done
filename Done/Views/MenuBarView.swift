import SwiftUI

/// Icône et minuteur dans la barre de menus.
struct MenuBarLabel: View {
    let engine: FocusEngine

    var body: some View {
        if engine.phase == .idle {
            Image(systemName: "scope")
        } else {
            Text("\(Image(systemName: engine.menuBarSymbol)) \(engine.menuBarText)")
        }
    }
}

struct MenuBarView: View {
    @Environment(FocusEngine.self) private var engine
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch engine.phase {
            case .idle:
                Text("Aucune session en cours").foregroundStyle(.secondary)
            case .onBreak:
                Text("Pause : \(Format.clock(engine.breakRemaining))").font(.headline)
            case .awaitingOutcome:
                Text("Session terminée").font(.headline)
                Text("Ouvre Done pour cocher la tâche ou continuer.").foregroundStyle(.secondary)
            case .focusing, .paused, .interrupted:
                if let current = engine.current {
                    Text(current.action.content)
                        .font(.headline)
                        .lineLimit(2)
                    Text("\(Format.clock(engine.remaining)) restantes")
                        .font(.title3.monospacedDigit())
                }
            }

            HStack {
                if engine.phase == .focusing {
                    Button("Pause") { engine.pause() }
                } else if engine.phase == .paused {
                    Button("Reprendre") { engine.resume() }
                }
                Spacer()
                Button("Ouvrir Done") {
                    openWindow(id: "main")
                    SystemBridge.bringToFront()
                }
            }
            Divider()
            Button("Quitter Done") { SystemBridge.quit() }
                .buttonStyle(.borderless)
        }
        .padding(14)
        .frame(width: 280)
    }
}
