import SwiftData
import SwiftUI

// MARK: Découpage en étapes

/// Découpe une tâche en étapes, dans l'ordre, ajoutées comme sous-tâches.
struct BreakdownSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let task: TodoTask
    var onAdded: (TodoTask) -> Void = { _ in }

    /// Une ligne de la liste. L'identifiant garde le focus sur la bonne ligne.
    private struct Step: Identifiable, Equatable {
        let id = UUID()
        var text: String
    }

    @State private var steps = [Step(text: "")]
    @FocusState private var focusedStep: UUID?

    private static let rowHeight: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Découper")
            Text("Quelles étapes pour finir cette tâche ?")
                .doneText(.displayM)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, DoneSpace.s8)
            Text(task.title)
                .doneText(.body)
                .foregroundStyle(DoneColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, DoneSpace.s6)
            stepsList
                .padding(.top, DoneSpace.s16)
            Text("Chaque étape tient en une session et commence par un verbe. Done te les propose une par une, dans cet ordre. Entrée ajoute une ligne.")
                .doneText(.caption)
                .foregroundStyle(DoneColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, DoneSpace.s8)
            HStack(spacing: DoneSpace.s8) {
                Spacer()
                Button("Annuler") { dismiss() }
                    .buttonStyle(DoneButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button(filledSteps.count > 1 ? "Ajouter \(filledSteps.count) étapes" : "Ajouter l'étape", action: save)
                    .buttonStyle(DoneButtonStyle(kind: .primary))
                    // Entrée sert à ajouter une ligne : l'ajout passe par ⌘ Entrée.
                    .keyboardShortcut(.return, modifiers: .command)
                    .help("⌘ Entrée")
                    .disabled(filledSteps.isEmpty)
            }
            .padding(.top, DoneSpace.s24)
        }
        .padding(DoneSpace.s24)
        .frame(width: 540)
        .background(DoneColor.bgCanvas)
        .onAppear { focusedStep = steps.first?.id }
    }

    private var stepsList: some View {
        VStack(alignment: .leading, spacing: DoneSpace.s8) {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { offset, step in
                        if offset > 0 {
                            Hairline().padding(.horizontal, DoneSpace.s12)
                        }
                        HStack(spacing: DoneSpace.s12) {
                            NumberTile(position: offset + 1)
                            TextField(offset == 0 ? "Ex. : lister les fiches à mettre à jour" : "Étape suivante", text: text(of: step.id))
                                .textFieldStyle(.plain)
                                .doneText(.body)
                                .focused($focusedStep, equals: step.id)
                                .onSubmit { insertStep(after: step.id) }
                            Button {
                                removeStep(step.id)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(DoneColor.textSecondary)
                                    .frame(width: 20, height: 20)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help("Retirer cette étape")
                            .opacity(steps.count > 1 ? 1 : 0)
                            .disabled(steps.count <= 1)
                        }
                        .padding(.horizontal, DoneSpace.s12)
                        .frame(height: Self.rowHeight)
                    }
                }
                .padding(4)
            }
            .scrollIndicators(.never)
            // Six lignes visibles, la liste défile au-delà.
            .frame(height: min(CGFloat(steps.count), 6) * (Self.rowHeight + 1) + 8)
            .doneCard(radius: DoneRadius.lg)
            Button {
                insertStep(after: steps.last?.id)
            } label: {
                Label("Ajouter une étape", systemImage: "plus")
            }
            .buttonStyle(DoneButtonStyle(kind: .plain, compact: true))
            .disabled(steps.count >= Rules.maxSteps)
        }
    }

    private var filledSteps: [String] {
        steps
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func text(of id: UUID) -> Binding<String> {
        Binding(
            get: { steps.first { $0.id == id }?.text ?? "" },
            set: { value in
                if let index = steps.firstIndex(where: { $0.id == id }) {
                    steps[index].text = value
                }
            }
        )
    }

    private func insertStep(after id: UUID?) {
        guard steps.count < Rules.maxSteps else { return }
        let step = Step(text: "")
        let position = id.flatMap { id in steps.firstIndex { $0.id == id } }.map { $0 + 1 } ?? steps.count
        steps.insert(step, at: position)
        focusedStep = step.id
    }

    private func removeStep(_ id: UUID) {
        steps.removeAll { $0.id == id }
        if steps.isEmpty { steps = [Step(text: "")] }
    }

    private func save() {
        let created = model.addSubtasks(filledSteps, to: task)
        if let first = created.first { onAdded(first) }
        dismiss()
    }
}

// MARK: Bilan du soir

