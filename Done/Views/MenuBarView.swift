import AppKit
import SwiftUI

/// Libellé de la barre de menus : une image « template » du système, qui prend la couleur de la
/// barre de menus, jamais celle de Done. Mini-anneau de 16 et temps restant en chiffres tabulaires.
struct MenuBarLabel: View {
    let engine: FocusEngine

    var body: some View {
        switch engine.phase {
        case .idle:
            Image("DoneGlyph")
        case .focusing:
            Text("\(MiniRing.image(fraction: engine.remainingFraction)) \(engine.menuBarText)")
                .monospacedDigit()
        case .awaitingOutcome:
            Text("\(MiniRing.image(fraction: 1, isTrackOnly: true)) \(engine.menuBarText)")
        case .paused, .interrupted:
            Text("\(Image(systemName: "pause.fill")) \(engine.menuBarText)")
                .monospacedDigit()
        case .onBreak:
            Text("\(Image(systemName: "cup.and.saucer.fill")) \(engine.menuBarText)")
                .monospacedDigit()
        }
    }
}

/// Mini-anneau de 16 points, rendu en image « template » : la part restante, depuis midi.
private struct MiniRing: View {
    let fraction: Double
    var isTrackOnly = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.black.opacity(isTrackOnly ? 1 : 0.3), lineWidth: 2)
            if !isTrackOnly {
                Circle()
                    .trim(from: 0, to: max(0, min(1, fraction)))
                    .stroke(Color.black, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .padding(1)
        .frame(width: 16, height: 16)
    }

    @MainActor
    static func image(fraction: Double, isTrackOnly: Bool = false) -> Image {
        let renderer = ImageRenderer(content: MiniRing(fraction: fraction, isTrackOnly: isTrackOnly))
        renderer.scale = 2
        guard let image = renderer.nsImage else { return Image("DoneGlyph") }
        image.isTemplate = true
        return Image(nsImage: image)
    }
}

