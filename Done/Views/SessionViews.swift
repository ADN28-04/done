import SwiftUI

/// Minuteur en cours ou en pause.
struct SessionView: View {
    @Environment(AppModel.self) private var model
    @Environment(FocusEngine.self) private var engine
    @State private var showReasons = false

    var body: some View {
        if let current = engine.current {
            let paused = engine.phase == .paused
            VStack(spacing: 0) {
                Text(context(current))
                    .font(.text(13))
                    .foregroundStyle(Theme.label2)
                Text(current.action.content)
                    .font(.display(26))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 620)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
                if let note = model.resumeNote(for: current.action.id) {
                    Text("Où tu en étais : \(note.text)")
                        .font(.text(13))
                        .foregroundStyle(Theme.label2)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(maxWidth: 560)
                        .padding(.top, 10)
                }

                ZStack {
                    ProgressRing(fraction: engine.remainingFraction, color: paused ? Theme.label3 : Theme.ring, lineWidth: 14)
                    VStack(spacing: 6) {
                        TimerText(text: Format.clock(engine.remaining), size: 80, color: paused ? Theme.label2 : Theme.label)
                        Text(paused ? "En pause" : "sur \(Int(current.planned / 60)) min")
                            .font(.text(14, paused ? .semibold : .regular))
                            .foregroundStyle(Theme.label2)
                    }
                }
                .frame(width: 320, height: 320)
                .padding(.top, 36)

                HStack(spacing: 10) {
                    if paused {
                        Button("Reprendre") { engine.resume() }
                            .buttonStyle(PillButtonStyle(kind: .primary))
                            .keyboardShortcut(.space, modifiers: [])
                    } else {
                        Button("Pause") { engine.pause() }
                            .buttonStyle(PillButtonStyle())
                            .keyboardShortcut(.space, modifiers: [])
                    }
                    Button("Interrompre") { showReasons = true }
                        .buttonStyle(PillButtonStyle())
                        .popover(isPresented: $showReasons, arrowEdge: .bottom) {
                            ReasonMenu { reason in
                                showReasons = false
                                engine.interrupt(reason)
                            }
                        }
                    Button("Terminer") { engine.finishEarly() }
                        .buttonStyle(PillButtonStyle(kind: paused ? .glass : .primary))
                }
                .padding(.top, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func context(_ current: FocusEngine.Current) -> String {
        guard current.action.id != current.root.id else { return current.projectName }
        return "\(current.projectName) · \(current.root.content)"
    }
}

/// Liste des raisons d'interruption, présentée comme un menu.
private struct ReasonMenu: View {
    let onPick: (InterruptionReason) -> Void
    @State private var hovered: InterruptionReason?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(InterruptionReason.allCases) { reason in
                Button { onPick(reason) } label: {
                    Text(reason.label)
                        .font(.text(13))
                        .foregroundStyle(hovered == reason ? Color.white : Theme.label)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(hovered == reason ? Theme.accent : Color.clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { inside in hovered = inside ? reason : (hovered == reason ? nil : hovered) }
            }
        }
        .padding(5)
        .frame(width: 200)
    }
}

/// Session interrompue : le temps de l'interruption défile, la tâche attend.
struct InterruptionView: View {
    @Environment(AppModel.self) private var model
    @Environment(FocusEngine.self) private var engine
    let reason: InterruptionReason
    @State private var showPicker = false
    @FocusState private var noteFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Eyebrow(text: "Interrompu · \(reason.label)")
            TimerText(text: Format.clock(interruptionDuration), size: 88)
                .padding(.top, 16)
            if let current = engine.current {
                Text("\(Text(current.action.content).foregroundStyle(Theme.label)) attend, \(Format.clock(engine.remaining)) restantes")
                    .font(.text(15))
                    .foregroundStyle(Theme.label2)
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
                    .padding(.top, 24)
                ResumeNoteField(taskID: current.action.id, focused: $noteFocused)
                    .frame(width: 420)
                    .padding(.top, 24)
            }
            HStack(spacing: 10) {
                Button("Choisir autre chose") { engine.stop(as: .interrupted) }
                    .buttonStyle(PillButtonStyle())
                Button("Reprendre") { engine.resume() }
                    .buttonStyle(PillButtonStyle(kind: .primary))
                    // Entrée dans le champ de note ne relance pas le minuteur.
                    .keyboardShortcut(noteFocused ? nil : .defaultAction)
            }
            .padding(.top, 24)
            Button("Insérer une tâche urgente…") { showPicker = true }
                .buttonStyle(PillButtonStyle(kind: .plain, size: .small))
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showPicker) {
            TaskPickerView(title: "Tâche urgente à mettre en tête du plan") { task in
                model.putFirst(task.id)
                engine.stop(as: .interrupted)
            }
            .environment(model)
        }
    }

    private var interruptionDuration: TimeInterval {
        guard let since = engine.interruptedAt else { return 0 }
        return max(0, engine.now.timeIntervalSince(since))
    }
}

/// Fin du minuteur : on décide de la suite.
struct OutcomeView: View {
    @Environment(FocusEngine.self) private var engine
    @FocusState private var noteFocused: Bool

