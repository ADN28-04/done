import SwiftUI

// MARK: Fiche d'une tâche

/// Fiche d'une tâche : titre, notes, liste, priorité, type, échéance, blocage et étapes.
/// Les étapes s'ajoutent et se cochent tout de suite ; le reste attend « Enregistrer ».
struct TaskEditorSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let taskID: String

    @State private var draft: TodoTask?
    @State private var newStep = ""
    @State private var confirmDelete = false
    @FocusState private var stepFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let task = Binding($draft) {
                form(task)
            } else {
                Text("Cette tâche n'existe plus.")
                    .doneText(.body)
                    .foregroundStyle(DoneColor.textSecondary)
                HStack {
                    Spacer()
                    Button("Fermer") { dismiss() }
                        .buttonStyle(DoneButtonStyle())
                        .keyboardShortcut(.cancelAction)
                }
                .padding(.top, DoneSpace.s20)
            }
        }
        .padding(DoneSpace.s24)
        .frame(width: 600)
        .background(DoneColor.bgCanvas)
        .onAppear {
            if draft == nil { draft = model.store[taskID] }
        }
    }

    @ViewBuilder
    private func form(_ task: Binding<TodoTask>) -> some View {
        let parent = task.wrappedValue.parentID.flatMap { model.store[$0] }
        Eyebrow(text: parent.map { "Étape de « \($0.title) »" } ?? model.projectName(task.wrappedValue.projectID))
        TextField("Titre", text: task.title)
            .textFieldStyle(.plain)
            .font(.done(.displayM))
            .foregroundStyle(DoneColor.textPrimary)
            .onSubmit(save)
            .padding(.top, DoneSpace.s8)
        NotesEditor(text: task.notes)
            .padding(.top, DoneSpace.s12)

        TaskDetailsCard(
            projectID: task.projectID,
            priority: task.priority,
            kind: task.kind,
            due: task.due,
            listLocked: parent != nil
        ) {
            Hairline().padding(.horizontal, DoneSpace.s16)
            DetailRow("Bloquée") {
                Toggle("Bloquée", isOn: task.isBlocked)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .tint(DoneColor.stateActive)
            }
        }
        .padding(.top, DoneSpace.s16)
        if task.wrappedValue.isBlocked, let note = model.resumeNote(for: taskID) {
            Text(note.text)
                .doneText(.caption)
                .foregroundStyle(DoneColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DoneSpace.s6)
                .padding(.top, DoneSpace.s8)
        }

        stepsSection(task.wrappedValue)
            .padding(.top, DoneSpace.s20)

        HStack(spacing: DoneSpace.s8) {
            Button("Supprimer…") { confirmDelete = true }
                .buttonStyle(DoneButtonStyle(kind: .plain))
            Spacer()
            Button("Annuler") { dismiss() }
                .buttonStyle(DoneButtonStyle())
                .keyboardShortcut(.cancelAction)
            Button("Enregistrer", action: save)
                .buttonStyle(DoneButtonStyle(kind: .primary))
                .keyboardShortcut(.return, modifiers: .command)
                .help("⌘ Entrée")
        }
        .padding(.top, DoneSpace.s24)
        .confirmationDialog("Supprimer « \(task.wrappedValue.title) » ?", isPresented: $confirmDelete) {
            Button("Supprimer", role: .destructive) {
                model.delete(task.wrappedValue)
                dismiss()
            }
        } message: {
            Text(model.index.children(of: taskID).isEmpty ? "C'est définitif." : "Ses étapes aussi. C'est définitif.")
        }
    }

    private func stepsSection(_ task: TodoTask) -> some View {
        let steps = model.index.children(of: task.id)
        return VStack(alignment: .leading, spacing: DoneSpace.s8) {
            Eyebrow(text: steps.isEmpty ? "Étapes" : "Étapes · \(steps.count)")
                .padding(.leading, DoneSpace.s2)
            VStack(spacing: 0) {
                ForEach(steps) { step in
                    HStack(spacing: DoneSpace.s12) {
                        TaskCheckbox(isDone: false) { model.complete(step) }
                        Text(step.title)
                            .doneText(.body)
                            .foregroundStyle(DoneColor.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if step.isBlocked {
                            StateChip(kind: .blocked, title: "Bloquée")
                        }
                    }
                    .padding(.horizontal, DoneSpace.s12)
                    .frame(height: 40)
                    Hairline().padding(.horizontal, DoneSpace.s12)
                }
                HStack(spacing: DoneSpace.s12) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DoneColor.stateActiveText)
                        .frame(width: 18)
                    TextField("Ajouter une étape", text: $newStep)
                        .textFieldStyle(.plain)
                        .font(.done(.body))
                        .focused($stepFocused)
                        .onSubmit(addStep)
                }
                .padding(.horizontal, DoneSpace.s12)
                .frame(height: 40)
            }
            .doneCard()
        }
    }

    private func addStep() {
        guard model.addTask(newStep, projectID: draft?.projectID, parentID: taskID) != nil else { return }
        newStep = ""
        stepFocused = true
    }

    private func save() {
        if let draft { model.update(draft) }
        dismiss()
    }
}

