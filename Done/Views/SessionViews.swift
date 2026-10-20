import SwiftUI

/// Minuteur en cours ou en pause.
struct SessionView: View {
    @Environment(FocusEngine.self) private var engine
    @State private var showReasons = false

    var body: some View {
        if let current = engine.current {
            let paused = engine.phase == .paused
            VStack(spacing: 0) {
                Text(context(current))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.label2)
                Text(current.action.content)
                    .font(.system(size: 30, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundStyle(Theme.label)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 640)
                    .padding(.top, 8)

                ZStack {
                    ProgressRing(fraction: engine.remainingFraction, color: paused ? Theme.label3 : Theme.accent)
                    VStack(spacing: 6) {
                        Text(Format.clock(engine.remaining))
                            .font(.timer(72))
                            .foregroundStyle(paused ? Theme.label2 : Theme.label)
                        Text(paused ? "En pause" : "sur \(Int(current.planned / 60)) min")
                            .font(.system(size: 13, weight: paused ? .semibold : .regular))
                            .foregroundStyle(Theme.label2)
                    }
                }
                .frame(width: 280, height: 280)
                .padding(.top, 40)

                HStack(spacing: 10) {
                    if paused {
                        Button { engine.resume() } label: { ShortcutLabel(title: "Reprendre", hint: "espace") }
                            .buttonStyle(PillButtonStyle(kind: .primary))
                            .keyboardShortcut(.space, modifiers: [])
                    } else {
                        Button { engine.pause() } label: { ShortcutLabel(title: "Pause", hint: "espace") }
                            .buttonStyle(PillButtonStyle())
                            .keyboardShortcut(.space, modifiers: [])
                    }
                    Button { showReasons = true } label: { ShortcutLabel(title: "Interrompre", hint: "▼") }
                        .buttonStyle(PillButtonStyle())
                        .popover(isPresented: $showReasons, arrowEdge: .bottom) {
                            ReasonMenu { reason in
                                showReasons = false
                                engine.interrupt(reason)
                            }
                        }
                    Button("Terminer") { engine.finishEarly() }
                        .buttonStyle(PillButtonStyle(kind: paused ? .secondary : .primary))
                }
                .padding(.top, 40)
            }
            .padding(.bottom, 40)
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
                        .font(.system(size: 13))
                        .foregroundStyle(hovered == reason ? Color.white : Theme.label)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(hovered == reason ? Theme.accent : Color.clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
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

/// Session interrompue : on garde la place et on attend la suite.
struct InterruptionView: View {
    @Environment(AppModel.self) private var model
    @Environment(FocusEngine.self) private var engine
    let reason: InterruptionReason
    @State private var showPicker = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(spacing: 16) {
                if let ongoing = model.meetingsToday.first(where: { $0.contains(context.date) }) {
                    MeetingBanner(ongoing: ongoing)
                }
                card
            }
            .frame(width: focusCardWidth)
            .padding(.top, 40)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .sheet(isPresented: $showPicker) {
            TaskPickerView(title: "Tâche urgente à mettre en tête du plan") { task in
                model.putFirst(task.id)
                engine.stop(as: .interrupted)
            }
            .environment(model)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                Image(systemName: reason.symbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.label2)
                    .frame(width: 52, height: 52)
                    .background(Theme.fill, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text("Interrompu : \(reason.label)")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.label)
                    if let since = engine.interruptedAt {
                        Text("Depuis \(Format.minutes(engine.now.timeIntervalSince(since) / 60))")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.label2)
                    }
                }
            }
            Hairline().padding(.top, 24)
            if let current = engine.current {
                Eyebrow(text: "Tâche en pause")
                    .padding(.top, 20)
                Text(current.action.content)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.label)
                    .padding(.top, 10)
                Text("Il restait \(Format.clock(engine.remaining)) sur \(Int(current.planned / 60)) min")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.label2)
                    .padding(.top, 4)
            }
            Hairline().padding(.top, 24)
            HStack(spacing: 8) {
                Button("Choisir autre chose") { engine.stop(as: .interrupted) }
                    .buttonStyle(PillButtonStyle())
                Button("Insérer une tâche urgente…") { showPicker = true }
                    .buttonStyle(PillButtonStyle())
                Spacer(minLength: 8)
                Button("Reprendre") { engine.resume() }
                    .buttonStyle(PillButtonStyle(kind: .primary))
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

/// Fin du minuteur : on décide de la suite.
struct OutcomeView: View {
    @Environment(FocusEngine.self) private var engine

    var body: some View {
        if let current = engine.current {
            VStack(alignment: .leading, spacing: 0) {
                ProgressRing(fraction: 1, lineWidth: 6)
                    .frame(width: 56, height: 56)
                Text("Session terminée")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.label)
                    .padding(.top, 20)
                Text("\(Format.minutes(engine.elapsed / 60)) sur « \(current.action.content) »")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.label2)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
                if let error = engine.errorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.redText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Theme.redTint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .padding(.top, 20)
                }
                VStack(spacing: 10) {
                    Button {
                        Task { await engine.markDone() }
                    } label: {
                        if engine.isClosing {
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small).tint(.white)
                                Text("Envoi à Todoist…")
                            }
                        } else {
                            Text(engine.errorMessage == nil ? "Terminé, cocher dans Todoist" : "Réessayer de cocher dans Todoist")
                        }
                    }
                    .buttonStyle(PillButtonStyle(kind: .primary, fullWidth: true))
                    .keyboardShortcut(.defaultAction)
                    HStack(spacing: 8) {
                        Button("Je continue (\(Int(current.planned / 60)) min)") { engine.continueSameAction() }
                            .buttonStyle(PillButtonStyle(fullWidth: true))
                        Button("Pause") { engine.takeBreakAfterSession() }
                            .buttonStyle(PillButtonStyle(fullWidth: true))
                        Button("Arrêter là") { engine.stop(as: .partial) }
                            .buttonStyle(PillButtonStyle(fullWidth: true))
                    }
                }
                .disabled(engine.isClosing)
                .padding(.top, 28)
            }
            .frame(width: focusCardWidth - 64, alignment: .leading)
            .cardStyle()
            .padding(.top, 110)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

struct BreakView: View {
    @Environment(FocusEngine.self) private var engine

    var body: some View {
        VStack(spacing: 0) {
            Eyebrow(text: "Pause")
            ZStack {
                ProgressRing(fraction: engine.breakRemainingFraction)
                VStack(spacing: 6) {
                    Text(Format.clock(engine.breakRemaining))
                        .font(.timer(72))
                        .foregroundStyle(Theme.label)
                    Text("sur \(Int((engine.breakDuration / 60).rounded())) min")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.label2)
                }
            }
            .frame(width: 280, height: 280)
            .padding(.top, 24)
            Text("Lève-toi, bois de l'eau, regarde loin de l'écran.")
                .font(.system(size: 17))
                .foregroundStyle(Theme.label)
                .padding(.top, 40)
            Button("Passer la pause") { engine.skipBreak() }
                .buttonStyle(PillButtonStyle())
                .padding(.top, 24)
        }
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
