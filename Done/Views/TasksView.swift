import SwiftUI

/// Onglet Tâches : l'Inbox et les projets à gauche, la liste choisie à droite.
struct TasksView: View {
    @Environment(AppModel.self) private var model

    /// Liste affichée : `nil` pour l'Inbox.
    @State private var selectedID: String?
    @State private var newTitle = ""
    @FocusState private var addFocused: Bool
    @State private var hovered: String?
    @State private var dropTarget: String?
    @State private var showCompleted = false
    @State private var editing: TodoTask?
    @State private var breakdownTask: TodoTask?
    @State private var deleting: TodoTask?
    @State private var naming: Naming?
    @State private var projectNameDraft = ""
    @State private var deletingProject: Project?

    private enum Naming: Identifiable {
        case new
        case rename(Project)

        var id: String {
            switch self {
            case .new: "new"
            case .rename(let project): project.id
            }
        }
    }

    /// Une ligne de la liste, avec son niveau d'indentation.
    private struct Row: Identifiable {
        let task: TodoTask
        let depth: Int
        var id: String { task.id }
    }

    /// La liste choisie, ou l'Inbox si son projet a été supprimé.
    private var listID: String? {
        model.project(selectedID) == nil ? nil : selectedID
    }

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            listsColumn
                .frame(width: 220)
            taskColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.leading, 32)
        .padding(.trailing, 40)
        .padding(.top, 4)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(item: $editing) { task in
            TaskEditorSheet(taskID: task.id)
                .environment(model)
        }
        .sheet(item: $breakdownTask) { task in
            BreakdownSheet(task: task)
                .environment(model)
        }
    }

    // MARK: Listes

    private var listsColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "Listes")
                .padding(.leading, 2)
            VStack(spacing: 2) {
                listRow(id: nil, name: "Inbox", symbol: "tray")
                ForEach(model.projects) { project in
                    listRow(id: project.id, name: project.name, symbol: "folder")
                        .contextMenu {
                            Button("Renommer…") {
                                projectNameDraft = project.name
                                naming = .rename(project)
                            }
                            Button("Monter") { model.shiftProject(project.id, by: -1) }
                                .disabled(project.id == model.projects.first?.id)
                            Button("Descendre") { model.shiftProject(project.id, by: 1) }
                                .disabled(project.id == model.projects.last?.id)
                            Divider()
                            Button("Supprimer le projet…", role: .destructive) { deletingProject = project }
                        }
                }
            }
            .padding(6)
            .surface(radius: 18)
            Button {
                projectNameDraft = ""
                naming = .new
            } label: {
                Label("Nouveau projet", systemImage: "plus")
            }
            .buttonStyle(PillButtonStyle(kind: .plain, size: .mini))
            Text("Glisse une tâche sur une liste pour l'y ranger.")
                .font(.text(12))
                .foregroundStyle(Theme.label3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 2)
        }
        .alert(naming.map(namingTitle) ?? "", isPresented: Binding(get: { naming != nil }, set: { if !$0 { naming = nil } })) {
            TextField("Nom du projet", text: $projectNameDraft)
            Button("Annuler", role: .cancel) { naming = nil }
            Button(naming.map(namingAction) ?? "OK") { commitNaming() }
        }
        .confirmationDialog(
            "Supprimer le projet « \(deletingProject?.name ?? "") » ?",
            isPresented: Binding(get: { deletingProject != nil }, set: { if !$0 { deletingProject = nil } }),
            presenting: deletingProject
        ) { project in
            Button("Supprimer le projet", role: .destructive) {
                model.deleteProject(project.id)
                deletingProject = nil
            }
        } message: { project in
            let count = model.openCount(in: project.id)
            Text(count == 0 ? "Il ne contient aucune tâche ouverte." : "Ses \(count) tâche\(count > 1 ? "s" : "") passe\(count > 1 ? "nt" : "") dans l'Inbox.")
        }
    }

    private func listRow(id: String?, name: String, symbol: String) -> some View {
        let key = "list-" + (id ?? "inbox")
        let isSelected = listID == id
        let count = model.openCount(in: id)
        let background = isSelected ? Theme.selection : (hovered == key ? Theme.fill : Color.clear)
        return Button {
            selectedID = id
            showCompleted = false
        } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 16)
                Text(name)
                    .font(.text(14, isSelected ? .semibold : .regular))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if count > 0 {
                    Text("\(count)")
                        .font(.mono(12))
                        .foregroundStyle(isSelected ? Theme.accentText : Theme.label3)
                }
            }
            .foregroundStyle(isSelected ? Theme.accentText : Theme.label)
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Theme.ring, lineWidth: dropTarget == key ? 2 : 0)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { inside in setHovered(key, inside) }
        .dropDestination(for: String.self) { ids, _ in
            for taskID in ids {
                edit(taskID) { task in
                    if task.parentID == nil { task.projectID = id }
                }
            }
            return true
        } isTargeted: { targeted in
            setDropTarget(key, targeted)
        }
    }

    private func namingTitle(_ naming: Naming) -> String {
        switch naming {
        case .new: "Nouveau projet"
        case .rename: "Renommer le projet"
        }
    }

    private func namingAction(_ naming: Naming) -> String {
        switch naming {
        case .new: "Créer"
        case .rename: "Renommer"
        }
    }

    private func commitNaming() {
        switch naming {
        case .new:
            if let project = model.addProject(named: projectNameDraft) { selectedID = project.id }
        case .rename(let project):
            model.renameProject(project.id, to: projectNameDraft)
        case nil:
            break
        }
        naming = nil
    }

    // MARK: Tâches

    private var taskColumn: some View {
        let tasks = model.topLevelTasks(in: listID)
        let rows = flattened(tasks)
        let completed = model.completedTasks(in: listID, limit: 30)
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(model.projectName(listID))
                    .font(.display(30, bold: true))
                    .tracking(-0.45)
                Text(subtitle(count: tasks.count))
                    .font(.text(15))
                    .foregroundStyle(Theme.label2)
            }
            addField
                .padding(.top, 20)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if rows.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 0) {
                            ForEach(rows) { row in
                                taskRow(row.task, depth: row.depth)
                            }
                        }
                        .padding(6)
                        .surface(radius: 18)
                    }
                    if !completed.isEmpty {
                        completedSection(completed)
                    }
                }
                .padding(.top, 14)
                .padding(.bottom, 2)
            }
            .scrollIndicators(.never)
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

    private var addField: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.accentText)
            TextField("Ajouter une tâche dans « \(model.projectName(listID)) »", text: $newTitle)
                .textFieldStyle(.plain)
                .font(.text(14))
                .focused($addFocused)
                .onSubmit(addTask)
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .surface(radius: 12)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.ring.opacity(addFocused ? 0.45 : 0), lineWidth: 2)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text(listID == nil ? "Inbox vide" : "Rien à faire ici")
                .font(.text(14, .semibold))
            Text(listID == nil ? "Note ici tout ce qui te passe par la tête, puis range-le dans un projet." : "Ajoute la première tâche de ce projet dans le champ ci-dessus.")
                .font(.text(13))
                .foregroundStyle(Theme.label2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .surface(radius: 18)
    }

    private func taskRow(_ task: TodoTask, depth: Int) -> some View {
        let inPlan = model.planIDs.contains(task.id)
        return HStack(spacing: 12) {
            CheckCircle(priority: task.priority, isDone: false) { model.complete(task) }
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.text(14))
                    .foregroundStyle(task.isBlocked ? Theme.label2 : Theme.label)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let line = details(task) {
                    line
                        .font(.text(12))
                        .foregroundStyle(Theme.label2)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if inPlan {
                Text("Aujourd'hui")
                    .font(.mono(11))
                    .foregroundStyle(Theme.accentText)
                    .padding(.horizontal, 8)
                    .frame(height: 20)
                    .background(Theme.accentTint, in: Capsule())
                    .help("Dans le plan du jour")
            }
        }
        .padding(.leading, 12 + CGFloat(depth) * 28)
        .padding(.trailing, 12)
        .padding(.vertical, 9)
        .background(hovered == task.id ? Theme.fill : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.ring, lineWidth: dropTarget == task.id ? 2 : 0)
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

    /// Échéance, étapes, type, blocage et notes, en une ligne.
    private func details(_ task: TodoTask) -> Text? {
        var parts: [Text] = []
        if let due = Format.due(task) {
            let late = task.due.map { $0 < Calendar.current.startOfDay(for: .now) } ?? false
            parts.append(Text(due).foregroundStyle(late ? Theme.orangeText : Theme.label2))
        }
        let steps = model.index.children(of: task.id).count
        if steps > 0 { parts.append(Text("\(steps) étape\(steps > 1 ? "s" : "")")) }
        if task.kind != .normal { parts.append(Text(task.kind.label)) }
        if task.isBlocked { parts.append(Text("Bloquée").foregroundStyle(Theme.orangeText)) }
        if !task.notes.isEmpty { parts.append(Text(Image(systemName: "text.alignleft"))) }
        guard let first = parts.first else { return nil }
        return parts.dropFirst().reduce(first) { $0 + Text(" · ") + $1 }
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
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showCompleted.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showCompleted ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.label2)
                    Eyebrow(text: "Terminées récemment · \(tasks.count)")
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 2)
            if showCompleted {
                VStack(spacing: 0) {
                    ForEach(tasks) { task in
                        HStack(spacing: 12) {
                            CheckCircle(priority: task.priority, isDone: true) { model.reopen(task) }
                            Text(task.title)
                                .font(.text(14))
                                .strikethrough(true, color: Theme.label3)
                                .foregroundStyle(Theme.label2)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if let done = task.completedAt {
                                Text(Format.moment(done))
                                    .font(.text(12))
                                    .foregroundStyle(Theme.label3)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                }
                .padding(6)
                .surface(radius: 18)
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

/// Case ronde à cocher, du contour de la couleur de priorité.
struct CheckCircle: View {
    let priority: Int
    let isDone: Bool
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        let color = Theme.priority(priority)
        Button(action: action) {
            Circle()
                .fill(isDone ? color : color.opacity(hovered ? 0.15 : 0))
                .overlay(Circle().strokeBorder(color, lineWidth: 1.5))
                .overlay {
                    if isDone || hovered {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(isDone ? Color.white : color)
                    }
                }
                .frame(width: 18, height: 18)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help(isDone ? "Rouvrir" : "Cocher")
    }
}