// MARK: Détails partagés

/// Détails communs à la fiche et à la capture : liste, priorité, type et échéance, dans une carte.
/// La fiche y ajoute la ligne « Bloquée ».
struct TaskDetailsCard<Extra: View>: View {
    @Environment(AppModel.self) private var model
    @Binding var projectID: String?
    @Binding var priority: Int
    @Binding var kind: TaskKind
    @Binding var due: Date?
    /// Une étape reste dans la liste de sa tâche.
    var listLocked = false
    let extra: Extra

    init(
        projectID: Binding<String?>,
        priority: Binding<Int>,
        kind: Binding<TaskKind>,
        due: Binding<Date?>,
        listLocked: Bool = false,
        @ViewBuilder extra: () -> Extra
    ) {
        _projectID = projectID
        _priority = priority
        _kind = kind
        _due = due
        self.listLocked = listLocked
        self.extra = extra()
    }

    var body: some View {
        VStack(spacing: 0) {
            DetailRow("Liste") {
                Menu {
                    Button("Inbox") { projectID = nil }
                    ForEach(model.projects) { project in
                        Button(project.name) { projectID = project.id }
                    }
                } label: {
                    Text(model.projectName(projectID))
                        .font(.done(.body))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .disabled(listLocked)
                .help(listLocked ? "Une étape reste dans la liste de sa tâche" : "Ranger la tâche")
            }
            Hairline().padding(.horizontal, DoneSpace.s16)
            DetailRow("Priorité") {
                DoneSegmented(selection: $priority, options: (1...4).map { (value: $0, title: "P\($0)") })
            }
            Hairline().padding(.horizontal, DoneSpace.s16)
            DetailRow("Type") {
                DoneSegmented(selection: $kind, options: TaskKind.allCases.map { (value: $0, title: $0.label) })
            }
            Hairline().padding(.horizontal, DoneSpace.s16)
            DetailRow("Échéance") {
                DueControl(due: $due)
            }
            extra
        }
        .doneCard()
    }
}

extension TaskDetailsCard where Extra == EmptyView {
    init(projectID: Binding<String?>, priority: Binding<Int>, kind: Binding<TaskKind>, due: Binding<Date?>) {
        self.init(projectID: projectID, priority: priority, kind: kind, due: due) { EmptyView() }
    }
}

/// Ligne de détail : libellé à gauche, contrôle à droite, 44 de haut.
struct DetailRow<Trailing: View>: View {
    let title: String
    let trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: DoneSpace.s12) {
            Text(title)
                .doneText(.body)
                .foregroundStyle(DoneColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(.horizontal, DoneSpace.s16)
        .frame(minHeight: 44)
    }
}

/// Notes de la tâche, sur plusieurs lignes.
struct NotesEditor: View {
    @Binding var text: String
    var height: CGFloat = 84

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("Notes, liens, contexte")
                    .doneText(.body)
                    .foregroundStyle(DoneColor.textSecondary)
                    .padding(.top, DoneSpace.s8)
                    .padding(.leading, 13)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $text)
                .font(.done(.body))
                .foregroundStyle(DoneColor.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(8)
        }
        .frame(height: height)
        .background(DoneColor.surfaceDefault, in: RoundedRectangle(cornerRadius: DoneRadius.sm, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DoneRadius.sm, style: .continuous).strokeBorder(DoneColor.borderControl, lineWidth: 1))
    }
}

/// Échéance : aucune, aujourd'hui, demain ou un jour choisi.
struct DueControl: View {
    @Binding var due: Date?

    var body: some View {
        let today = Calendar.current.startOfDay(for: .now)
        HStack(spacing: DoneSpace.s6) {
            if let value = due {
                DatePicker(
                    "Échéance",
                    selection: Binding(get: { value }, set: { due = Calendar.current.startOfDay(for: $0) }),
                    displayedComponents: .date
                )
                .labelsHidden()
                Button("Retirer") { due = nil }
                    .buttonStyle(DoneButtonStyle(kind: .plain, compact: true))
            } else {
                Button("Aujourd'hui") { due = today }
                    .buttonStyle(DoneButtonStyle(compact: true))
                Button("Demain") { due = Calendar.current.date(byAdding: .day, value: 1, to: today) }
                    .buttonStyle(DoneButtonStyle(compact: true))
                Button("Choisir…") { due = today }
                    .buttonStyle(DoneButtonStyle(kind: .plain, compact: true))
            }
        }
    }
}

