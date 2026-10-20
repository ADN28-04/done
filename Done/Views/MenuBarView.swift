import AppKit
import SwiftUI

/// Glyphe monochrome de la marque pour la barre de menus (image « template »).
enum MenuBarGlyph {
    static let mark: NSImage = {
        let image = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            let lineWidth: CGFloat = 2.3
            let bounds = rect.insetBy(dx: lineWidth / 2 + 1, dy: lineWidth / 2 + 1)
            let center = NSPoint(x: rect.midX, y: rect.midY)

            NSColor.black.withAlphaComponent(0.35).setStroke()
            let ring = NSBezierPath(ovalIn: bounds)
            ring.lineWidth = lineWidth
            ring.stroke()

            // Arc de 315° partant du haut, dans le sens des aiguilles d'une montre.
            NSColor.black.setStroke()
            let arc = NSBezierPath()
            arc.appendArc(withCenter: center, radius: bounds.width / 2, startAngle: 90, endAngle: -225, clockwise: true)
            arc.lineWidth = lineWidth
            arc.lineCapStyle = .round
            arc.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }()
}

/// Icône et minuteur dans la barre de menus.
struct MenuBarLabel: View {
    let engine: FocusEngine

    var body: some View {
        switch engine.phase {
        case .idle:
            Image(nsImage: MenuBarGlyph.mark)
        case .focusing, .awaitingOutcome:
            Text("\(Image(nsImage: MenuBarGlyph.mark)) \(engine.menuBarText)")
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

/// Panneau ouvert au clic sur l'icône : 280 pt, style fenêtre.
struct MenuBarView: View {
    @Environment(FocusEngine.self) private var engine
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
            Hairline()
                .padding(.vertical, 8)
            MenuRow(title: "Ouvrir Done", shortcut: "⌘O") {
                openWindow(id: "main")
                SystemBridge.bringToFront()
            }
            .keyboardShortcut("o")
            MenuRow(title: "Quitter", shortcut: "⌘Q") { SystemBridge.quit() }
                .keyboardShortcut("q")
        }
        .padding(14)
        .frame(width: 280)
    }

    @ViewBuilder
    private var content: some View {
        switch engine.phase {
        case .idle:
            Text("Aucune session en cours")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.label)
            Text("Ouvre Done pour lancer la prochaine tâche.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.label2)
                .padding(.top, 4)
        case .awaitingOutcome:
            Text("Session terminée")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.label)
            Text("Ouvre Done pour cocher la tâche ou continuer.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.label2)
                .padding(.top, 4)
        case .onBreak:
            caption("Pause café")
            timer(engine.breakRemaining, total: engine.breakDuration, fraction: engine.breakRemainingFraction)
            Button("Passer la pause") { engine.skipBreak() }
                .buttonStyle(PillButtonStyle(fullWidth: true))
                .padding(.top, 12)
        case .focusing, .paused, .interrupted:
            if let current = engine.current {
                caption(engine.phase == .focusing ? current.projectName : statusCaption)
                Text(current.action.content)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.label)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
                timer(engine.remaining, total: current.planned, fraction: engine.remainingFraction)
                if engine.phase == .focusing {
                    Button("Pause") { engine.pause() }
                        .buttonStyle(PillButtonStyle(fullWidth: true))
                        .padding(.top, 12)
                } else {
                    Button("Reprendre") { engine.resume() }
                        .buttonStyle(PillButtonStyle(kind: .primary, fullWidth: true))
                        .padding(.top, 12)
                }
            }
        }
    }

    private var statusCaption: String {
        if case .interrupted(let reason) = engine.phase {
            return "Interrompu : \(reason.label)"
        }
        return "En pause"
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(Theme.label2)
    }

    private func timer(_ remaining: TimeInterval, total: TimeInterval, fraction: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Format.clock(remaining))
                    .font(.timer(34))
                    .foregroundStyle(Theme.label)
                Text("sur \(Int((total / 60).rounded())) min")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.label2)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.track)
                    Capsule()
                        .fill(engine.phase == .focusing || engine.phase == .onBreak ? Theme.accent : Theme.label3)
                        .frame(width: proxy.size.width * max(0, min(1, fraction)))
                }
            }
            .frame(height: 4)
        }
        .padding(.top, 8)
    }
}

/// Ligne façon menu macOS, surlignée au survol.
private struct MenuRow: View {
    let title: String
    let shortcut: String
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Text(shortcut)
                    .foregroundStyle(hovered ? Color.white.opacity(0.8) : Theme.label2)
            }
            .font(.system(size: 13))
            .foregroundStyle(hovered ? Color.white : Theme.label)
            .padding(.horizontal, 6)
            .frame(height: 24)
            .background(hovered ? Theme.accent : Color.clear, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}