/// Panneau ouvert au clic sur l'icône : 300 pt de large, sur le fond de fenêtre.
/// En haut, la capture rapide ; en dessous, la session en cours.
struct MenuBarView: View {
    @Environment(AppModel.self) private var model
    @Environment(FocusEngine.self) private var engine
    @Environment(\.openWindow) private var openWindow
    @State private var title = ""
    @State private var projectID: String?
    /// Liste de la dernière tâche ajoutée, pour la confirmation. Effacée dès qu'on retape.
    @State private var addedTo: String?
    @FocusState private var captureFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            capture
            Hairline()
                .padding(.vertical, DoneSpace.s16)
            content
            HStack(spacing: DoneSpace.s8) {
                primaryControl
                Button("Ouvrir Done") {
                    openWindow(id: "main")
                    SystemBridge.bringToFront()
                }
                .buttonStyle(DoneButtonStyle(fullWidth: true))
                .keyboardShortcut("o")
            }
            .padding(.top, DoneSpace.s16)
            HStack {
                Spacer()
                Button("Quitter Done") { SystemBridge.quit() }
                    .buttonStyle(DoneButtonStyle(kind: .plain, compact: true))
                    .keyboardShortcut("q")
            }
            .padding(.top, DoneSpace.s6)
        }
        .padding(DoneSpace.s16)
        .frame(width: 300)
        .foregroundStyle(DoneColor.textPrimary)
        .background(DoneColor.bgCanvas)
        .onAppear { captureFocused = true }
        .onDisappear { addedTo = nil }
    }

    /// Une ligne, Entrée : la tâche part dans la liste choisie, et le champ reste prêt pour la suivante.
    private var capture: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Nouvelle tâche")
            TextField("Ce que tu as à faire", text: $title)
                .focused($captureFocused)
                .doneField(focused: captureFocused)
                .onSubmit(add)
                .padding(.top, DoneSpace.s8)
            HStack(spacing: DoneSpace.s8) {
                Menu {
                    Button("Inbox") { projectID = nil }
                    ForEach(model.projects) { project in
                        Button(project.name) { projectID = project.id }
                    }
                } label: {
                    Text("Dans : \(model.projectName(projectID))")
                        .font(.done(.callout))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                Spacer()
                if let addedTo {
                    Text("Ajoutée dans \(addedTo)")
                        .doneText(.caption)
                        .foregroundStyle(DoneColor.textSecondary)
                        .lineLimit(1)
                } else {
                    // Ouvre la saisie complète, avec le titre et la liste déjà choisis.
                    Button("Détails…") {
                        QuickCapturePanel.shared.show(prefill: TaskDraft(title: title, projectID: projectID))
                        title = ""
                    }
                    .buttonStyle(DoneButtonStyle(kind: .plain, compact: true))
                    .help("Saisir la priorité, le type, l'échéance, les notes et les étapes")
                }
            }
            .padding(.top, DoneSpace.s8)
        }
        .onChange(of: title) {
            if !title.isEmpty { addedTo = nil }
        }
    }

    private func add() {
        guard let task = model.addTask(title, projectID: projectID) else { return }
        title = ""
        addedTo = model.listName(for: task)
    }

    @ViewBuilder
    private var content: some View {
        switch engine.phase {
        case .idle:
            Text("Aucune session en cours")
                .font(.sans(14, .semibold))
            Text("Ouvre Done pour lancer la prochaine tâche.")
                .doneText(.caption)
                .foregroundStyle(DoneColor.textSecondary)
                .padding(.top, DoneSpace.s4)
        case .awaitingOutcome:
            Text(engine.checkedAction == nil ? "Session terminée" : "Étape cochée")
                .font(.sans(14, .semibold))
            Text(engine.checkedAction == nil ? "Ouvre Done pour cocher la tâche ou ajouter du temps." : "Ouvre Done pour enchaîner sur la suite.")
                .doneText(.caption)
                .foregroundStyle(DoneColor.textSecondary)
                .padding(.top, DoneSpace.s4)
        case .onBreak:
            caption(engine.breakIsMandatory ? "Pause avant la tâche suivante" : "Pause")
            timer(engine.breakRemaining, total: engine.breakDuration, fraction: engine.breakRemainingFraction, active: true)
        case .focusing, .paused, .interrupted:
            if let current = engine.current {
                caption(engine.phase == .focusing ? current.projectName : statusCaption)
                Text(current.action.title)
                    .font(.sans(14, .semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, DoneSpace.s4)
                timer(engine.remaining, total: current.planned, fraction: engine.remainingFraction, active: engine.phase == .focusing)
            }
        }
    }

    @ViewBuilder
    private var primaryControl: some View {
        switch engine.phase {
        case .focusing:
            Button("Pause") { engine.pause() }
                .buttonStyle(DoneButtonStyle(fullWidth: true))
        case .paused, .interrupted:
            Button("Reprendre") { engine.resume() }
                .buttonStyle(DoneButtonStyle(kind: .primary, fullWidth: true))
        case .onBreak where !engine.breakIsMandatory:
            Button("Passer la pause") { engine.skipBreak() }
                .buttonStyle(DoneButtonStyle(fullWidth: true))
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
            .doneText(.caption)
            .foregroundStyle(DoneColor.textSecondary)
    }

    private func timer(_ remaining: TimeInterval, total: TimeInterval, fraction: Double, active: Bool) -> some View {
        VStack(alignment: .leading, spacing: DoneSpace.s12) {
            HStack(alignment: .firstTextBaseline, spacing: DoneSpace.s8) {
                TimerText(text: Format.clock(remaining), style: .numericL)
                Text("sur \(Int((total / 60).rounded())) min")
                    .doneText(.callout)
                    .foregroundStyle(DoneColor.textSecondary)
            }
            ProgressBar(fraction: fraction, color: active ? DoneColor.pomodoroFocus : DoneColor.pomodoroPaused)
        }
        .padding(.top, DoneSpace.s12)
    }
}
