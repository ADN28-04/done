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
        notesEditor(task.notes)
            .padding(.top, DoneSpace.s12)

        VStack(spacing: 0) {
            row("Liste") {
                Menu {
                    Button("Inbox") { task.wrappedValue.projectID = nil }
                    ForEach(model.projects) { project in
                        Button(project.name) { task.wrappedValue.projectID = project.id }
                    }
                } label: {
                    Text(model.projectName(task.wrappedValue.projectID))
                        .font(.done(.body))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .disabled(parent != nil)
                .help(parent != nil ? "Une étape reste dans la liste de sa tâche" : "Ranger la tâche")
            }
            Hairline().padding(.horizontal, DoneSpace.s16)
            row("Priorité") {
                DoneSegmented(selection: task.priority, options: (1...4).map { (value: $0, title: "P\($0)") })
            }
            Hairline().padding(.horizontal, DoneSpace.s16)
            row("Type") {
                DoneSegmented(selection: task.kind, options: TaskKind.allCases.map { (value: $0, title: $0.label) })
            }
            Hairline().padding(.horizontal, DoneSpace.s16)
            row("Échéance") {
                dueControl(task.due)
            }
            Hairline().padding(.horizontal, DoneSpace.s16)
            row("Bloquée") {
                Toggle("Bloquée", isOn: task.isBlocked)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .tint(DoneColor.stateActive)
            }
        }
        .doneCard()
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

    private func row<Trailing: View>(_ title: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: DoneSpace.s12) {
            Text(title)
                .doneText(.body)
                .foregroundStyle(DoneColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
        }
        .padding(.horizontal, DoneSpace.s16)
        .frame(minHeight: 44)
    }

    private func notesEditor(_ notes: Binding<String>) -> some View {
        ZStack(alignment: .topLeading) {
            if notes.wrappedValue.isEmpty {
                Text("Notes, liens, contexte")
                    .doneText(.body)
                    .foregroundStyle(DoneColor.textSecondary)
                    .padding(.top, DoneSpace.s8)
                    .padding(.leading, 13)
                    .allowsHitTesting(false)
            }
            TextEditor(text: notes)
                .font(.done(.body))
                .foregroundStyle(DoneColor.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(8)
        }
        .frame(height: 84)
        .background(DoneColor.surfaceDefault, in: RoundedRectangle(cornerRadius: DoneRadius.sm, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DoneRadius.sm, style: .continuous).strokeBorder(DoneColor.borderControl, lineWidth: 1))
    }

    private func dueControl(_ due: Binding<Date?>) -> some View {
        let today = Calendar.current.startOfDay(for: .now)
        return HStack(spacing: DoneSpace.s6) {
            if let value = due.wrappedValue {
                DatePicker(
                    "Échéance",
                    selection: Binding(get: { value }, set: { due.wrappedValue = Calendar.current.startOfDay(for: $0) }),
                    displayedComponents: .date
                )
                .labelsHidden()
                Button("Retirer") { due.wrappedValue = nil }
                    .buttonStyle(DoneButtonStyle(kind: .plain, compact: true))
            } else {
                Button("Aujourd'hui") { due.wrappedValue = today }
                    .buttonStyle(DoneButtonStyle(compact: true))
                Button("Demain") { due.wrappedValue = Calendar.current.date(byAdding: .day, value: 1, to: today) }
                    .buttonStyle(DoneButtonStyle(compact: true))
                Button("Choisir…") { due.wrappedValue = today }
                    .buttonStyle(DoneButtonStyle(kind: .plain, compact: true))
            }
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

// MARK: Capture rapide

/// ⌘N, depuis n'importe quel écran, même en session : une tâche notée en une ligne,
/// dans l'Inbox par défaut.
struct CaptureSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var projectID: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Nouvelle tâche")
            TextField("Ce que tu as à faire", text: $title)
                .focused($focused)
                .doneField(focused: focused, height: 40)
                .padding(.top, DoneSpace.s12)
            HStack(spacing: DoneSpace.s8) {
                Menu {
                    Button("Inbox") { projectID = nil }
                    ForEach(model.projects) { project in
                        Button(project.name) { projectID = project.id }
                    }
                } label: {
                    Text("Dans : \(model.projectName(projectID))")
                        .font(.done(.callout))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                Spacer()
                Button("Annuler") { dismiss() }
                    .buttonStyle(DoneButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("Ajouter", action: add)
                    .buttonStyle(DoneButtonStyle(kind: .primary))
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, DoneSpace.s16)
        }
        .padding(DoneSpace.s24)
        .frame(width: 480)
        .background(DoneColor.bgCanvas)
        .onAppear { focused = true }
    }

    private func add() {
        guard model.addTask(title, projectID: projectID) != nil else { return }
        dismiss()
    }
}