    var body: some View {
        if let current = engine.current {
            VStack(spacing: 0) {
                Image(systemName: "checkmark")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 88, height: 88)
                    .background(Theme.accent, in: Circle())
                Text("Session terminée")
                    .font(.display(36, bold: true))
                    .tracking(-0.54)
                    .padding(.top, 24)
                Text("\(Format.minutes(engine.elapsed / 60)) sur « \(current.action.content) »")
                    .font(.text(16))
                    .foregroundStyle(Theme.label2)
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
                    .padding(.top, 10)
                if let error = engine.errorMessage {
                    NoticeBox(text: error, tone: .error)
                        .frame(width: 360)
                        .padding(.top, 20)
                }
                ResumeNoteField(taskID: current.action.id, placeholder: "Pas fini ? Note où tu en es pour reprendre plus vite", focused: $noteFocused)
                    .frame(width: 360)
                    .padding(.top, 28)
                VStack(spacing: 10) {
                    Button {
                        Task { await engine.markDone() }
                    } label: {
                        if engine.isClosing {
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                Text("Envoi à Todoist…")
                            }
                        } else {
                            Text(engine.errorMessage == nil ? "Cocher dans Todoist" : "Réessayer de cocher dans Todoist")
                        }
                    }
                    .buttonStyle(PillButtonStyle(kind: .primary, fullWidth: true))
                    // Entrée dans le champ de note ne coche pas la tâche.
                    .keyboardShortcut(noteFocused ? nil : .defaultAction)
                    HStack(spacing: 10) {
                        Button("Continuer \(Int(current.planned / 60)) min") { engine.continueSameAction() }
                            .buttonStyle(PillButtonStyle(fullWidth: true))
                        Button("Pause") { engine.takeBreakAfterSession() }
                            .buttonStyle(PillButtonStyle(fullWidth: true))
                    }
                    Button("Arrêter là") { engine.stop(as: .partial) }
                        .buttonStyle(PillButtonStyle(kind: .plain, size: .small))
                }
                .frame(width: 360)
                .disabled(engine.isClosing)
                .padding(.top, 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Pause café : halo sable, anneau qui se vide.
struct BreakView: View {
    @Environment(FocusEngine.self) private var engine

    var body: some View {
        VStack(spacing: 0) {
            Eyebrow(text: "Pause")
            ZStack {
                ProgressRing(fraction: engine.breakRemainingFraction, lineWidth: 12)
                VStack(spacing: 6) {
                    TimerText(text: Format.clock(engine.breakRemaining), size: 72)
                    Text("sur \(Int((engine.breakDuration / 60).rounded())) min")
                        .font(.text(14))
                        .foregroundStyle(Theme.label2)
                }
            }
            .frame(width: 280, height: 280)
            .padding(.top, 24)
            Text("Lève-toi, bois de l'eau, regarde loin de l'écran.")
                .font(.text(17))
                .padding(.top, 32)
            Button("Passer la pause") { engine.skipBreak() }
                .buttonStyle(PillButtonStyle())
                .padding(.top, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
