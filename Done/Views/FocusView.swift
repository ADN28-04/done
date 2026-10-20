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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Largeur des cartes de l'écran Focus.
let focusCardWidth: CGFloat = 560

/// Tâche du plan avec sa position, pour les listes numérotées.
struct NumberedTask: Identifiable {
    let position: Int
    let task: TodoistTask
    var id: String { task.id }
}

/// Proposition : la prochaine action du plan et sa durée.
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
            ScrollView {
                VStack(spacing: 16) {
                    if model.isReviewDue {
                        ReviewBanner { showReview = true }
                    }
                    MeetingBanner(suggestion: suggestion)
                    switch suggestion.status {
                    case .planEmpty:
                        planEmpty
                    case .allBlocked:
                        allBlocked
                    case .noTimeBeforeMeeting:
                        noTime(suggestion)
                    case .ready:
                        ready(suggestion)
                        upNext(suggestion)
                    }
                }
                .frame(width: focusCardWidth)
                .padding(.top, 40)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
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
            VStack(alignment: .leading, spacing: 0) {
                Eyebrow(text: caption(suggestion, root: root))
                if action.id != root.id {
                    Text(root.content)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.label2)
                        .padding(.top, 16)
                }
                Text(action.content)
                    .font(.system(size: 30, weight: .semibold))
                    .tracking(-0.3)
                    .lineSpacing(2)
                    .foregroundStyle(Theme.label)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, action.id != root.id ? 4 : 16)
                if !action.description.isEmpty {
                    Text(action.description)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.label2)
                        .lineLimit(3)
                        .padding(.top, 8)
                }
                if Planner.needsBreakdown(action: action, root: root, in: model.index) {
                    BreakdownHint { breakdownTask = root }
                        .padding(.top, 20)
                }
                if let note = suggestion.note {
                    Text(note)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.orangeText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Theme.orangeTint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .padding(.top, 20)
                }
                HStack(spacing: 8) {
                    Text("Durée")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.label2)
                    Picker("Durée", selection: Binding(
                        get: { minutes },
                        set: { customMinutes = MinutesOverride(taskID: action.id, minutes: $0) }
                    )) {
                        ForEach(durationOptions(including: minutes), id: \.self) { value in
                            Text("\(value) min").tag(value)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }
                .padding(.top, 24)
                Hairline()
                    .padding(.top, 24)
                HStack(spacing: 8) {
                    Button("Changer de tâche") { showPicker = true }
                        .buttonStyle(PillButtonStyle())
                    if suggestion.position > 0 {
                        Button("Passer") { model.skip(root.id) }
                            .buttonStyle(PillButtonStyle())
                            .help("Mettre cette tâche en fin de plan")
                    }
                    Spacer()
                    Button {
                        engine.start(action: action, root: root, minutes: minutes)
                    } label: {
                        ShortcutLabel(title: "Démarrer", hint: "↩")
                    }
                    .buttonStyle(PillButtonStyle(kind: .primary))
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.top, 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
    }

    @ViewBuilder
    private func upNext(_ suggestion: Suggestion) -> some View {
        let rest = model.planIDs.enumerated().compactMap { offset, id -> NumberedTask? in
            guard let task = model.index[id], task.id != suggestion.planTask?.id else { return nil }
            return NumberedTask(position: offset + 1, task: task)
        }
        if !rest.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(text: "Ensuite")
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
                ForEach(rest) { item in
                    let task = item.task
                    HStack(spacing: 12) {
                        Text("\(item.position)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(Theme.label2)
                            .frame(width: 12, alignment: .trailing)
                        PriorityBadge(task: task)
                        Text(task.content)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.label)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(meta(task))
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.label2)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
            }
            .padding(.top, 12)
        }
    }

    // MARK: Autres états

    private var planEmpty: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Aucun plan")
            Text("Pas encore de plan pour aujourd'hui")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.label)
                .padding(.top, 16)
            Text("Choisis tes \(Rules.recommendedPlanSize) tâches les plus importantes. Ça prend moins de deux minutes.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.label2)
                .padding(.top, 6)
            Hairline().padding(.top, 24)
            HStack {
                Spacer()
                Button("Préparer le plan", action: openPlan)
                    .buttonStyle(PillButtonStyle(kind: .primary))
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var allBlocked: some View {
        let tasks = model.planIDs.compactMap { model.index[$0] }
        return VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Plan en attente")
            Text("Tout ton plan dépend de quelqu'un d'autre")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.label)
                .padding(.top, 16)
            Text("Aucune des \(tasks.count) tâches ne peut avancer pour l'instant.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.label2)
                .padding(.top, 6)
            VStack(spacing: 0) {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { offset, task in
                    HStack(spacing: 12) {
                        Text("\(offset + 1)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(Theme.label2)
                            .frame(width: 12, alignment: .trailing)
                        PriorityBadge(task: task)
                        Text(task.content)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.label2)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text("En attente")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.label2)
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(.top, 16)
            Hairline().padding(.top, 16)
            HStack {
                Button("Faire une pause") { engine.takeBreak(minutes: model.rules.shortBreakMinutes) }
                    .buttonStyle(PillButtonStyle())
                Spacer()
                Button("Revoir le plan", action: openPlan)
                    .buttonStyle(PillButtonStyle(kind: .primary))
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    @ViewBuilder
    private func noTime(_ suggestion: Suggestion) -> some View {
        let available = suggestion.minutesBeforeMeeting ?? 0
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Réunion à venir")
            if let meeting = suggestion.nextMeeting {
                Text("\(meeting.title) commence à \(Format.time(meeting.start))")
                    .font(.system(size: 30, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundStyle(Theme.label)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 16)
            }
            Text("Il reste \(Format.minutes(Double(available)))")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.orangeText)
                .padding(.top, 12)
            Text("Aucune tâche du plan ne tient dans ce temps.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.label2)
                .padding(.top, 4)
            Hairline().padding(.top, 24)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    noTimeSecondaryButtons(available)
                    Spacer(minLength: 8)
                    preparationButton(suggestion, available: available)
                }
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) { noTimeSecondaryButtons(available) }
                    preparationButton(suggestion, available: available)
                }
            }
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    @ViewBuilder
    private func noTimeSecondaryButtons(_ available: Int) -> some View {
        Button("Ignorer la réunion") { ignoreMeetings = true }
            .buttonStyle(PillButtonStyle(kind: .plain))
        Button("Faire une pause") { engine.takeBreak(minutes: max(1, available)) }
            .buttonStyle(PillButtonStyle())
    }

    @ViewBuilder
    private func preparationButton(_ suggestion: Suggestion, available: Int) -> some View {
        if let preparation = suggestion.preparation {
            Button(preparation.content) {
                engine.start(action: preparation, root: model.index.root(of: preparation), minutes: max(5, available))
            }
            .buttonStyle(PillButtonStyle(kind: .primary))
            .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: Aides

    private func caption(_ suggestion: Suggestion, root: TodoistTask) -> String {
        let project = model.projectName(for: root)
        guard suggestion.position > 0 else { return "Hors plan · \(project)" }
        return "Tâche \(suggestion.position) sur \(suggestion.planCount) · \(project)"
    }

    private func meta(_ task: TodoistTask) -> String {
        ([model.projectName(for: task)] + task.labels.map { "@\($0)" })
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private func durationOptions(including minutes: Int) -> [Int] {
        Array(Set([5, 10, 15, 20, 25, 30, 40, 45, 50, 60, 75, 90, minutes])).sorted()
    }
}

/// Bandeau au-dessus de la carte : bloc de travail, réunion en cours ou prochaine réunion.
struct MeetingBanner: View {
    var ongoing: Meeting?
    var next: Meeting?
    var minutesBeforeMeeting: Int?

    init(ongoing: Meeting?, next: Meeting? = nil, minutesBeforeMeeting: Int? = nil) {
        self.ongoing = ongoing
        self.next = next
        self.minutesBeforeMeeting = minutesBeforeMeeting
    }

    init(suggestion: Suggestion) {
        self.init(ongoing: suggestion.ongoing, next: suggestion.nextMeeting, minutesBeforeMeeting: suggestion.minutesBeforeMeeting)
    }

    var body: some View {
        if let ongoing {
            if ongoing.isFocusBlock {
                banner(
                    Text("Bloc \(ongoing.title) jusqu'à \(Format.time(ongoing.end))"),
                    color: Theme.accentText, dot: Theme.accent, background: Theme.accentTint
                )
            } else {
                banner(
                    Text("Réunion en cours… jusqu'à \(Format.time(ongoing.end))"),
                    color: Theme.label, dot: Theme.label2, background: Theme.fill
                )
            }
        } else if let next, let minutes = minutesBeforeMeeting {
            HStack(spacing: 10) {
                Circle()
                    .strokeBorder(Theme.label2, lineWidth: 1.5)
                    .frame(width: 8, height: 8)
                Text("Prochaine réunion : \(Text(next.title).foregroundStyle(Theme.label)) à \(Format.time(next.start)), dans \(Format.minutes(Double(minutes)))")
                    .foregroundStyle(Theme.label2)
            }
            .font(.system(size: 13))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    private func banner(_ content: Text, color: Color, dot: Color, background: Color) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(dot)
                .frame(width: 8, height: 8)
            content
                .foregroundStyle(color)
        }
        .font(.system(size: 13))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
