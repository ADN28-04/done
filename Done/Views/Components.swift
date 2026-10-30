import SwiftUI

/// Badge de priorité : contour et fond teinté de la couleur de la priorité, chiffres en DM Mono.
struct PriorityBadge: View {
    let task: TodoTask

    var body: some View {
        let color = Theme.priority(task.priority)
        Text("P\(task.priority)")
            .font(.mono(10))
            .foregroundStyle(Theme.label)
            .padding(.horizontal, 5)
            .frame(height: 16)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(color, lineWidth: 1))
    }
}

/// Contenu d'une ligne de tâche : badge, titre et, au besoin, une ligne de détails.
struct TaskRowContent: View {
    @Environment(AppModel.self) private var model
    let task: TodoTask
    var showDetails = true

    var body: some View {
        HStack(spacing: 12) {
            PriorityBadge(task: task)
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.text(14))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if showDetails, !details.isEmpty {
                    Text(details)
                        .font(.text(12))
                        .foregroundStyle(Theme.label2)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .help(details)
    }

    var details: String {
        var parts = [model.projectName(for: task)]
        if let due = Format.due(task) { parts.append(due) }
        let subtasks = model.index.children(of: task.id).count
        if subtasks > 0 { parts.append("\(subtasks) étape\(subtasks > 1 ? "s" : "")") }
        if task.kind != .normal { parts.append(task.kind.label) }
        if task.isBlocked { parts.append("Bloquée") }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.display(22))
            TextField("Rechercher une tâche ou un projet", text: $query)
                .textFieldStyle(.plain)
                .font(.text(14))
                .padding(.horizontal, 14)
                .frame(height: 40)
                .surface(radius: 12)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.pickableTasks(matching: query)) { task in
                        Button {
                            dismiss()
                            onPick(task)
                        } label: {
                            TaskRowContent(task: task)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(hovered == task.id ? Theme.fill : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .onHover { inside in hovered = inside ? task.id : (hovered == task.id ? nil : hovered) }
                    }
                }
                .padding(6)
            }
            .surface(radius: 18)
            HStack {
                Spacer()
                Button("Annuler") { dismiss() }
                    .buttonStyle(PillButtonStyle())
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(width: 600, height: 540)
        .background(Backdrop(style: .wash))
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
            .textFieldStyle(.plain)
            .font(.text(14))
            .multilineTextAlignment(.leading)
            .focused(focused)
            .onSubmit { focused.wrappedValue = false }
            .padding(.horizontal, 14)
            .frame(height: 40)
            .surface(radius: 12)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.ring.opacity(focused.wrappedValue ? 0.45 : 0), lineWidth: 2)
            )
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
        VStack(spacing: 6) {
            Eyebrow(text: "Où tu en étais · \(Format.moment(note.writtenAt))")
            Text(note.text)
                .font(.text(15))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: 520)
        .surface(radius: 14)
    }
}
