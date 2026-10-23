import SwiftData
import SwiftUI

// MARK: Découpage assisté

/// Découpe une tâche en étapes, dans l'ordre, et les crée toutes comme sous-tâches dans Todoist.
/// Claude peut proposer le découpage ; chaque étape reste modifiable avant l'envoi.
struct BreakdownSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let task: TodoistTask
    var onAdded: (TodoistTask) -> Void = { _ in }
    /// Demande un découpage à Claude dès l'ouverture.
    var askClaudeOnOpen = false

    /// Une ligne de la liste. L'identifiant garde le focus sur la bonne ligne.
    private struct Step: Identifiable, Equatable {
        let id = UUID()
        var text: String
    }

    @State private var steps = [Step(text: "")]
    /// Approche résumée par Claude, affichée au-dessus des étapes.
    @State private var approach: String?
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var isAsking = false
    /// Pièces jointes au moment de la dernière demande, pour proposer de relancer Claude.
    @State private var askedWith: [String]?
    @State private var isDropTargeted = false
    @FocusState private var focusedStep: UUID?

    private static let rowHeight: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Découper")
            Text("Quelles étapes pour finir cette tâche ?")
                .font(.display(24))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
            Text(task.content)
                .font(.text(14))
                .foregroundStyle(Theme.label2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
            if model.hasClaudeKey {
                attachmentsBlock
                    .padding(.top, 18)
                claudeRow
                    .padding(.top, 14)
            } else {
                Text("Ajoute une clé API Claude dans Réglages › Claude pour obtenir un découpage.")
                    .font(.text(12))
                    .foregroundStyle(Theme.label3)
                    .padding(.top, 14)
            }
            stepsList
                .padding(.top, 16)
            Text("Chaque étape tient en une session et commence par un verbe. Done te les propose une par une, dans cet ordre. Entrée ajoute une ligne.")
                .font(.text(12))
                .foregroundStyle(Theme.label2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
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
                            Text("Ajout dans Todoist…")
                        }
                    } else {
                        Text(filledSteps.count > 1 ? "Ajouter \(filledSteps.count) étapes dans Todoist" : "Ajouter dans Todoist")
                    }
                }
                .buttonStyle(PillButtonStyle(kind: .primary))
                // Entrée sert à ajouter une ligne : l'envoi passe par ⌘ Entrée.
                .keyboardShortcut(.return, modifiers: .command)
                .help("⌘ Entrée")
                .disabled(filledSteps.isEmpty || isSaving || isAsking)
            }
            .padding(.top, 26)
        }
        .padding(28)
        .frame(width: 540)
        .background(Backdrop(style: .wash))
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.ring, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard model.hasClaudeKey else { return false }
            attach(urls)
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted && model.hasClaudeKey
        }
        .onAppear { focusedStep = steps.first?.id }
        .task {
            if askClaudeOnOpen, model.hasClaudeKey, approach == nil {
                await askClaude()
            }
        }
    }

    // MARK: Étapes

    private var stepsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { offset, step in
                        if offset > 0 {
                            Hairline().padding(.horizontal, 12)
                        }
                        HStack(spacing: 12) {
                            Text("\(offset + 1)")
                                .font(.mono(15))
                                .foregroundStyle(Theme.accentText)
                                .frame(width: 22, alignment: .trailing)
                            TextField(offset == 0 ? "Ex. : lister les fiches à mettre à jour" : "Étape suivante", text: text(of: step.id))
                                .textFieldStyle(.plain)
                                .font(.text(14))
                                .focused($focusedStep, equals: step.id)
                                .onSubmit { insertStep(after: step.id) }
                            Button {
                                removeStep(step.id)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Theme.label2)
                                    .frame(width: 20, height: 20)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help("Retirer cette étape")
                            .opacity(steps.count > 1 ? 1 : 0)
                            .disabled(steps.count <= 1)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: Self.rowHeight)
                    }
                }
                .padding(4)
            }
            .scrollIndicators(.never)
            // Six lignes visibles, la liste défile au-delà.
            .frame(height: min(CGFloat(steps.count), 6) * (Self.rowHeight + 1) + 8)
            .surface(radius: 14)
            Button {
                insertStep(after: steps.last?.id)
            } label: {
                Label("Ajouter une étape", systemImage: "plus")
            }
            .buttonStyle(PillButtonStyle(kind: .plain, size: .mini))
            .disabled(steps.count >= Breakdown.maxSteps)
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
        guard steps.count < Breakdown.maxSteps else { return }
        let step = Step(text: "")
        let position = id.flatMap { id in steps.firstIndex { $0.id == id } }.map { $0 + 1 } ?? steps.count
        steps.insert(step, at: position)
        focusedStep = step.id
    }

    private func removeStep(_ id: UUID) {
        steps.removeAll { $0.id == id }
        if steps.isEmpty { steps = [Step(text: "")] }
    }

    // MARK: Claude

    private var claudeRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let approach, !approach.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.accentText)
                    Text(approach)
                        .font(.text(13))
                        .foregroundStyle(Theme.label2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button {
                Task { await askClaude() }
            } label: {
                if isAsking {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Claude prépare le découpage…")
                    }
                } else {
                    Label(claudeButtonTitle, systemImage: "sparkles")
                }
            }
            .buttonStyle(PillButtonStyle(size: .small))
            .disabled(isAsking || isSaving)
        }
    }

    private var claudeButtonTitle: String {
        guard approach != nil else { return "Découper avec Claude" }
        return askedWith == model.attachments(for: task.id) ? "Proposer un autre découpage" : "Relancer avec les pièces jointes"
    }

    /// Fichiers joints à la tâche : envoyés à Claude en entier, gardés pour les prochains découpages.
    private var attachmentsBlock: some View {
        let paths = model.attachments(for: task.id)
        return VStack(alignment: .leading, spacing: 8) {
            if !paths.isEmpty {
                Eyebrow(text: "Pièces jointes")
                    .padding(.leading, 2)
                VStack(spacing: 6) {
                    ForEach(paths, id: \.self) { path in
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.label2)
                            Text((path as NSString).lastPathComponent)
                                .font(.text(13))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .help(path)
                            Spacer(minLength: 0)
                            Button {
                                model.detach(path, from: task.id)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Theme.label2)
                                    .frame(width: 20, height: 20)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help("Retirer cette pièce jointe")
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(Theme.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
            Button {
                attach(SystemBridge.chooseFiles(prompt: "Joindre"))
            } label: {
                Label("Joindre un fichier…", systemImage: "paperclip")
            }
            .buttonStyle(PillButtonStyle(kind: .plain, size: .small))
            .disabled(paths.count >= Breakdown.maxAttachments)
            .help("PDF, image, Word, Markdown ou texte : Claude le lit en entier. Tu peux aussi glisser un fichier sur cette fenêtre.")
        }
    }

    private func attach(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        var problems: [String] = []
        var accepted: [String] = []
        for url in urls {
            if let problem = AttachmentLoader.problem(with: url) {
                problems.append(problem.localizedDescription)
            } else {
                accepted.append(url.path)
            }
        }
        if !model.attach(accepted, to: task.id).isEmpty {
            problems.append("\(Breakdown.maxAttachments) pièces jointes au plus par tâche.")
        }
        errorMessage = problems.isEmpty ? nil : problems.joined(separator: " ")
    }

    private func askClaude() async {
        isAsking = true
        defer { isAsking = false }
        errorMessage = nil
        askedWith = model.attachments(for: task.id)
        do {
            let plan = try await model.suggestBreakdown(for: task)
            approach = plan.approach
            steps = plan.steps.map { Step(text: $0) }
        } catch {
            errorMessage = "Claude n'a pas pu découper la tâche : \(error.localizedDescription)"
        }
    }

    // MARK: Envoi

    private func save() {
        let contents = filledSteps
        guard !contents.isEmpty, !isSaving else { return }
        // Posé tout de suite : un double clic ne crée jamais les étapes deux fois.
        isSaving = true
        Task {
            defer { isSaving = false }
            let (created, error) = await model.addSubtasks(contents, to: task)
            if let first = created.first { onAdded(first) }
            guard let error else {
                dismiss()
                return
            }
            // Les étapes déjà créées sortent de la liste : un nouvel essai ne les recrée pas.
            steps = contents.dropFirst(created.count).map { Step(text: $0) }
            errorMessage = created.isEmpty
                ? "Les étapes n'ont pas été créées : \(error.localizedDescription)"
                : "\(created.count) étape\(created.count > 1 ? "s" : "") sur \(contents.count) dans Todoist. Les autres n'ont pas été créées : \(error.localizedDescription)"
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
