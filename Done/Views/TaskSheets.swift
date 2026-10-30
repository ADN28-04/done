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
                    .font(.text(14))
                    .foregroundStyle(Theme.label2)
                HStack {
                    Spacer()
                    Button("Fermer") { dismiss() }
                        .buttonStyle(PillButtonStyle())
                        .keyboardShortcut(.cancelAction)
                }
                .padding(.top, 20)
            }
        }
        .padding(28)
        .frame(width: 600)
        .background(Backdrop(style: .wash))
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
            .font(.display(22))
            .onSubmit(save)
            .padding(.top, 10)
        notesEditor(task.notes)
            .padding(.top, 14)

        VStack(spacing: 0) {
            row("Liste") {
                Menu {
                    Button("Inbox") { task.wrappedValue.projectID = nil }
                    ForEach(model.projects) { project in
                        Button(project.name) { task.wrappedValue.projectID = project.id }
                    }
                } label: {
                    Text(model.projectName(task.wrappedValue.projectID))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .disabled(parent != nil)
                .help(parent != nil ? "Une étape reste dans la liste de sa tâche" : "Ranger la tâche")
            }
            Hairline().padding(.horizontal, 16)
            row("Priorité") {
                GlassSegmented(selection: task.priority, options: (1...4).map { (value: $0, title: "P\($0)") })
            }
            Hairline().padding(.horizontal, 16)
            row("Type") {
                GlassSegmented(selection: task.kind, options: TaskKind.allCases.map { (value: $0, title: $0.label) })
            }
            Hairline().padding(.horizontal, 16)
            row("Échéance") {
                dueControl(task.due)
            }
            Hairline().padding(.horizontal, 16)
            row("Bloquée") {
                Toggle("Bloquée", isOn: task.isBlocked)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .tint(Theme.accent)
            }
        }
        .surface(radius: 16)
        .padding(.top, 16)
        if task.wrappedValue.isBlocked, let note = model.resumeNote(for: taskID) {
            Text(note.text)
                .font(.text(12))
                .foregroundStyle(Theme.label2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 6)
                .padding(.top, 8)
        }

        stepsSection(task.wrappedValue)
            .padding(.top, 18)

        HStack(spacing: 10) {
            Button("Supprimer…") { confirmDelete = true }
                .buttonStyle(PillButtonStyle(kind: .plain))
            Spacer()
            Button("Annuler") { dismiss() }
                .buttonStyle(PillButtonStyle())
                .keyboardShortcut(.cancelAction)
            Button("Enregistrer", action: save)
                .buttonStyle(PillButtonStyle(kind: .primary))
                .keyboardShortcut(.return, modifiers: .command)
                .help("⌘ Entrée")
        }
        .padding(.top, 24)
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
        HStack(spacing: 12) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
        }
        .font(.text(14))
        .padding(.horizontal, 16)
        .frame(minHeight: 44)
    }

    private func notesEditor(_ notes: Binding<String>) -> some View {
        ZStack(alignment: .topLeading) {
            if notes.wrappedValue.isEmpty {
                Text("Notes, liens, contexte")
                    .font(.text(14))
                    .foregroundStyle(Theme.label3)
                    .padding(.top, 8)
                    .padding(.leading, 13)
                    .allowsHitTesting(false)
            }
            TextEditor(text: notes)
                .font(.text(14))
                .scrollContentBackground(.hidden)
                .padding(8)
        }
        .frame(height: 84)
        .background(Theme.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func dueControl(_ due: Binding<Date?>) -> some View {
        let today = Calendar.current.startOfDay(for: .now)
        return HStack(spacing: 6) {
            if let value = due.wrappedValue {
                DatePicker(
                    "Échéance",
                    selection: Binding(get: { value }, set: { due.wrappedValue = Calendar.current.startOfDay(for: $0) }),
                    displayedComponents: .date
                )
                .labelsHidden()
                Button("Retirer") { due.wrappedValue = nil }
                    .buttonStyle(PillButtonStyle(kind: .plain, size: .mini))
            } else {
                Button("Aujourd'hui") { due.wrappedValue = today }
                    .buttonStyle(PillButtonStyle(size: .mini))
                Button("Demain") { due.wrappedValue = Calendar.current.date(byAdding: .day, value: 1, to: today) }
                    .buttonStyle(PillButtonStyle(size: .mini))
                Button("Choisir…") { due.wrappedValue = today }
                    .buttonStyle(PillButtonStyle(kind: .plain, size: .mini))
            }
        }
    }

    private func stepsSection(_ task: TodoTask) -> some View {
        let steps = model.index.children(of: task.id)
        return VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: steps.isEmpty ? "Étapes" : "Étapes · \(steps.count)")
                .padding(.leading, 2)
            VStack(spacing: 0) {
                ForEach(steps) { step in
                    HStack(spacing: 10) {
                        CheckCircle(priority: step.priority, isDone: false) { model.complete(step) }
                        Text(step.title)
                            .font(.text(14))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if step.isBlocked {
                            Text("Bloquée")
                                .font(.text(12))
                                .foregroundStyle(Theme.orangeText)
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    Hairline().padding(.horizontal, 12)
                }
                HStack(spacing: 10) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.accentText)
                        .frame(width: 18)
                    TextField("Ajouter une étape", text: $newStep)
                        .textFieldStyle(.plain)
                        .font(.text(14))
                        .focused($stepFocused)
                        .onSubmit(addStep)
                }
                .padding(.horizontal, 12)
                .frame(height: 38)
            }
            .surface(radius: 14)
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
                .textFieldStyle(.plain)
                .font(.text(15))
                .focused($focused)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .surface(radius: 12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.ring.opacity(focused ? 0.45 : 0), lineWidth: 2)
                )
                .padding(.top, 12)
            HStack(spacing: 10) {
                Menu {
                    Button("Inbox") { projectID = nil }
                    ForEach(model.projects) { project in
                        Button(project.name) { projectID = project.id }
                    }
                } label: {
                    Text("Dans : \(model.projectName(projectID))")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                Spacer()
                Button("Annuler") { dismiss() }
                    .buttonStyle(PillButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("Ajouter", action: add)
                    .buttonStyle(PillButtonStyle(kind: .primary))
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .font(.text(13))
            .padding(.top, 18)
        }
        .padding(24)
        .frame(width: 480)
        .background(Backdrop(style: .wash))
        .onAppear { focused = true }
    }

    private func add() {
        guard model.addTask(title, projectID: projectID) != nil else { return }
        dismiss()
    }
}
