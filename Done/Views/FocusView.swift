import SwiftUI

/// Écran principal : une seule chose à la fois.
struct FocusView: View {
    @Environment(FocusEngine.self) private var engine
    var openPlan: () -> Void

    var body: some View {
        Group {
            switch engine.phase {
            case .idle:
                SuggestionView(openPlan: openPlan)
            case .focusing, .paused:
                SessionView()
            case .interrupted(let reason):
                InterruptionView(reason: reason)
            case .awaitingOutcome:
                OutcomeView()
            case .onBreak:
                BreakView()
            }
        }
        .padding(.horizontal, 48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Proposition : la prochaine action du plan et sa durée, au centre de la fenêtre.
struct SuggestionView: View {
    @Environment(AppModel.self) private var model
    @Environment(FocusEngine.self) private var engine
    var openPlan: () -> Void

    @State private var ignoreMeetings = false
    @State private var customMinutes: MinutesOverride?
    @State private var showPicker = false
    @State private var breakdownTask: TodoistTask?
    @State private var showReview = false

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
                        .padding(.bottom, 32)
                }
                switch suggestion.status {
                case .planEmpty:
                    planEmpty
                case .allBlocked:
                    allBlocked
                case .noTimeBeforeMeeting:
                    noTime(suggestion)
                case .ready:
                    ready(suggestion)
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

    // MARK: Prêt

    @ViewBuilder
    private func ready(_ suggestion: Suggestion) -> some View {
        if let action = suggestion.action, let root = suggestion.planTask {
            let minutes = customMinutes.flatMap { $0.taskID == action.id ? $0.minutes : nil } ?? suggestion.minutes
            let canBreakDown = Planner.needsBreakdown(action: action, root: root, in: model.index)
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    PlanDots(position: suggestion.position, count: suggestion.planCount)
                    Text(caption(suggestion, root: root))
                        .font(.text(13))
                        .foregroundStyle(Theme.label2)
                }
                if action.id != root.id {
                    Text(root.content)
                        .font(.text(15))
                        .foregroundStyle(Theme.label2)
                        .padding(.top, 16)
                }
                Text(action.content)
                    .font(.display(42))
                    .tracking(-0.63)
                    .lineSpacing(4)
                    .frame(maxWidth: 680)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, action.id != root.id ? 6 : 20)
                if let note = suggestion.note {
                    NoticeBox(text: note)
                        .frame(maxWidth: 520)
                        .padding(.top, 20)
                }
                HStack(spacing: 10) {
                    Button("Démarrer · \(minutes) min") {
                        engine.start(action: action, root: root, minutes: minutes)
                    }
                    .buttonStyle(PillButtonStyle(kind: .primary))
                    .keyboardShortcut(.defaultAction)
                    Button("Changer de tâche") { showPicker = true }
                        .buttonStyle(PillButtonStyle())
                }
                .padding(.top, 40)
                HStack(spacing: 2) {
                    Menu {
                        ForEach(durationOptions(including: minutes), id: \.self) { value in
                            Button("\(value) min") {
                                customMinutes = MinutesOverride(taskID: action.id, minutes: value)
                            }
                        }
                    } label: {
                        Text("Durée : \(minutes) min")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .padding(.horizontal, 12)
                    if suggestion.position > 0 {
                        Button("Passer") { model.skip(root.id) }
                            .buttonStyle(PillButtonStyle(kind: .plain, size: .small))
                            .help("Mettre cette tâche en fin de plan")
                    }
                    if canBreakDown {
                        Button("Découper en une première action…") { breakdownTask = root }
                            .buttonStyle(PillButtonStyle(kind: .plain, size: .small))
                            .help("Cette tâche n'a pas encore de sous-tâche")
                    }
                }
                .font(.text(13))
                .foregroundStyle(Theme.label2)
                .padding(.top, 12)
            }
        }
    }

    // MARK: Autres états

    private var planEmpty: some View {
        VStack(spacing: 0) {
            Eyebrow(text: "Aucun plan")
            Text("Pas encore de plan pour aujourd'hui")
                .font(.display(36))
                .tracking(-0.54)
                .padding(.top, 16)
            Text("Choisis tes \(model.rules.planSize) tâches les plus importantes. Ça prend moins de deux minutes.")
                .font(.text(15))
                .foregroundStyle(Theme.label2)
                .frame(maxWidth: 520)
                .padding(.top, 10)
            Button("Préparer le plan", action: openPlan)
                .buttonStyle(PillButtonStyle(kind: .primary))
                .keyboardShortcut(.defaultAction)
                .padding(.top, 36)
        }
    }

    private var allBlocked: some View {
        let tasks = model.planIDs.compactMap { model.index[$0] }
        return VStack(spacing: 0) {
            Eyebrow(text: "Plan en attente")
            Text("Tout ton plan dépend de quelqu'un d'autre")
                .font(.display(36))
                .tracking(-0.54)
                .frame(maxWidth: 640)
                .padding(.top, 16)
            Text("Aucune des \(tasks.count) tâches ne peut avancer pour l'instant.")
                .font(.text(15))
                .foregroundStyle(Theme.label2)
                .padding(.top, 10)
            VStack(spacing: 0) {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { offset, task in
                    HStack(spacing: 12) {
                        Text("\(offset + 1)")
                            .font(.mono(15))
                            .foregroundStyle(Theme.label3)
                            .frame(width: 16, alignment: .trailing)
                        PriorityBadge(task: task)
                        Text(task.content)
                            .font(.text(14))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("En attente")
                            .font(.text(12))
                            .foregroundStyle(Theme.label2)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                }
            }
            .padding(4)
            .surface(radius: 18)
            .frame(maxWidth: 520)
            .padding(.top, 28)
            HStack(spacing: 10) {
                Button("Faire une pause") { engine.takeBreak(minutes: model.rules.shortBreakMinutes) }
                    .buttonStyle(PillButtonStyle())
                Button("Revoir le plan", action: openPlan)
                    .buttonStyle(PillButtonStyle(kind: .primary))
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 32)
        }
    }

    @ViewBuilder
    private func noTime(_ suggestion: Suggestion) -> some View {
        let available = suggestion.minutesBeforeMeeting ?? 0
        VStack(spacing: 0) {
            Eyebrow(text: "Réunion à venir")
            if let meeting = suggestion.nextMeeting {
                Text("\(meeting.title) commence à \(Format.time(meeting.start))")
                    .font(.display(36))
                    .tracking(-0.54)
                    .frame(maxWidth: 640)
                    .padding(.top, 16)
            }
            Text("Il reste \(Format.minutes(Double(available)))")
                .font(.text(17, .semibold))
                .foregroundStyle(Theme.orangeText)
                .padding(.top, 14)
            Text("Aucune tâche du plan ne tient dans ce temps.")
                .font(.text(15))
                .foregroundStyle(Theme.label2)
                .padding(.top, 6)
            HStack(spacing: 10) {
                if let preparation = suggestion.preparation {
                    Button(preparation.content) {
                        engine.start(action: preparation, root: model.index.root(of: preparation), minutes: max(5, available))
                    }
                    .buttonStyle(PillButtonStyle(kind: .primary))
                    .keyboardShortcut(.defaultAction)
                }
                Button("Faire une pause") { engine.takeBreak(minutes: max(1, available)) }
                    .buttonStyle(PillButtonStyle())
            }
            .padding(.top, 36)
            Button("Ignorer la réunion") { ignoreMeetings = true }
                .buttonStyle(PillButtonStyle(kind: .plain, size: .small))
                .padding(.top, 10)
        }
    }

    // MARK: Aides

    private func caption(_ suggestion: Suggestion, root: TodoistTask) -> String {
        let project = model.projectName(for: root)
        guard suggestion.position > 0 else { return "Hors plan · \(project)" }
        return "\(suggestion.position) sur \(suggestion.planCount) · \(project)"
    }

    private func durationOptions(including minutes: Int) -> [Int] {
        Array(Set([5, 10, 15, 20, 25, 30, 40, 45, 50, 60, 75, 90, minutes])).sorted()
    }
}

/// Position dans le plan : un point par tâche, la tâche en cours en pastille allongée.
struct PlanDots: View {
    let position: Int
    let count: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(1...max(count, 1), id: \.self) { index in
                Capsule()
                    .fill(index <= position ? Theme.ring : Theme.track)
                    .frame(width: index == position ? 22 : 8, height: 8)
            }
        }
    }
}

/// Invitation au bilan du soir, en haut de l'écran Focus.
struct ReviewPrompt: View {
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.stars")
                .foregroundStyle(Theme.accentText)
            Text("C'est l'heure du bilan du soir")
                .font(.text(13))
            Button("Faire le bilan", action: action)
                .buttonStyle(PillButtonStyle(kind: .primary, size: .mini))
        }
        .padding(.leading, 16)
        .padding(.trailing, 4)
        .frame(height: 36)
        .glassBackground(Capsule())
    }
}
