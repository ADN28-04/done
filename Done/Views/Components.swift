import SwiftUI

/// Badge de priorité : contour et fond teinté de la couleur Todoist.
struct PriorityBadge: View {
    let task: TodoistTask

    var body: some View {
        let color = Theme.priority(task.displayPriority)
        Text("P\(task.displayPriority)")
            .font(.system(size: 10, weight: .semibold).monospacedDigit())
            .foregroundStyle(Theme.label)
            .padding(.horizontal, 5)
            .frame(height: 16)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(color, lineWidth: 1))
    }
}

/// Contenu d'une ligne de tâche : badge, titre et ligne de détails.
struct TaskRowContent: View {
    @Environment(AppModel.self) private var model
    let task: TodoistTask
    var emphasized = false

    var body: some View {
        HStack(spacing: 12) {
            PriorityBadge(task: task)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.content)
                    .font(.system(size: 13, weight: emphasized ? .medium : .regular))
                    .foregroundStyle(Theme.label)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if !details.isEmpty {
                    Text(details)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.label2)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var details: String {
        var parts = [model.projectName(for: task)]
        if let due = Format.due(task) { parts.append(due) }
        let subtasks = model.index.children(of: task.id).count
        if subtasks > 0 { parts.append("\(subtasks) sous-tâche\(subtasks > 1 ? "s" : "")") }
        parts += task.labels.map { "@\($0)" }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

/// Créneaux du jour, avec un repère pour l'heure actuelle.
struct AgendaStrip: View {
    let meetings: [Meeting]
    var now: Date = .now

    var body: some View {
        if meetings.isEmpty {
            Text("Aucune réunion aujourd'hui dans Todoist")
                .font(.system(size: 13))
                .foregroundStyle(Theme.label2)
        } else {
            let nowIndex = meetings.firstIndex { $0.start > now } ?? meetings.count
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center, spacing: 8) {
                    ForEach(Array(meetings.enumerated()), id: \.element.id) { offset, meeting in
                        if offset == nowIndex { nowMarker }
                        chip(meeting)
                    }
                    if nowIndex == meetings.count { nowMarker }
                }
                .fixedSize()
            }
        }
    }

    private var nowMarker: some View {
        VStack(spacing: 4) {
            Text(Format.time(now))
                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.label2)
            Capsule()
                .fill(Theme.label2)
                .frame(width: 2, height: 30)
        }
        .padding(.horizontal, 2)
    }

    private func chip(_ meeting: Meeting) -> some View {
        let isPast = meeting.end <= now
        return VStack(alignment: .leading, spacing: 2) {
            Text("\(Format.time(meeting.start))–\(Format.time(meeting.end))")
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(meeting.isFocusBlock ? Theme.accentText : Theme.label2)
            Text(meeting.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(meeting.isFocusBlock ? Theme.accentText : Theme.label)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(meeting.isFocusBlock ? Theme.accentTint : Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(meeting.isFocusBlock ? Color.clear : Theme.separator, lineWidth: 1)
        )
        .opacity(isPast ? 0.45 : 1)
    }
}

/// Recherche dans toutes les tâches ouvertes.
struct TaskPickerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let title: String
    let onPick: (TodoistTask) -> Void
    @State private var query = ""
    @State private var hovered: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.label)
            TextField("Rechercher une tâche ou un projet", text: $query)
                .textFieldStyle(.roundedBorder)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.pickableTasks(matching: query)) { task in
                        Button {
                            dismiss()
                            onPick(task)
                        } label: {
                            TaskRowContent(task: task)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(hovered == task.id ? Theme.fill : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .onHover { inside in hovered = inside ? task.id : (hovered == task.id ? nil : hovered) }
                    }
                }
                .padding(4)
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            HStack {
                Spacer()
                Button("Annuler") { dismiss() }
                    .buttonStyle(PillButtonStyle())
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 580, height: 520)
        .background(Theme.background)
    }
}