// MARK: Capture

/// Saisie d'une nouvelle tâche, avec tous ses détails d'emblée : titre, notes, liste, priorité,
/// type, échéance et étapes. Entrée dans le titre ajoute tout de suite ; ⌘ Entrée ajoute depuis
/// n'importe quel champ. Sert à la feuille ⌘N et à la fenêtre flottante du raccourci global.
struct CaptureForm: View {
    @Environment(AppModel.self) private var model
    @Binding var draft: TaskDraft
    /// Change pour redonner le focus au titre (fenêtre flottante réutilisée d'une ouverture à l'autre).
    var focusRequest = 0
    let onCancel: () -> Void
    let onAdded: (TodoTask) -> Void

    @State private var newStep = ""
    @FocusState private var focus: Field?

    private enum Field {
        case title, step
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Nouvelle tâche")
            TextField("Ce que tu as à faire", text: $draft.title)
                .textFieldStyle(.plain)
                .font(.done(.displayM))
                .foregroundStyle(DoneColor.textPrimary)
                .focused($focus, equals: .title)
                .onSubmit(add)
                .padding(.top, DoneSpace.s8)
            NotesEditor(text: $draft.notes, height: 64)
                .padding(.top, DoneSpace.s12)
            TaskDetailsCard(projectID: $draft.projectID, priority: $draft.priority, kind: $draft.kind, due: $draft.due)
                .padding(.top, DoneSpace.s16)
            stepsSection
                .padding(.top, DoneSpace.s20)
            HStack(spacing: DoneSpace.s8) {
                Spacer()
                Button("Annuler", action: onCancel)
                    .buttonStyle(DoneButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("Ajouter", action: add)
                    .buttonStyle(DoneButtonStyle(kind: .primary))
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!draft.hasTitle)
                    .help("⌘ Entrée")
            }
            .padding(.top, DoneSpace.s24)
        }
        .onAppear { focus = .title }
        .onChange(of: focusRequest) { focus = .title }
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: DoneSpace.s8) {
            Eyebrow(text: draft.steps.isEmpty ? "Étapes" : "Étapes · \(draft.steps.count)")
                .padding(.leading, DoneSpace.s2)
            VStack(spacing: 0) {
                ForEach(Array(draft.steps.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: DoneSpace.s12) {
                        Text("\(index + 1)")
                            .font(.done(.numericS))
                            .foregroundStyle(DoneColor.textSecondary)
                            .frame(width: 18)
                        Text(step)
                            .doneText(.body)
                            .foregroundStyle(DoneColor.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Button {
                            draft.steps.remove(at: index)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .semibold))
                                .frame(width: 20, height: 20)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(DoneColor.textSecondary)
                        .help("Retirer l'étape")
                    }
                    .padding(.horizontal, DoneSpace.s12)
                    .frame(height: 36)
                    Hairline().padding(.horizontal, DoneSpace.s12)
                }
                HStack(spacing: DoneSpace.s12) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DoneColor.stateActiveText)
                        .frame(width: 18)
                    TextField("Ajouter une étape", text: $newStep)
                        .textFieldStyle(.plain)
                        .font(.done(.body))
                        .focused($focus, equals: .step)
                        .onSubmit(addStep)
                }
                .padding(.horizontal, DoneSpace.s12)
                .frame(height: 36)
            }
            .doneCard()
        }
    }

    private func addStep() {
        let step = newStep.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !step.isEmpty else { return }
        draft.steps.append(step)
        newStep = ""
        focus = .step
    }

    private func add() {
        var complete = draft
        // Une étape tapée sans Entrée n'est pas perdue.
        let pending = newStep.trimmingCharacters(in: .whitespacesAndNewlines)
        if !pending.isEmpty { complete.steps.append(pending) }
        guard let task = model.addTask(complete) else {
            focus = .title
            return
        }
        newStep = ""
        onAdded(task)
    }
}

/// ⌘N ou « + », depuis n'importe quel écran, même en session. Peut partir d'un titre déjà tapé
/// dans une liste (« Détails… »).
struct CaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: TaskDraft
    private let onAdded: () -> Void

    init(draft: TaskDraft = TaskDraft(), onAdded: @escaping () -> Void = {}) {
        _draft = State(initialValue: draft)
        self.onAdded = onAdded
    }

    var body: some View {
        CaptureForm(draft: $draft, onCancel: { dismiss() }, onAdded: { _ in
            onAdded()
            dismiss()
        })
        .padding(DoneSpace.s24)
        .frame(width: 560)
        .background(DoneColor.bgCanvas)
    }
}
