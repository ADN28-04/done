import SwiftUI

/// Puces d'une tâche, à droite de sa ligne : priorité, blocage, échéance, puis durée.
struct TaskChips: View {
    @Environment(AppModel.self) private var model
    let task: TodoTask
    /// L'étiquette de la vue en cours : inutile de la répéter sur chaque ligne.
    var hiding: String?

    var body: some View {
        HStack(spacing: DoneSpace.s12) {
            PriorityChip(priority: task.priority)
            if task.isBlocked {
                StateChip(kind: .blocked, title: "Bloquée")
            }
            ForEach(task.tags.filter { $0 != hiding }, id: \.self) { tag in
                TagChip(name: tag)
            }
            if let due = task.due {
                InfoChip(symbol: "calendar", text: Format.chipDate(due), isAlert: Format.isOverdue(due))
            }
            if let minutes = sessionMinutes {
                InfoChip(symbol: "clock", text: Format.minutes(Double(minutes)))
            }
        }
    }

    /// Durée de session d'une tâche rapide ou Deepwork. Une tâche normale n'affiche rien.
    private var sessionMinutes: Int? {
        switch task.kind {
        case .quick: model.rules.quickMinutes
        case .deepwork: model.rules.deepworkMinutes
        case .normal: nil
        }
    }
}

/// Contenu d'une ligne de tâche : titre (body.strong), métadonnées (caption) et puces à droite.
struct TaskRowContent: View {
    @Environment(AppModel.self) private var model
    let task: TodoTask
    var showDetails = true

    var body: some View {
        HStack(spacing: DoneSpace.s12) {
            VStack(alignment: .leading, spacing: DoneSpace.s2) {
                Text(task.title)
                    .doneText(.bodyStrong)
                    .foregroundStyle(DoneColor.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if showDetails, !details.isEmpty {
                    Text(details)
                        .doneText(.caption)
                        .foregroundStyle(DoneColor.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            TaskChips(task: task)
        }
        .help(details)
    }

    var details: String {
        var parts = [model.listName(for: task)]
        let steps = model.index.children(of: task.id).count
        if steps > 0 { parts.append("\(steps) étape\(steps > 1 ? "s" : "")") }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

/// Recherche dans toutes les tâches ouvertes.
struct TaskPickerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let title: String
    let onPick: (TodoTask) -> Void
    @State private var query = ""
    @State private var hovered: String?
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DoneSpace.s16) {
            Text(title)
                .doneText(.displayM)
                .foregroundStyle(DoneColor.textPrimary)
            TextField("Rechercher une tâche ou un projet", text: $query)
                .focused($searchFocused)
                .doneField(focused: searchFocused)
            ScrollView {
                LazyVStack(spacing: DoneSpace.s2) {
                    ForEach(model.pickableTasks(matching: query)) { task in
                        Button {
                            dismiss()
                            onPick(task)
                        } label: {
                            TaskRowContent(task: task)
                                .padding(.horizontal, DoneSpace.s12)
                                .frame(minHeight: 48)
                                .background(hovered == task.id ? DoneColor.surfaceHover : Color.clear, in: RoundedRectangle(cornerRadius: DoneRadius.md, style: .continuous))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .onHover { inside in hovered = inside ? task.id : (hovered == task.id ? nil : hovered) }
                    }
                }
                .padding(6)
            }
            .doneCard()
            HStack {
                Spacer()
                Button("Annuler") { dismiss() }
                    .buttonStyle(DoneButtonStyle())
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(DoneSpace.s24)
        .frame(width: 600, height: 540)
        .background(DoneColor.bgCanvas)
        .onAppear { searchFocused = true }
    }
}

// MARK: Note de reprise

/// Champ « Où tu en es ? », enregistré au fil de la frappe dans la note de reprise de la tâche.
struct ResumeNoteField: View {
    @Environment(AppModel.self) private var model
    let taskID: String
    var placeholder = "Où tu en es ? Une ligne pour reprendre plus vite"
    var focused: FocusState<Bool>.Binding

    @State private var text = ""
    @State private var loaded = false

    var body: some View {
        TextField(placeholder, text: $text)
            .multilineTextAlignment(.leading)
            .focused(focused)
            .onSubmit { focused.wrappedValue = false }
            .doneField(focused: focused.wrappedValue)
            .onAppear {
                guard !loaded else { return }
                text = model.resumeNote(for: taskID)?.text ?? ""
                loaded = true
            }
            .onChange(of: text) {
                if loaded { model.setResumeNote(text, for: taskID) }
            }
    }
}

/// Rappel de la note de reprise, quand la tâche revient sur l'écran Focus.
struct ResumeNoteCard: View {
    let note: ResumeNote

    var body: some View {
        VStack(alignment: .leading, spacing: DoneSpace.s4) {
            Eyebrow(text: "Où tu en étais · \(Format.moment(note.writtenAt))")
            Text(note.text)
                .doneText(.body)
                .foregroundStyle(DoneColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, DoneSpace.s16)
        .padding(.vertical, DoneSpace.s12)
        .frame(maxWidth: 520, alignment: .leading)
        .doneCard()
    }
}
