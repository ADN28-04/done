import SwiftUI

/// Écran principal : une seule chose à la fois.
struct FocusView: View {
    @Environment(AppModel.self) private var model
    @Environment(FocusEngine.self) private var engine
    var openPlan: () -> Void
    var openTasks: () -> Void
    @State private var showBlocked = false

    var body: some View {
        Group {
            switch engine.phase {
            case .idle:
                SuggestionView(openPlan: openPlan, openTasks: openTasks)
            case .focusing, .paused:
                SessionView { showBlocked = true }
            case .interrupted(let reason):
                InterruptionView(reason: reason)
            case .awaitingOutcome:
                OutcomeView { showBlocked = true }
            case .onBreak:
                BreakView()
            }
        }
        .padding(.horizontal, 48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Ici plutôt que sur l'écran de session : la feuille reste ouverte si le minuteur sonne pendant la saisie.
        .sheet(isPresented: $showBlocked) {
            BlockedSheet()
                .environment(model)
                .environment(engine)
        }
    }
}

/// Proposition : la prochaine action du plan et sa durée, au centre de la fenêtre.
struct SuggestionView: View {
    @Environment(AppModel.self) private var model
    @Environment(FocusEngine.self) private var engine
    var openPlan: () -> Void
    var openTasks: () -> Void

    @State private var ignoreMeetings = false
    @State private var customMinutes: MinutesOverride?
    @State private var showPicker = false
    @State private var breakdownTask: TodoTask?
    @State private var showReview = false
    /// Jour d'absence : on peut quand même demander une tâche.
    @State private var workAnyway = false

    private struct MinutesOverride {
        let taskID: String
        let minutes: Int
    }

    var body: some View {
        // Recalcule toutes les 30 s pour suivre l'heure de la prochaine réunion.
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let suggestion = Planner.suggest(
                plan: model.planIDs,
                index: model.index,
                meetings: model.meetingsToday,
                rules: model.rules,
                now: context.date,
                ignoreMeetings: ignoreMeetings
            )
            VStack(spacing: 0) {
                Spacer(minLength: 16)
                if model.isReviewDue {
                    ReviewPrompt { showReview = true }
                        .padding(.bottom, DoneSpace.s32)
                }
                if let absence = model.absence(on: context.date), !workAnyway {
                    absent(absence)
                } else {
                    switch suggestion.status {
                    case .planEmpty:
                        planEmpty
                    case .allBlocked:
                        allBlocked
                    case .noTimeBeforeMeeting:
                        noTime(suggestion)
                    case .ready:
                        ready(suggestion, now: context.date)
                    }
                }
                Spacer(minLength: 16)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showPicker) {
            TaskPickerView(title: "Changer de tâche") { model.putFirst($0.id) }
                .environment(model)
        }
        .sheet(item: $breakdownTask) { task in
            BreakdownSheet(task: task)
                .environment(model)
        }
        .sheet(isPresented: $showReview) {
            ReviewSheet()
                .environment(model)
                .modelContext(model.context)
        }
    }

    // MARK: Absence

    /// Congé ou férié, marqué dans le calendrier : Done ne propose rien.
    private func absent(_ absence: Absence) -> some View {
        VStack(spacing: 0) {
            Eyebrow(text: "Jour d'absence")
            Text(absence.title)
                .doneText(.displayXL)
                .foregroundStyle(DoneColor.textPrimary)
                .padding(.top, DoneSpace.s12)
            Text("Done ne propose rien aujourd'hui.")
                .doneText(.body)
                .foregroundStyle(DoneColor.textSecondary)
                .padding(.top, DoneSpace.s8)
            Button("Travailler quand même") { workAnyway = true }
                .buttonStyle(DoneButtonStyle())
                .padding(.top, DoneSpace.s24)
        }
    }

    // MARK: Prêt

