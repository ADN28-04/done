import SwiftData
import SwiftUI

// MARK: Découpage assisté

/// Demande la prochaine action concrète d'une tâche et la crée comme sous-tâche dans Todoist.
struct BreakdownSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let task: TodoistTask
    var onAdded: (TodoistTask) -> Void = { _ in }
    /// Demande des propositions à Claude dès l'ouverture.
    var askClaudeOnOpen = false

    @State private var text = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var suggestions: [Breakdown.Suggestion] = []
    @State private var isAsking = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Découper")
            Text("Quelle est la prochaine action concrète ?")
                .font(.display(24))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
            Text(task.content)
                .font(.text(14))
                .foregroundStyle(Theme.label2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
            TextField("Ex. : lister les fiches à mettre à jour", text: $text)
                .textFieldStyle(.plain)
                .font(.text(15))
                .focused($fieldFocused)
                .onSubmit(save)
                .padding(.horizontal, 14)
                .frame(height: 40)
                .surface(radius: 12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.ring.opacity(fieldFocused ? 0.45 : 0), lineWidth: 2)
                )
                .padding(.top, 22)
            Text("Une action qui tient en une session et commence par un verbe : écrire, appeler, lister, envoyer.")
                .font(.text(12))
                .foregroundStyle(Theme.label2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
            if model.hasClaudeKey {
                claudeSuggestions
                    .padding(.top, 18)
            } else {
                Text("Ajoute une clé API Claude dans Réglages › Claude pour obtenir des propositions.")
                    .font(.text(12))
                    .foregroundStyle(Theme.label3)
                    .padding(.top, 14)
            }
            if let errorMessage {
                NoticeBox(text: errorMessage, tone: .error)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 16)
            }
            HStack(spacing: 10) {
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
            .padding(.top, 26)
        }
        .padding(28)
        .frame(width: 500)
        .background(Backdrop(style: .wash))
        .onAppear { fieldFocused = true }
        .task {
            if askClaudeOnOpen, model.hasClaudeKey, suggestions.isEmpty {
                await askClaude()
            }
        }
    }

    /// Trois propositions de Claude : un clic les met dans le champ, à retoucher si besoin.
    @ViewBuilder
    private var claudeSuggestions: some View {
        if suggestions.isEmpty {
            Button {
                Task { await askClaude() }
            } label: {
                if isAsking {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Claude lit ton contexte…")
                    }
                } else {
                    Label("Proposer avec Claude", systemImage: "sparkles")
                }
            }
            .buttonStyle(PillButtonStyle(size: .small))
            .disabled(isAsking)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: "Propositions de Claude")
                    .padding(.leading, 2)
                VStack(spacing: 0) {
                    ForEach(suggestions) { suggestion in
                        Button {
                            text = suggestion.title
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(suggestion.title)
                                    .font(.text(14, .medium))
                                    .foregroundStyle(Theme.label)
                                Text(suggestion.why)
                                    .font(.text(12))
                                    .foregroundStyle(Theme.label2)
                            }
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(trimmed == suggestion.title ? Theme.selection : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .surface(radius: 16)
                Button(isAsking ? "Claude lit ton contexte…" : "Autres propositions") {
                    Task { await askClaude() }
                }
                .buttonStyle(PillButtonStyle(kind: .plain, size: .mini))
                .disabled(isAsking)
            }
        }
    }

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func askClaude() async {
        isAsking = true
        defer { isAsking = false }
        errorMessage = nil
        do {
            suggestions = try await model.suggestBreakdown(for: task)
        } catch {
            errorMessage = "Claude n'a pas pu proposer d'action : \(error.localizedDescription)"
        }
    }

    private func save() {
        guard !trimmed.isEmpty, !isSaving else { return }
        // Posé tout de suite : Entrée et le bouton ne créent jamais deux sous-tâches.
        isSaving = true
        Task {
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
                .font(.display(26, bold: true))
                .padding(.top, 10)
            Text("\(active.count) tâches portent @\(Rules.activeLabel), pour une cible de \(target). Mets en file d'attente celles que tu n'avances pas cette semaine.")
                .font(.text(14))
                .foregroundStyle(Theme.label2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(active.enumerated()), id: \.element.id) { offset, task in
                        if offset > 0 {
                            Hairline().padding(.horizontal, 12)
                        }
                        HStack(spacing: 12) {
                            TaskRowContent(task: task)
                                .opacity(parked.contains(task.id) ? 0.5 : 1)
                            if plan.contains(task.id) {
                                Text("Dans le plan")
                                    .font(.mono(11))
                                    .foregroundStyle(Theme.accentText)
                                    .padding(.horizontal, 8)
                                    .frame(height: 20)
                                    .background(Theme.accentTint, in: Capsule())
                            }
                            GlassSegmented(selection: binding(for: task.id), options: [(value: false, title: "Actif"), (value: true, title: "En attente")])
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                }
                .padding(6)
                .surface(radius: 18)
                .padding(.bottom, 2)
            }
            .scrollIndicators(.never)
            // Une ligne fait environ 58 pt : au-delà de six chantiers, la liste défile.
            .frame(height: min(CGFloat(active.count) * 58 + 14, 362))
            .padding(.top, 20)

            HStack(spacing: 8) {
                Eyebrow(text: "Restent actifs")
                Text("\(remaining) / \(target)")
                    .font(.mono(15))
                    .foregroundStyle(remaining > target ? Theme.orangeText : Theme.accentText)
            }
            .padding(.top, 14)

            Text("Done retire le label @\(Rules.activeLabel) dans Todoist, sur la tâche et ses sous-tâches. Elles restent à leur place.")
                .font(.text(12))
                .foregroundStyle(Theme.label2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            if let errorMessage {
                NoticeBox(text: errorMessage, tone: .error)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 16)
            }

            HStack(spacing: 10) {
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
            .padding(.top, 26)
        }
        .padding(28)
        .frame(width: 640)
        .background(Backdrop(style: .wash))
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
                .font(.display(30, bold: true))
                .tracking(-0.45)
                .padding(.top, 10)

            HStack(spacing: 10) {
                StatTile(title: "Temps de focus", value: Format.minutes(summary.focusMinutes))
                StatTile(title: "Sessions", value: "\(summary.sessions)")
                StatTile(title: "Tâches cochées", value: "\(summary.checked)")
                StatTile(title: "Interruptions", value: "\(summary.interruptions)")
            }
            .padding(.top, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if !checked.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Eyebrow(text: "Terminé aujourd'hui")
                                .padding(.leading, 2)
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(checked, id: \.self) { title in
                                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 13))
                                            .foregroundStyle(Theme.ring)
                                        Text(title)
                                            .font(.text(14))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .surface(radius: 18)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(text: "Pas terminé")
                            .padding(.leading, 2)
                        if unfinished.isEmpty {
                            Text("Tout le plan du jour est terminé.")
                                .font(.text(14))
                                .foregroundStyle(Theme.accentText)
                                .padding(.leading, 2)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(unfinished.enumerated()), id: \.element.id) { offset, task in
                                    if offset > 0 {
                                        Hairline().padding(.horizontal, 12)
                                    }
                                    unfinishedRow(task)
                                }
                            }
                            .padding(6)
                            .surface(radius: 18)
                            Text("« Demain » remet la tâche dans le plan de demain matin. « Plus tard » la laisse dans Todoist, hors du plan.")
                                .font(.text(12))
                                .foregroundStyle(Theme.label2)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.leading, 2)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 22)
                .padding(.bottom, 2)
            }
            .scrollIndicators(.never)

            HStack(spacing: 10) {
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
        .frame(width: 660, height: 620)
        .background(Backdrop(style: .wash))
        .sheet(item: $breakdownTask) { task in
            BreakdownSheet(task: task, onAdded: { _ in decisions[task.id] = .tomorrow }, askClaudeOnOpen: model.hasClaudeKey)
                .environment(model)
        }
    }

    private func unfinishedRow(_ task: TodoistTask) -> some View {
        HStack(spacing: 12) {
            TaskRowContent(task: task)
            if Planner.needsBreakdown(action: task, root: task, in: model.index) {
                Button(model.hasClaudeKey ? "Découper avec Claude…" : "Découper…") { breakdownTask = task }
                    .buttonStyle(PillButtonStyle(kind: .plain, size: .mini))
            }
            GlassSegmented(
                selection: Binding(
                    get: { decisions[task.id, default: .tomorrow] },
                    set: { decisions[task.id] = $0 }
                ),
                options: Review.Decision.allCases.map { (value: $0, title: $0.label) }
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func uniqueTitles(_ sessions: [FocusSession]) -> [String] {
        var seen = Set<String>()
        return sessions.map(\.title).filter { seen.insert($0).inserted }
    }
}
