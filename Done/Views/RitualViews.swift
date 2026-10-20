import SwiftData
import SwiftUI

// MARK: Découpage assisté

/// Demande la prochaine action concrète d'une tâche et la crée comme sous-tâche dans Todoist.
struct BreakdownSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let task: TodoistTask
    var onAdded: (TodoistTask) -> Void = { _ in }

    @State private var text = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Découper")
            Text("Quelle est la prochaine action concrète ?")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.label)
                .padding(.top, 12)
            Text(task.content)
                .font(.system(size: 13))
                .foregroundStyle(Theme.label2)
                .padding(.top, 6)
            TextField("Ex. : lister les fiches à mettre à jour", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($fieldFocused)
                .onSubmit(save)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(Theme.field, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(fieldFocused ? Theme.accent.opacity(0.4) : Theme.separator, lineWidth: fieldFocused ? 3 : 1)
                )
                .padding(.top, 20)
            Text("Une action qui tient en une session et commence par un verbe : écrire, appeler, lister, envoyer.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.label2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.redText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.redTint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.top, 16)
            }
            HStack(spacing: 8) {
                Spacer()
                Button("Annuler") { dismiss() }
                    .buttonStyle(PillButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button(action: save) {
                    if isSaving {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Ajout…")
                        }
                    } else {
                        Text("Ajouter dans Todoist")
                    }
                }
                .buttonStyle(PillButtonStyle(kind: .primary))
                .keyboardShortcut(.defaultAction)
                .disabled(trimmed.isEmpty || isSaving)
            }
            .padding(.top, 24)
        }
        .padding(28)
        .frame(width: 480)
        .background(Theme.background)
        .onAppear { fieldFocused = true }
    }

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        guard !trimmed.isEmpty, !isSaving else { return }
        Task {
            isSaving = true
            defer { isSaving = false }
            do {
                let created = try await model.addSubtask(trimmed, to: task)
                onAdded(created)
                dismiss()
            } catch {
                errorMessage = "La sous-tâche n'a pas été créée : \(error.localizedDescription)"
            }
        }
    }
}

/// Encart de la carte Focus quand la tâche n'a pas encore de sous-tâche.
struct BreakdownHint: View {
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("Pas encore de sous-tâche. La découper en une première action aide à démarrer.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.accentText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("Découper…", action: action)
                .buttonStyle(PillButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.accentTint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: Garde-fou des chantiers actifs

/// Proposé à la validation du plan quand il y a plus de chantiers actifs que la cible.
struct GuardrailSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let plan: [String]
    let onValidate: () -> Void

    @State private var parked: Set<String> = []
    @State private var prepared = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        let active = model.activeChantiers
        let target = model.rules.maxActive
        let remaining = active.count - parked.count
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Garde-fou")
            Text("Trop de chantiers actifs")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.label)
                .padding(.top, 12)
            Text("\(active.count) tâches portent @\(Rules.activeLabel), pour une cible de \(target). Mets en file d'attente celles que tu n'avances pas cette semaine.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.label2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            VStack(spacing: 0) {
                ForEach(active) { task in
                    HStack(spacing: 12) {
                        TaskRowContent(task: task)
                            .opacity(parked.contains(task.id) ? 0.5 : 1)
                        if plan.contains(task.id) {
                            Text("Dans le plan")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.accentText)
                        }
                        Picker("État", selection: binding(for: task.id)) {
                            Text("Actif").tag(false)
                            Text("En attente").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
            }
            .padding(4)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.top, 20)

            HStack(spacing: 6) {
                Text("Restent actifs :")
                    .foregroundStyle(Theme.label2)
                Text("\(remaining) / \(target)")
                    .monospacedDigit()
                    .fontWeight(.semibold)
                    .foregroundStyle(remaining > target ? Theme.orangeText : Theme.accentText)
            }
            .font(.system(size: 13))
            .padding(.top, 12)

            Text("Done retire le label @\(Rules.activeLabel) dans Todoist, sur la tâche et ses sous-tâches. Elles restent à leur place.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.label2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.redText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.redTint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.top, 16)
            }

            HStack(spacing: 8) {
                Button("Annuler") { dismiss() }
                    .buttonStyle(PillButtonStyle(kind: .plain))
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Valider sans changer") {
                    dismiss()
                    onValidate()
                }
                .buttonStyle(PillButtonStyle())
                Button(action: parkAndValidate) {
                    if isSaving {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Mise à jour de Todoist…")
                        }
                    } else {
                        Text(parked.isEmpty ? "Valider" : "Mettre \(parked.count) en attente et valider")
                    }
                }
                .buttonStyle(PillButtonStyle(kind: .primary))
                .keyboardShortcut(.defaultAction)
                .disabled(isSaving)
            }
            .padding(.top, 24)
        }
        .padding(28)
        .frame(width: 620)
        .background(Theme.background)
        .onAppear {
            // Par défaut, les chantiers absents du plan du jour partent en file d'attente.
            guard !prepared else { return }
            parked = Set(active.filter { !plan.contains($0.id) }.map(\.id))
            prepared = true
        }
    }

    private func binding(for id: String) -> Binding<Bool> {
        Binding(
            get: { parked.contains(id) },
            set: { isParked in
                if isParked { parked.insert(id) } else { parked.remove(id) }
            }
        )
    }

    private func parkAndValidate() {
        let tasks = model.activeChantiers.filter { parked.contains($0.id) }
        guard !tasks.isEmpty else {
            dismiss()
            onValidate()
            return
        }
        Task {
            isSaving = true
            defer { isSaving = false }
            do {
                try await model.park(tasks)
                dismiss()
                onValidate()
            } catch {
                errorMessage = "Todoist n'a pas été mis à jour : \(error.localizedDescription)"
            }
        }
    }
}

