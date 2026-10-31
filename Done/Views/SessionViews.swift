import SwiftUI

/// Minuteur en cours ou en pause.
struct SessionView: View {
    @Environment(AppModel.self) private var model
    @Environment(FocusEngine.self) private var engine
    var onBlocked: () -> Void
    @State private var showReasons = false

    var body: some View {
        if let current = engine.current {
            let paused = engine.phase == .paused
            VStack(spacing: 0) {
                Text(context(current))
                    .doneText(.callout)
                    .foregroundStyle(DoneColor.textSecondary)
                Text(current.action.title)
                    .doneText(.displayM)
                    .foregroundStyle(DoneColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 620)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, DoneSpace.s6)
                if let steps = Planner.stepsAfter(current.action, in: model.index) {
                    StepsBadge(stepsAfter: steps)
                        .padding(.top, DoneSpace.s12)
                }
                if let note = model.resumeNote(for: current.action.id) {
                    Text("Où tu en étais : \(note.text)")
                        .doneText(.callout)
                        .foregroundStyle(DoneColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(maxWidth: 560)
                        .padding(.top, DoneSpace.s8)
                }

                // Anneau de 280, trait 12 : Indigo en concentration, gris à l'arrêt.
                ZStack {
                    ProgressRing(fraction: engine.remainingFraction, color: paused ? DoneColor.pomodoroPaused : DoneColor.pomodoroFocus)
                    VStack(spacing: DoneSpace.s4) {
                        TimerText(text: Format.clock(engine.remaining), color: paused ? DoneColor.textSecondary : DoneColor.textPrimary)
                        if paused {
                            Label("En pause", systemImage: "pause.fill")
                                .font(.sans(13, .semibold))
                                .foregroundStyle(DoneColor.textSecondary)
                        } else {
                            Text("sur \(Int(current.planned / 60)) min")
                                .doneText(.callout)
                                .foregroundStyle(DoneColor.textSecondary)
                        }
                    }
                }
                .frame(width: 280, height: 280)
                .padding(.top, DoneSpace.s32)

                HStack(spacing: DoneSpace.s8) {
                    if paused {
                        Button("Reprendre") { engine.resume() }
                            .buttonStyle(DoneButtonStyle(kind: .primary))
                            .keyboardShortcut(.space, modifiers: [])
                    } else {
                        Button("Pause") { engine.pause() }
                            .buttonStyle(DoneButtonStyle())
                            .keyboardShortcut(.space, modifiers: [])
                    }
                    Button("Interrompre") { showReasons = true }
                        .buttonStyle(DoneButtonStyle())
                        .popover(isPresented: $showReasons, arrowEdge: .bottom) {
                            ReasonMenu { reason in
                                showReasons = false
                                engine.interrupt(reason)
                            }
                        }
                    // Fini avant la sonnerie : on coche tout de suite, l'écran suivant propose la suite.
                    Button("C'est fait") {
                        engine.finishEarly()
                        engine.markDone()
                    }
                    .buttonStyle(DoneButtonStyle())
                    .keyboardShortcut(.return, modifiers: .command)
                    .help("Cocher la tâche (⌘↩)")
                }
                .padding(.top, DoneSpace.s40)
                HStack(spacing: DoneSpace.s2) {
                    if engine.canExtend {
                        Button("Ajouter \(Rules.extensionStepMinutes) min") { engine.extend() }
                            .buttonStyle(DoneButtonStyle(kind: .plain))
                            .help("\(Rules.maxExtensionMinutes) minutes de plus au maximum par session")
                    }
                    Button("Bloqué…", action: onBlocked)
                        .buttonStyle(DoneButtonStyle(kind: .plain))
                        .help("Laisser cette étape ouverte, marquée bloquée, et passer à la suite")
                }
                .padding(.top, DoneSpace.s8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func context(_ current: FocusEngine.Current) -> String {
        guard current.action.id != current.root.id else { return current.projectName }
        return "\(current.projectName) · \(current.root.title)"
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
                        .doneText(.callout)
                        .foregroundStyle(hovered == reason ? Color.white : DoneColor.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DoneSpace.s8)
                        .frame(height: 28)
                        .background(hovered == reason ? DoneColor.actionPrimary : Color.clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
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
            TimerText(text: Format.clock(interruptionDuration))
                .padding(.top, DoneSpace.s16)
            if let current = engine.current {
                Text("\(Text(current.action.title).foregroundStyle(DoneColor.textPrimary)) attend, \(Format.clock(engine.remaining)) restantes")
                    .doneText(.body)
                    .foregroundStyle(DoneColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
                    .padding(.top, DoneSpace.s24)
                ResumeNoteField(taskID: current.action.id, focused: $noteFocused)
                    .frame(width: 420)
                    .padding(.top, DoneSpace.s24)
            }
            HStack(spacing: DoneSpace.s8) {
                Button("Choisir autre chose") { engine.stop(as: .interrupted) }
                    .buttonStyle(DoneButtonStyle())
                Button("Reprendre") { engine.resume() }
                    .buttonStyle(DoneButtonStyle(kind: .primary))
                    // Entrée dans le champ de note ne relance pas le minuteur.
                    .keyboardShortcut(noteFocused ? nil : .defaultAction)
            }
            .padding(.top, DoneSpace.s24)
            Button("Insérer une tâche urgente…") { showPicker = true }
                .buttonStyle(DoneButtonStyle(kind: .plain))
                .padding(.top, DoneSpace.s8)
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

/// Fin du minuteur, ou action cochée en avance : carte de transition, comme la fin de pomodoro du design system.
struct OutcomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(FocusEngine.self) private var engine
    var onBlocked: () -> Void
    @FocusState private var noteFocused: Bool

    var body: some View {
        if let current = engine.current {
            VStack(alignment: .leading, spacing: 0) {
                if let checked = engine.checkedAction, let followUp = engine.followUp {
                    checkedContent(checked, followUp: followUp)
                } else {
                    sessionEnded(current)
                }
            }
            .padding(DoneSpace.s24)
            .frame(width: 520)
            .doneRaised()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Anneau Indigo coché et titre de la carte.
    private func header(_ title: String, subtitle: String) -> some View {
        HStack(spacing: DoneSpace.s16) {
            ZStack {
                Circle()
                    .strokeBorder(DoneColor.pomodoroFocus, lineWidth: 3)
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(DoneColor.pomodoroFocus)
            }
            .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: DoneSpace.s2) {
                Text(title)
                    .doneText(.displayM)
                    .foregroundStyle(DoneColor.textPrimary)
                Text(subtitle)
                    .doneText(.callout)
                    .foregroundStyle(DoneColor.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Étape cochée avant la fin

    @ViewBuilder
    private func checkedContent(_ checked: TodoTask, followUp: Planner.FollowUp) -> some View {
        header(title(for: followUp), subtitle: "« \(checked.title) » est cochée.")
        if let next = nextLine(for: followUp) {
            VStack(alignment: .leading, spacing: DoneSpace.s6) {
                Eyebrow(text: "Ensuite")
                Text(next.title)
                    .doneText(.title)
                    .foregroundStyle(DoneColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let steps = next.stepsAfter {
                    StepsBadge(stepsAfter: steps)
                }
            }
            .padding(DoneSpace.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DoneColor.bgSunken, in: RoundedRectangle(cornerRadius: DoneRadius.md, style: .continuous))
            .padding(.top, DoneSpace.s20)
        }
        HStack(spacing: DoneSpace.s8) {
            switch followUp {
            case .step:
                Button("Enchaîner · \(Format.clock(engine.remaining)) restantes") { engine.chainToNext() }
                    .buttonStyle(DoneButtonStyle(kind: .primary))
                    .keyboardShortcut(.defaultAction)
            case .closeRoot(let root):
                Button("Cocher « \(root.title) »") { engine.closeRoot() }
                    .buttonStyle(DoneButtonStyle(kind: .primary))
                    .keyboardShortcut(.defaultAction)
            case .switchTask:
                EmptyView()
            }
            Button("Pause d'abord") { engine.takeBreakAfterSession() }
                .buttonStyle(DoneButtonStyle())
            Button("Arrêter là") { engine.stop(as: .done) }
                .buttonStyle(DoneButtonStyle(kind: .plain))
        }
        .padding(.top, DoneSpace.s20)
        if case .closeRoot = followUp {
            Text("Ensuite, \(engine.breakMinutesAfterSession) min de pause avant la tâche suivante.")
                .doneText(.caption)
                .foregroundStyle(DoneColor.textSecondary)
                .padding(.top, DoneSpace.s12)
        }
    }

    private func title(for followUp: Planner.FollowUp) -> String {
        if case .closeRoot = followUp { return "Toutes les étapes sont faites" }
        return "Étape terminée"
    }

    private func nextLine(for followUp: Planner.FollowUp) -> (title: String, stepsAfter: Int?)? {
        guard case .step(let next) = followUp else { return nil }
        return (next.title, Planner.stepsAfter(next, in: model.index))
    }

    // MARK: Minuteur fini

    @ViewBuilder
    private func sessionEnded(_ current: FocusEngine.Current) -> some View {
        header("Pomodoro terminé", subtitle: "\(Format.minutes(engine.stepElapsed / 60)) sur « \(current.action.title) »")
        ResumeNoteField(taskID: current.action.id, placeholder: "Pas fini ? Note où tu en es pour reprendre plus vite", focused: $noteFocused)
            .padding(.top, DoneSpace.s20)
        HStack(spacing: DoneSpace.s8) {
            Button("Cocher la tâche") { engine.markDone() }
                .buttonStyle(DoneButtonStyle(kind: .primary))
                // Entrée dans le champ de note ne coche pas la tâche.
                .keyboardShortcut(noteFocused ? nil : .defaultAction)
            if engine.canExtend {
                Button("Encore \(Rules.extensionStepMinutes) min") { engine.extend() }
                    .buttonStyle(DoneButtonStyle())
            }
            Button("Pause, puis je reprends") { engine.takeBreakAfterSession() }
                .buttonStyle(DoneButtonStyle())
        }
        .padding(.top, DoneSpace.s16)
        HStack(spacing: DoneSpace.s4) {
            Button("Bloqué…", action: onBlocked)
                .buttonStyle(DoneButtonStyle(kind: .plain))
                .help("Laisser cette étape ouverte, marquée bloquée, et passer à la suite")
            Button("Arrêter là") { engine.stop(as: .partial) }
                .buttonStyle(DoneButtonStyle(kind: .plain))
            Spacer(minLength: 0)
        }
        .padding(.top, DoneSpace.s8)
        if !engine.canExtend {
            Text("Déjà \(Rules.maxExtensionMinutes) min de plus : une pause avant de continuer.")
                .doneText(.caption)
                .foregroundStyle(DoneColor.textSecondary)
                .padding(.top, DoneSpace.s4)
        }
    }
}

/// Repère dans une tâche découpée : combien d'étapes restent après celle-ci.
struct StepsBadge: View {
    let stepsAfter: Int

    var body: some View {
        Text(text)
            .font(.sans(12, .medium))
            .foregroundStyle(DoneColor.stateActiveText)
            .padding(.horizontal, DoneSpace.s8)
            .frame(height: 22)
            .background(DoneColor.stateActiveTint, in: RoundedRectangle(cornerRadius: DoneRadius.xs, style: .continuous))
            .fixedSize()
    }

    private var text: String {
        switch stepsAfter {
        case 0: "Dernière étape"
        case 1: "Encore 1 étape après celle-ci"
        default: "Encore \(stepsAfter) étapes après celle-ci"
        }
    }
}

/// Bloqué sur une étape : elle reste ouverte, marquée bloquée, avec la raison en note de reprise,
/// et Done passe à l'étape suivante de la même tâche.
struct BlockedSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(FocusEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Bloqué")
            if let current = engine.current {
                Text(current.action.title)
                    .doneText(.displayM)
                    .foregroundStyle(DoneColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, DoneSpace.s8)
                Text("Elle reste dans sa liste, marquée bloquée, et Done ne la propose plus. Quand c'est réglé, débloque-la depuis sa liste : ta raison s'affichera pour reprendre.")
                    .doneText(.body)
                    .foregroundStyle(DoneColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, DoneSpace.s6)
                TextField("Ce qui bloque, en une ligne", text: $reason)
                    .focused($focused)
                    .doneField(focused: focused)
                    .padding(.top, DoneSpace.s20)
                HStack(alignment: .firstTextBaseline, spacing: DoneSpace.s8) {
                    Eyebrow(text: "Ensuite")
                    Text(nextText(current))
                        .doneText(.body)
                        .foregroundStyle(DoneColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, DoneSpace.s16)
                HStack(spacing: DoneSpace.s8) {
                    Button("Annuler") { dismiss() }
                        .buttonStyle(DoneButtonStyle(kind: .plain))
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Laisser ouverte et passer à la suite", action: submit)
                        .buttonStyle(DoneButtonStyle(kind: .primary))
                        .keyboardShortcut(.defaultAction)
                        .disabled(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.top, DoneSpace.s24)
            }
        }
        .padding(DoneSpace.s24)
        .frame(width: 520)
        .background(DoneColor.bgCanvas)
        .onAppear { focused = true }
    }

    private func nextText(_ current: FocusEngine.Current) -> String {
        let pause = "\(engine.breakMinutesAfterSession) min de pause"
        switch Planner.followUp(blocking: current.action, root: current.root, in: model.index, rules: model.rules) {
        case .step(let next) where engine.remaining >= Rules.minChainSeconds:
            return "« \(next.title) », dans le temps qui reste (\(Format.clock(engine.remaining)))."
        case .step(let next):
            return "\(pause), puis « \(next.title) »."
        case .closeRoot, .switchTask:
            guard current.action.id != current.root.id else { return "\(pause), puis la tâche suivante du plan." }
            return "Plus d'étape ouverte dans « \(current.root.title) » : \(pause), puis la tâche suivante du plan."
        }
    }

    private func submit() {
        engine.markBlocked(reason: reason)
        dismiss()
    }
}

/// Pause : fond pomodoro.breakBg (posé par RootView) et anneau de pause. Entre deux tâches
/// principales, elle ne se passe pas.
struct BreakView: View {
    @Environment(AppModel.self) private var model
    @Environment(FocusEngine.self) private var engine

    var body: some View {
        VStack(spacing: 0) {
            Eyebrow(text: engine.breakIsMandatory ? "Pause avant la tâche suivante" : "Pause")
            ZStack {
                ProgressRing(fraction: engine.breakRemainingFraction, color: DoneColor.pomodoroBreak)
                VStack(spacing: DoneSpace.s4) {
                    TimerText(text: Format.clock(engine.breakRemaining))
                    Text("sur \(Int((engine.breakDuration / 60).rounded())) min")
                        .doneText(.callout)
                        .foregroundStyle(DoneColor.textSecondary)
                }
            }
            .frame(width: 280, height: 280)
            .padding(.top, DoneSpace.s24)
            Text("Lève-toi, bois de l'eau, regarde loin de l'écran.")
                .doneText(.title)
                .foregroundStyle(DoneColor.textPrimary)
                .padding(.top, DoneSpace.s32)
            if let next = nextUp {
                Text("Ensuite : \(next)")
                    .doneText(.body)
                    .foregroundStyle(DoneColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: 520)
                    .padding(.top, DoneSpace.s8)
            }
            if engine.breakIsMandatory {
                Text("Tu changes de tâche : la pause va jusqu'au bout.")
                    .doneText(.callout)
                    .foregroundStyle(DoneColor.textSecondary)
                    .padding(.top, DoneSpace.s24)
            } else {
                Button("Passer la pause") { engine.skipBreak() }
                    .buttonStyle(DoneButtonStyle())
                    .padding(.top, DoneSpace.s24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Prochaine action du plan, pour savoir où l'on repart.
    private var nextUp: String? {
        let suggestion = Planner.suggest(plan: model.planIDs, index: model.index, meetings: model.meetingsToday, rules: model.rules, now: engine.now)
        guard suggestion.status == .ready, let action = suggestion.action else { return nil }
        guard let root = suggestion.planTask, root.id != action.id else { return "« \(action.title) »" }
        return "« \(action.title) » · \(root.title)"
    }
}