    @ViewBuilder
    private func ready(_ suggestion: Suggestion, now: Date) -> some View {
        if let action = suggestion.action, let root = suggestion.planTask {
            let minutes = customMinutes.flatMap { $0.taskID == action.id ? $0.minutes : nil } ?? suggestion.minutes
            let canBreakDown = Planner.canBreakDown(action: action, root: root)
            let invitesBreakdown = Planner.needsBreakdown(action: action, root: root, in: model.index)
            VStack(spacing: 0) {
                HStack(spacing: DoneSpace.s12) {
                    PlanDots(position: suggestion.position, count: suggestion.planCount)
                    Text(caption(suggestion, root: root))
                        .doneText(.callout)
                        .foregroundStyle(DoneColor.textSecondary)
                }
                if action.id != root.id {
                    Text(root.title)
                        .doneText(.title)
                        .foregroundStyle(DoneColor.textSecondary)
                        .padding(.top, DoneSpace.s16)
                }
                Text(action.title)
                    .doneText(.displayXL)
                    .foregroundStyle(DoneColor.textPrimary)
                    .frame(maxWidth: 680)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, action.id != root.id ? DoneSpace.s6 : DoneSpace.s20)
                TaskChips(task: action)
                    .padding(.top, DoneSpace.s12)
                if let resume = model.resumeNote(for: action.id) {
                    ResumeNoteCard(note: resume)
                        .padding(.top, DoneSpace.s20)
                }
                if let note = suggestion.note {
                    NoticeBox(text: note)
                        .frame(maxWidth: 520)
                        .padding(.top, DoneSpace.s20)
                }
                // Nouvelle tâche principale juste après une session : la pause passe d'abord.
                let pause = engine.needsBreak(before: root, now: now) ? engine.breakDue?.remainingMinutes(now: now) : nil
                if let pause {
                    Text("Tu changes de tâche : \(pause) min de pause d'abord.")
                        .doneText(.bodyStrong)
                        .foregroundStyle(DoneColor.stateActiveText)
                        .padding(.top, DoneSpace.s24)
                }
                HStack(spacing: DoneSpace.s8) {
                    if let pause {
                        Button("Démarrer la pause · \(pause) min") {
                            engine.takeBreak(minutes: pause, mandatory: true)
                        }
                        .buttonStyle(DoneButtonStyle(kind: .primary))
                        .keyboardShortcut(.defaultAction)
                    } else {
                        Button("Démarrer · \(minutes) min") {
                            engine.start(action: action, root: root, minutes: minutes)
                        }
                        .buttonStyle(DoneButtonStyle(kind: .primary))
                        .keyboardShortcut(.defaultAction)
                    }
                    Button("Changer de tâche") { showPicker = true }
                        .buttonStyle(DoneButtonStyle())
                }
                .padding(.top, pause == nil ? DoneSpace.s32 : DoneSpace.s12)
                HStack(spacing: DoneSpace.s2) {
                    Menu {
                        ForEach(durationOptions(including: minutes), id: \.self) { value in
                            Button("\(value) min") {
                                customMinutes = MinutesOverride(taskID: action.id, minutes: value)
                            }
                        }
                    } label: {
                        Text("Durée : \(minutes) min")
                            .font(.sans(14, .medium))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .padding(.horizontal, DoneSpace.s8)
                    if suggestion.position > 0 {
                        Button("Passer") { model.skip(root.id) }
                            .buttonStyle(DoneButtonStyle(kind: .plain))
                            .help("Mettre cette tâche en fin de plan")
                    }
                    if canBreakDown {
                        // Découpe l'action proposée : la nouvelle étape devient la prochaine action.
                        Button(breakdownTitle(invites: invitesBreakdown)) { breakdownTask = action }
                            .buttonStyle(DoneButtonStyle(kind: .plain))
                            .help(invitesBreakdown ? "Cette tâche n'a pas encore de sous-tâche" : "Ajouter une étape plus petite sous cette action")
                    }
                }
                .doneText(.callout)
                .foregroundStyle(DoneColor.textSecondary)
                .padding(.top, DoneSpace.s12)
            }
        }
    }

    private func breakdownTitle(invites: Bool) -> String {
        invites ? "Découper en étapes…" : "Découper…"
    }

    // MARK: Autres états

    @ViewBuilder
    private var planEmpty: some View {
        if model.index.all.isEmpty {
            noTasks
        } else {
            noPlan
        }
    }

    /// Premier lancement, ou tout est fait : il n'y a rien à planifier.
    private var noTasks: some View {
        VStack(spacing: 0) {
            Eyebrow(text: "Aucune tâche")
            Text("Ta liste est vide")
                .doneText(.displayL)
                .padding(.top, DoneSpace.s16)
            Text("Note ce que tu as à faire, puis choisis par quoi commencer. ⌘N ajoute une tâche depuis n'importe quel écran.")
                .doneText(.body)
                .foregroundStyle(DoneColor.textSecondary)
                .frame(maxWidth: 520)
                .padding(.top, DoneSpace.s8)
            Button("Ajouter des tâches", action: openTasks)
                .buttonStyle(DoneButtonStyle(kind: .primary))
                .keyboardShortcut(.defaultAction)
                .padding(.top, DoneSpace.s32)
        }
    }

    private var noPlan: some View {
        VStack(spacing: 0) {
            Eyebrow(text: "Aucun plan")
            Text("Pas encore de plan pour aujourd'hui")
                .doneText(.displayL)
                .padding(.top, DoneSpace.s16)
            Text("Choisis tes \(model.rules.planSize) tâches les plus importantes. Ça prend moins de deux minutes.")
                .doneText(.body)
                .foregroundStyle(DoneColor.textSecondary)
                .frame(maxWidth: 520)
                .padding(.top, DoneSpace.s8)
            Button("Préparer le plan", action: openPlan)
                .buttonStyle(DoneButtonStyle(kind: .primary))
                .keyboardShortcut(.defaultAction)
                .padding(.top, DoneSpace.s32)
        }
    }