// MARK: Bilan du soir

struct ReviewSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FocusSession.startedAt) private var sessions: [FocusSession]

    @State private var decisions: [String: Review.Decision] = [:]
    @State private var breakdownTask: TodoistTask?

    var body: some View {
        let today = sessions.filter { Calendar.current.isDateInToday($0.startedAt) }
        let summary = Review.summary(today.map(\.fact), on: .now)
        let checked = uniqueTitles(today.filter { $0.outcome == .done })
        let unfinished = Review.unfinished(plan: model.planIDs, index: model.index)

        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Bilan du soir")
            Text("Ta journée")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.label)
                .padding(.top, 12)

            HStack(spacing: 10) {
                StatTile(title: "Temps de focus", value: Format.minutes(summary.focusMinutes))
                StatTile(title: "Sessions", value: "\(summary.sessions)")
                StatTile(title: "Tâches cochées", value: "\(summary.checked)")
                StatTile(title: "Interruptions", value: "\(summary.interruptions)")
            }
            .padding(.top, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !checked.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Eyebrow(text: "Terminé aujourd'hui")
                            ForEach(checked, id: \.self) { title in
                                Label(title, systemImage: "checkmark.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.label)
                                    .labelStyle(CheckLabelStyle())
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "Pas terminé")
                        if unfinished.isEmpty {
                            Text("Tout le plan du jour est terminé.")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.accentText)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(unfinished) { task in
                                    unfinishedRow(task)
                                }
                            }
                            .padding(4)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            Text("« Demain » remet la tâche dans le plan de demain matin. « Plus tard » la laisse dans Todoist, hors du plan.")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.label2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 20)
            }

            HStack(spacing: 8) {
                Button("Annuler") { dismiss() }
                    .buttonStyle(PillButtonStyle(kind: .plain))
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Terminer la journée") {
                    model.completeReview(Review.carryOver(decisions, plan: unfinished.map(\.id), on: .now))
                    dismiss()
                }
                .buttonStyle(PillButtonStyle(kind: .primary))
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 20)
        }
        .padding(28)
        .frame(width: 640, height: 600)
        .background(Theme.background)
        .sheet(item: $breakdownTask) { task in
            BreakdownSheet(task: task) { _ in decisions[task.id] = .tomorrow }
                .environment(model)
        }
    }

    private func unfinishedRow(_ task: TodoistTask) -> some View {
        HStack(spacing: 12) {
            TaskRowContent(task: task)
            if Planner.needsBreakdown(action: task, root: task, in: model.index) {
                Button("Découper…") { breakdownTask = task }
                    .buttonStyle(PillButtonStyle(kind: .plain))
            }
            Picker("Suite", selection: Binding(
                get: { decisions[task.id, default: .tomorrow] },
                set: { decisions[task.id] = $0 }
            )) {
                ForEach(Review.Decision.allCases) { decision in
                    Text(decision.label).tag(decision)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func uniqueTitles(_ sessions: [FocusSession]) -> [String] {
        var seen = Set<String>()
        return sessions.map(\.title).filter { seen.insert($0).inserted }
    }
}

/// Coche verte devant les tâches terminées du bilan.
private struct CheckLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon
                .foregroundStyle(Theme.accent)
            configuration.title
        }
    }
}

/// Bandeau qui propose le bilan, en fin de journée.
struct ReviewBanner: View {
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.stars")
                .foregroundStyle(Theme.accent)
            Text("C'est l'heure du bilan : deux minutes pour clore la journée et préparer demain.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.label)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("Faire le bilan", action: action)
                .buttonStyle(PillButtonStyle(kind: .primary))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.accent.opacity(0.35), lineWidth: 1))
    }
}