struct ReviewSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FocusSession.startedAt) private var sessions: [FocusSession]

    @State private var decisions: [String: Review.Decision] = [:]
    @State private var breakdownTask: TodoTask?

    var body: some View {
        let today = sessions.filter { Calendar.current.isDateInToday($0.startedAt) }
        let summary = Review.summary(today.map(\.fact), on: .now)
        let checked = uniqueTitles(today.filter { $0.outcome == .done })
        let unfinished = Review.unfinished(plan: model.planIDs, index: model.index)

        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Bilan du soir")
            Text("Ta journée")
                .doneText(.displayL)
                .padding(.top, DoneSpace.s8)

            HStack(spacing: DoneSpace.s8) {
                StatTile(title: "Temps de focus", value: Format.minutes(summary.focusMinutes))
                StatTile(title: "Sessions", value: "\(summary.sessions)")
                StatTile(title: "Tâches cochées", value: "\(summary.checked)")
                StatTile(title: "Interruptions", value: "\(summary.interruptions)")
            }
            .padding(.top, DoneSpace.s16)

            ScrollView {
                VStack(alignment: .leading, spacing: DoneSpace.s20) {
                    if !checked.isEmpty {
                        VStack(alignment: .leading, spacing: DoneSpace.s8) {
                            Eyebrow(text: "Terminé aujourd'hui")
                                .padding(.leading, DoneSpace.s2)
                            VStack(alignment: .leading, spacing: DoneSpace.s8) {
                                ForEach(checked, id: \.self) { title in
                                    HStack(alignment: .firstTextBaseline, spacing: DoneSpace.s8) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(DoneColor.stateActiveText)
                                        Text(title)
                                            .doneText(.body)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, DoneSpace.s16)
                            .padding(.vertical, DoneSpace.s12)
                            .doneCard(radius: DoneRadius.lg)
                        }
                    }

                    VStack(alignment: .leading, spacing: DoneSpace.s8) {
                        Eyebrow(text: "Pas terminé")
                            .padding(.leading, DoneSpace.s2)
                        if unfinished.isEmpty {
                            Text("Tout le plan du jour est terminé.")
                                .doneText(.body)
                                .foregroundStyle(DoneColor.stateActiveText)
                                .padding(.leading, DoneSpace.s2)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(unfinished.enumerated()), id: \.element.id) { offset, task in
                                    if offset > 0 {
                                        Hairline().padding(.horizontal, DoneSpace.s12)
                                    }
                                    unfinishedRow(task)
                                }
                            }
                            .padding(6)
                            .doneCard(radius: DoneRadius.lg)
                            Text("« Demain » remet la tâche dans le plan de demain matin. « Plus tard » la laisse dans ta liste, hors du plan.")
                                .doneText(.caption)
                                .foregroundStyle(DoneColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.leading, DoneSpace.s2)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, DoneSpace.s20)
                .padding(.bottom, DoneSpace.s2)
            }
            .scrollIndicators(.never)

            HStack(spacing: DoneSpace.s8) {
                Button("Annuler") { dismiss() }
                    .buttonStyle(DoneButtonStyle(kind: .plain))
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Terminer la journée") {
                    model.completeReview(Review.carryOver(decisions, plan: unfinished.map(\.id), on: .now))
                    dismiss()
                }
                .buttonStyle(DoneButtonStyle(kind: .primary))
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, DoneSpace.s20)
        }
        .padding(DoneSpace.s24)
        .frame(width: 660, height: 620)
        .background(DoneColor.bgCanvas)
        .sheet(item: $breakdownTask) { task in
            BreakdownSheet(task: task, onAdded: { _ in decisions[task.id] = .tomorrow })
                .environment(model)
        }
    }

    private func unfinishedRow(_ task: TodoTask) -> some View {
        HStack(spacing: DoneSpace.s12) {
            TaskRowContent(task: task)
            if Planner.needsBreakdown(action: task, root: task, in: model.index) {
                Button("Découper…") { breakdownTask = task }
                    .buttonStyle(DoneButtonStyle(kind: .plain, compact: true))
            }
            DoneSegmented(
                selection: Binding(
                    get: { decisions[task.id, default: .tomorrow] },
                    set: { decisions[task.id] = $0 }
                ),
                options: Review.Decision.allCases.map { (value: $0, title: $0.label) }
            )
        }
        .padding(.horizontal, DoneSpace.s12)
        .padding(.vertical, DoneSpace.s8)
    }

    private func uniqueTitles(_ sessions: [FocusSession]) -> [String] {
        var seen = Set<String>()
        return sessions.map(\.title).filter { seen.insert($0).inserted }
    }
}