    private var allBlocked: some View {
        let tasks = model.planIDs.compactMap { model.index[$0] }
        return VStack(spacing: 0) {
            Eyebrow(text: "Plan en attente")
            Text("Ton plan est bloqué pour l'instant")
                .doneText(.displayL)
                .frame(maxWidth: 640)
                .padding(.top, DoneSpace.s16)
            Text(tasks.count > 1 ? "Aucune des \(tasks.count) tâches ne peut avancer pour l'instant." : "Cette tâche ne peut pas avancer pour l'instant.")
                .doneText(.body)
                .foregroundStyle(DoneColor.textSecondary)
                .padding(.top, DoneSpace.s8)
            VStack(spacing: 0) {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { offset, task in
                    HStack(spacing: DoneSpace.s12) {
                        NumberTile(position: offset + 1, isFilled: false)
                        Text(task.title)
                            .doneText(.bodyStrong)
                            .foregroundStyle(DoneColor.textPrimary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        StateChip(kind: .blocked, title: blockedReason(task))
                    }
                    .padding(.horizontal, DoneSpace.s12)
                    .frame(minHeight: 48)
                }
            }
            .padding(DoneSpace.s6)
            .doneCard(radius: DoneRadius.lg)
            .frame(maxWidth: 520)
            .padding(.top, DoneSpace.s24)
            HStack(spacing: DoneSpace.s8) {
                Button("Faire une pause") { engine.takeBreak(minutes: model.rules.shortBreakMinutes) }
                    .buttonStyle(DoneButtonStyle())
                Button("Revoir le plan", action: openPlan)
                    .buttonStyle(DoneButtonStyle(kind: .primary))
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, DoneSpace.s32)
        }
    }

    /// Étapes bloquées, ou suite datée plus tard.
    private func blockedReason(_ task: TodoTask) -> String {
        if let day = Planner.resumeDay(of: task, in: model.index, rules: model.rules) {
            return "Prévue le \(Format.day(day))"
        }
        return "Bloquée"
    }

    @ViewBuilder
    private func noTime(_ suggestion: Suggestion) -> some View {
        let available = suggestion.minutesBeforeMeeting ?? 0
        VStack(spacing: 0) {
            Eyebrow(text: "Réunion à venir")
            if let meeting = suggestion.nextMeeting {
                Text("\(meeting.title) commence à \(Format.time(meeting.start))")
                    .doneText(.displayL)
                    .frame(maxWidth: 640)
                    .padding(.top, DoneSpace.s16)
            }
            Text("Il reste \(Format.minutes(Double(available)))")
                .doneText(.title)
                .foregroundStyle(DoneColor.stateActiveText)
                .padding(.top, DoneSpace.s12)
            Text("Aucune tâche du plan ne tient dans ce temps.")
                .doneText(.body)
                .foregroundStyle(DoneColor.textSecondary)
                .padding(.top, DoneSpace.s6)
            HStack(spacing: DoneSpace.s8) {
                if let preparation = suggestion.preparation {
                    Button(preparation.title) {
                        engine.start(action: preparation, root: model.index.root(of: preparation), minutes: max(5, available))
                    }
                    .buttonStyle(DoneButtonStyle(kind: .primary))
                    .keyboardShortcut(.defaultAction)
                }
                Button("Faire une pause") { engine.takeBreak(minutes: max(1, available)) }
                    .buttonStyle(DoneButtonStyle())
            }
            .padding(.top, DoneSpace.s32)
            Button("Ignorer la réunion") { ignoreMeetings = true }
                .buttonStyle(DoneButtonStyle(kind: .plain))
                .padding(.top, DoneSpace.s8)
        }
    }

    // MARK: Aides

    private func caption(_ suggestion: Suggestion, root: TodoTask) -> String {
        let project = model.listName(for: root)
        guard suggestion.position > 0 else { return "Hors plan · \(project)" }
        return "\(suggestion.position) sur \(suggestion.planCount) · \(project)"
    }

    private func durationOptions(including minutes: Int) -> [Int] {
        Array(Set([5, 10, 15, 20, 25, 30, 40, 45, 50, 60, 75, 90, minutes])).sorted()
    }
}

/// Position dans le plan, à la manière du cycle pomodoro : un segment par tâche,
/// pleins jusqu'à la tâche en cours.
struct PlanDots: View {
    let position: Int
    let count: Int

    var body: some View {
        HStack(spacing: DoneSpace.s4) {
            ForEach(1...max(count, 1), id: \.self) { index in
                Capsule()
                    .fill(index <= position ? DoneColor.stateActive : DoneColor.pomodoroTrack)
                    .frame(width: 22, height: 6)
            }
        }
    }
}

/// Invitation au bilan du soir, en haut de l'écran Focus.
struct ReviewPrompt: View {
    let action: () -> Void

    var body: some View {
        HStack(spacing: DoneSpace.s12) {
            Image(systemName: "moon.stars")
                .foregroundStyle(DoneColor.stateActiveText)
            Text("C'est l'heure du bilan du soir")
                .doneText(.callout)
                .foregroundStyle(DoneColor.textPrimary)
            Button("Faire le bilan", action: action)
                .buttonStyle(DoneButtonStyle(compact: true))
        }
        .padding(.leading, DoneSpace.s12)
        .padding(.trailing, DoneSpace.s4)
        .frame(height: 36)
        .background(DoneColor.stateActiveTint, in: RoundedRectangle(cornerRadius: DoneRadius.sm, style: .continuous))
    }
}
