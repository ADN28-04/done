import SwiftUI

struct PriorityBadge: View {
    let task: TodoistTask

    var body: some View {
        Text("P\(task.displayPriority)")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .foregroundStyle(.white)
            .background(color, in: Capsule())
    }

    private var color: Color {
        switch task.displayPriority {
        case 1: .red
        case 2: .orange
        case 3: .blue
        default: .gray
        }
    }
}

/// Ligne de tâche : priorité, titre, projet, échéance, sous-tâches et labels.
struct TaskRow: View {
    @Environment(AppModel.self) private var model
    let task: TodoistTask

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            PriorityBadge(task: task)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.content)
                    .lineLimit(2)
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
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

struct StatTile: View {
    let title: String
    let value: String
    var detail: String?
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold).monospacedDigit())
                .foregroundStyle(tint)
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(minWidth: 140, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct Card<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Réunions et blocs du jour, en bandeau horizontal.
struct AgendaStrip: View {
    let meetings: [Meeting]

    var body: some View {
        if meetings.isEmpty {
            Label("Aucune réunion aujourd'hui dans Todoist", systemImage: "calendar")
                .font(.callout)
                .foregroundStyle(.secondary)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(meetings) { meeting in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(Format.time(meeting.start))–\(Format.time(meeting.end))")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Label(meeting.title, systemImage: meeting.isFocusBlock ? "brain.head.profile" : "person.2")
                                .font(.callout)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            (meeting.isFocusBlock ? Color.accentColor : Color.secondary).opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .opacity(meeting.end < .now ? 0.45 : 1)
                    }
                }
            }
        }
    }
}

/// Recherche dans toutes les tâches ouvertes.
struct TaskPickerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let title: String
    let onPick: (TodoistTask) -> Void
    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            TextField("Rechercher une tâche ou un projet", text: $query)
                .textFieldStyle(.roundedBorder)
            List(model.pickableTasks(matching: query)) { task in
                Button {
                    dismiss()
                    onPick(task)
                } label: {
                    TaskRow(task: task)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listStyle(.inset)
            HStack {
                Spacer()
                Button("Annuler") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 580, height: 520)
    }
}
