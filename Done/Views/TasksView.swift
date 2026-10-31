import SwiftUI

/// Une liste de tâches : l'Inbox ou un projet, choisi dans la barre latérale.
struct TaskListView: View {
    @Environment(AppModel.self) private var model
    /// `nil` pour l'Inbox.
    let projectID: String?

    @State private var newTitle = ""
    @FocusState private var addFocused: Bool
    @State private var hovered: String?
    @State private var dropTarget: String?
    @State private var showCompleted = false
    @State private var editing: TodoTask?
    @State private var breakdownTask: TodoTask?
    @State private var deleting: TodoTask?
    @State private var showDetails = false

    /// Une ligne, avec son niveau d'indentation.
    private struct Row: Identifiable {
        let task: TodoTask
        let depth: Int
        var id: String { task.id }
    }

    /// La liste demandée, ou l'Inbox si son projet a été supprimé.
    private var listID: String? {
        model.project(projectID) == nil ? nil : projectID
    }

    var body: some View {
        let tasks = model.topLevelTasks(in: listID)
        let rows = flattened(tasks)
        let completed = model.completedTasks(in: listID, limit: 30)
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: DoneSpace.s4) {
                Text(model.projectName(listID))
                    .doneText(.displayL)
                    .foregroundStyle(DoneColor.textPrimary)
                Text(subtitle(count: tasks.count))
                    .doneText(.body)
                    .foregroundStyle(DoneColor.textSecondary)
            }
            addField
                .padding(.top, DoneSpace.s20)
            ScrollView {
                VStack(alignment: .leading, spacing: DoneSpace.s20) {
                    if rows.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: DoneSpace.s2) {
                            ForEach(rows) { row in
                                taskRow(row.task, depth: row.depth)
                            }
                        }
                        .padding(DoneSpace.s6)
                        .doneCard(radius: DoneRadius.lg)
                    }
                    if !completed.isEmpty {
                        completedSection(completed)
                    }
                }
                .padding(.top, DoneSpace.s16)
                .padding(.bottom, DoneSpace.s4)
            }
            .scrollIndicators(.never)
        }
        .frame(maxWidth: 820, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, DoneSpace.s40)
        .padding(.top, DoneSpace.s4)
        .padding(.bottom, DoneSpace.s24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(item: $editing) { task in
            TaskEditorSheet(taskID: task.id)
                .environment(model)
        }
        .sheet(item: $breakdownTask) { task in
            BreakdownSheet(task: task)
                .environment(model)
        }
        .confirmationDialog(
            "Supprimer « \(deleting?.title ?? "") » ?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            presenting: deleting
        ) { task in
            Button("Supprimer", role: .destructive) {
                model.delete(task)
                deleting = nil
            }
        } message: { task in
            Text(model.index.children(of: task.id).isEmpty ? "C'est définitif." : "Ses étapes aussi. C'est définitif.")
        }
    }

    // MARK: Saisie

    private var addField: some View {
        HStack(spacing: DoneSpace.s8) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DoneColor.stateActiveText)
            TextField("Ajouter une tâche dans « \(model.projectName(listID)) »", text: $newTitle)
                .textFieldStyle(.plain)
                .focused($addFocused)
                .onSubmit(addTask)
            Button("Détails…") { showDetails = true }
                .buttonStyle(DoneButtonStyle(kind: .plain, compact: true))
                .help("Saisir la tâche avec sa priorité, son type, son échéance, ses notes et ses étapes")
        }
        .doneField(focused: addFocused, height: 36)
        .sheet(isPresented: $showDetails) {
            CaptureSheet(draft: TaskDraft(title: newTitle, projectID: listID)) { newTitle = "" }
                .environment(model)
        }
    }

    private var emptyState: some View {
        VStack(spacing: DoneSpace.s6) {
            Text(listID == nil ? "Inbox vide" : "Rien à faire ici")
                .doneText(.title)
                .foregroundStyle(DoneColor.textPrimary)
            Text(listID == nil ? "Note ici tout ce qui te passe par la tête, puis range-le dans un projet." : "Ajoute la première tâche de ce projet dans le champ ci-dessus.")
                .doneText(.callout)
                .foregroundStyle(DoneColor.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DoneSpace.s48)
        .overlay(
            RoundedRectangle(cornerRadius: DoneRadius.lg, style: .continuous)
                .strokeBorder(DoneColor.stateWaiting, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        )
    }

    // MARK: Lignes

    /// Ligne de tâche : hauteur 48, rayon 10. Au survol, fond surface.hover et poignée de déplacement.
    private func taskRow(_ task: TodoTask, depth: Int) -> some View {
        let isHovered = hovered == task.id
        let inPlan = model.planIDs.contains(task.id)
        return HStack(spacing: DoneSpace.s12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DoneColor.textDisabled)
                .frame(width: 10)
                .opacity(isHovered ? 1 : 0)
            TaskCheckbox(isDone: false) { model.complete(task) }
            VStack(alignment: .leading, spacing: DoneSpace.s2) {
                Text(task.title)
                    .doneText(.bodyStrong)
                    .foregroundStyle(task.isBlocked ? DoneColor.textSecondary : DoneColor.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let line = details(task) {
                    Text(line)
                        .doneText(.caption)
                        .foregroundStyle(DoneColor.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if inPlan {
                StateChip(kind: .active, title: "Aujourd'hui")
                    .help("Dans le plan du jour")
            }
            TaskChips(task: task)
        }
        .padding(.leading, DoneSpace.s4 + CGFloat(depth) * 28)
        .padding(.trailing, DoneSpace.s12)
        .frame(minHeight: 48)
        .background(isHovered ? DoneColor.surfaceHover : Color.clear, in: RoundedRectangle(cornerRadius: DoneRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DoneRadius.md, style: .continuous)
                .strokeBorder(DoneColor.focusRing, lineWidth: dropTarget == task.id ? 2 : 0)
        )
        .contentShape(Rectangle())
        .onTapGesture { editing = task }
        .onHover { inside in setHovered(task.id, inside) }
        .draggable(task.id)
        .dropDestination(for: String.self) { ids, _ in
            ids.forEach { model.move($0, before: task.id) }
            return true
        } isTargeted: { targeted in
            setDropTarget(task.id, targeted)
        }
        .contextMenu { menu(for: task) }
        .help("Cliquer pour ouvrir la tâche")
    }

    /// Étapes et notes, en une ligne. L'échéance, la durée et le blocage sont dans les puces.
    private func details(_ task: TodoTask) -> String? {
        var parts: [String] = []
        let steps = model.index.children(of: task.id).count
        if steps > 0 { parts.append("\(steps) étape\(steps > 1 ? "s" : "")") }
        if !task.notes.isEmpty { parts.append("Notes") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func menu(for task: TodoTask) -> some View {
        Button("Ouvrir…") { editing = task }
        Button("Ajouter au plan du jour") { model.addToPlan(task.id) }
            .disabled(model.planIDs.contains(task.id) || model.planIDs.count >= Rules.maxPlanSize)
        Button("Découper en étapes…") { breakdownTask = task }
        Divider()
        Menu("Échéance") {
            Button("Aujourd'hui") { setDue(task, inDays: 0) }
            Button("Demain") { setDue(task, inDays: 1) }
            Button("Dans une semaine") { setDue(task, inDays: 7) }
            Button("Sans échéance") { setDue(task, inDays: nil) }
        }
        Menu("Priorité") {
            ForEach(1...4, id: \.self) { priority in
                Button("P\(priority)") { edit(task.id) { $0.priority = priority } }
            }
        }
        Menu("Type") {
            ForEach(TaskKind.allCases) { kind in
                Button(kind.label) { edit(task.id) { $0.kind = kind } }
            }
        }
        if task.parentID == nil {
            Menu("Déplacer vers") {
                Button("Inbox") { edit(task.id) { $0.projectID = nil } }
                    .disabled(task.projectID == nil)
                ForEach(model.projects) { project in
                    Button(project.name) { edit(task.id) { $0.projectID = project.id } }
                        .disabled(task.projectID == project.id)
                }
            }
        }
        Button(task.isBlocked ? "Débloquer" : "Marquer comme bloquée") {
            edit(task.id) { $0.isBlocked.toggle() }
        }
        Divider()
        Button("Supprimer…", role: .destructive) { deleting = task }
    }

    private func completedSection(_ tasks: [TodoTask]) -> some View {
        VStack(alignment: .leading, spacing: DoneSpace.s8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showCompleted.toggle() }
            } label: {
                HStack(spacing: DoneSpace.s6) {
                    Image(systemName: showCompleted ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DoneColor.textSecondary)
                    Eyebrow(text: "Terminées récemment · \(tasks.count)")
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.leading, DoneSpace.s4)
            if showCompleted {
                VStack(spacing: DoneSpace.s2) {
                    ForEach(tasks) { task in
                        HStack(spacing: DoneSpace.s12) {
                            TaskCheckbox(isDone: true) { model.reopen(task) }
                            Text(task.title)
                                .doneText(.bodyStrong)
                                .strikethrough(true, color: DoneColor.stateOnDone)
                                .foregroundStyle(DoneColor.stateOnDone)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if let done = task.completedAt {
                                Text(Format.moment(done))
                                    .doneText(.caption)
                                    .foregroundStyle(DoneColor.textSecondary)
                            }
                        }
                        .padding(.horizontal, DoneSpace.s12)
                        .frame(minHeight: 44)
                    }
                }
                .padding(DoneSpace.s6)
                .background(DoneColor.stateDone, in: RoundedRectangle(cornerRadius: DoneRadius.lg, style: .continuous))
            }
        }
    }

    // MARK: Aides

    private func flattened(_ tasks: [TodoTask], depth: Int = 0) -> [Row] {
        tasks.flatMap { task -> [Row] in
            let children = depth < 6 ? flattened(model.index.children(of: task.id), depth: depth + 1) : []
            return [Row(task: task, depth: depth)] + children
        }
    }

    private func subtitle(count: Int) -> String {
        switch count {
        case 0: "Rien d'ouvert"
        case 1: "1 tâche ouverte"
        default: "\(count) tâches ouvertes"
        }
    }

    private func addTask() {
        guard model.addTask(newTitle, projectID: listID) != nil else { return }
        newTitle = ""
        addFocused = true
    }

    /// Modifie la version à jour de la tâche, pas une copie peut-être périmée.
    private func edit(_ id: String, _ change: (inout TodoTask) -> Void) {
        guard var task = model.store[id] else { return }
        change(&task)
        model.update(task)
    }

    private func setDue(_ task: TodoTask, inDays days: Int?) {
        let day = days.flatMap { Calendar.current.date(byAdding: .day, value: $0, to: Calendar.current.startOfDay(for: .now)) }
        edit(task.id) { $0.due = day }
    }

    private func setHovered(_ key: String, _ inside: Bool) {
        if inside {
            hovered = key
        } else if hovered == key {
            hovered = nil
        }
    }

    private func setDropTarget(_ key: String, _ targeted: Bool) {
        if targeted {
            dropTarget = key
        } else if dropTarget == key {
            dropTarget = nil
        }
    }
}
