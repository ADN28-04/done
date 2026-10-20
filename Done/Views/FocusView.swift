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
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Proposition : la prochaine action du plan et sa durée.
struct SuggestionView: View {
    @Environment(AppModel.self) private var model
    @Environment(FocusEngine.self) private var engine
    var openPlan: () -> Void

    @State private var ignoreMeetings = false
    @State private var customMinutes: MinutesOverride?
    @State private var showPicker = false

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
            VStack(spacing: 20) {
                MeetingBanner(suggestion: suggestion)
                switch suggestion.status {
                case .planEmpty:
                    ContentUnavailableView {
                        Label("Pas encore de plan aujourd'hui", systemImage: "list.number")
                    } description: {
                        Text("Choisis tes trois tâches les plus importantes pour commencer.")
                    } actions: {
                        Button("Préparer mon plan", action: openPlan)
                            .buttonStyle(.borderedProminent)
                    }
                case .allBlocked:
                    ContentUnavailableView {
                        Label("Tout est en attente", systemImage: "hourglass")
                    } description: {
                        Text("Tout ce qui reste dans le plan porte @\(Rules.waitingLabel). Ajoute une tâche faisable maintenant.")
                    } actions: {
                        Button("Modifier le plan", action: openPlan)
                        Button("Choisir une tâche…") { showPicker = true }
                    }
                case .noTimeBeforeMeeting:
                    noTime(suggestion)
                case .ready:
                    ready(suggestion)
                    upNext(suggestion)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: 680)
        }
        .sheet(isPresented: $showPicker) {
            TaskPickerView(title: "Changer de tâche") { model.putFirst($0.id) }
                .environment(model)
        }
    }

    @ViewBuilder
    private func ready(_ suggestion: Suggestion) -> some View {
        if let action = suggestion.action, let root = suggestion.planTask {
            let minutes = customMinutes.flatMap { $0.taskID == action.id ? $0.minutes : nil } ?? suggestion.minutes
            VStack(alignment: .leading, spacing: 14) {
                Text(caption(suggestion, root: root))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                if action.id != root.id {
                    Text(root.content)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                Text(action.content)
                    .font(.system(size: 30, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if !action.description.isEmpty {
                    Text(action.description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
                if let note = suggestion.note {
                    Label(note, systemImage: "clock.badge.exclamationmark")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
                HStack(spacing: 12) {
                    Stepper(value: Binding(
                        get: { minutes },
                        set: { customMinutes = MinutesOverride(taskID: action.id, minutes: $0) }
                    ), in: 5...120, step: 5) {
                        Text("\(minutes) min").font(.title3.monospacedDigit())
                    }
                    .fixedSize()
                    Spacer()
                    Button("Changer de tâche") { showPicker = true }
                    if suggestion.position > 0 {
                        Button("Passer") { model.skip(root.id) }
                            .help("Mettre cette tâche en fin de plan")
                    }
                    Button {
                        engine.start(action: action, root: root, minutes: minutes)
                    } label: {
                        Label("Démarrer", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    @ViewBuilder
    private func upNext(_ suggestion: Suggestion) -> some View {
        let rest = model.planIDs.compactMap { model.index[$0] }.filter { $0.id != suggestion.planTask?.id }
        if !rest.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Ensuite").font(.caption.weight(.medium)).foregroundStyle(.secondary).textCase(.uppercase)
                ForEach(rest) { task in
                    Text(task.content)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    private func noTime(_ suggestion: Suggestion) -> some View {
        let available = suggestion.minutesBeforeMeeting ?? 0
        VStack(spacing: 14) {
            Image(systemName: "person.2")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            if let meeting = suggestion.nextMeeting {
                Text("« \(meeting.title) » commence à \(Format.time(meeting.start))")
                    .font(.title2)
                    .multilineTextAlignment(.center)
            }
            Text("Il reste \(Format.minutes(Double(available))) : pas assez pour une tâche du plan. Prépare la réunion ou fais une pause.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack {
                if let preparation = suggestion.preparation {
                    Button("Préparer : \(preparation.content)") {
                        engine.start(action: preparation, root: model.index.root(of: preparation), minutes: max(5, available))
                    }
                    .buttonStyle(.borderedProminent)
                }
                Button("Faire une pause") { engine.takeBreak(minutes: max(1, available)) }
                Button("Ignorer la réunion") { ignoreMeetings = true }
            }
            .controlSize(.large)
        }
        .padding(.top, 40)
    }

    private func caption(_ suggestion: Suggestion, root: TodoistTask) -> String {
        let project = model.projectName(for: root)
        guard suggestion.position > 0 else { return "Hors plan · \(project)" }
        return "Tâche \(suggestion.position) sur \(suggestion.planCount) · \(project)"
    }
}

struct MeetingBanner: View {
    let suggestion: Suggestion

    var body: some View {
        if let ongoing = suggestion.ongoing {
            banner(
                ongoing.isFocusBlock
                    ? "Bloc « \(ongoing.title) » jusqu'à \(Format.time(ongoing.end))"
                    : "Réunion en cours : \(ongoing.title), jusqu'à \(Format.time(ongoing.end))",
                symbol: ongoing.isFocusBlock ? "brain.head.profile" : "person.2.fill",
                tint: ongoing.isFocusBlock ? .accentColor : .orange
            )
        } else if let next = suggestion.nextMeeting, let minutes = suggestion.minutesBeforeMeeting {
            banner(
                "Prochaine réunion : \(next.title) à \(Format.time(next.start)), dans \(Format.minutes(Double(minutes)))",
                symbol: "calendar",
                tint: .secondary
            )
        }
    }

    private func banner(_ text: String, symbol: String, tint: Color) -> some View {
        Label(text, systemImage: symbol)
            .font(.callout)
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(tint.opacity(0.1), in: Capsule())
    }
}
