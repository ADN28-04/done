import Foundation

/// Les outils du connecteur Claude. Claude lit tout ; il crée et modifie tâches, projets, étiquettes,
/// notes, réunions, absences et plan du jour. Il ne supprime jamais rien.
struct ConnectorTools {
    let workspace: any ConnectorWorkspace
    let clock: () -> Date

    init(workspace: any ConnectorWorkspace, clock: @escaping () -> Date = { .now }) {
        self.workspace = workspace
        self.clock = clock
    }

    private var calendar: Calendar { .current }

    var server: MCPServer {
        MCPServer(name: "done", version: "1.0", instructions: Self.instructions, tools: Self.catalog) { name, arguments in
            try call(name, arguments)
        }
    }

    func call(_ name: String, _ values: [String: JSONValue]) throws -> JSONValue {
        let args = ToolArguments(values)
        switch name {
        case "get_overview": return try overview()
        case "list_tasks": return try listTasks(args)
        case "get_task": return try getTask(args)
        case "list_projects": return try listProjects()
        case "get_calendar": return try calendarDays(args)
        case "list_notes": return try listNotes(args)
        case "read_note": return try readNote(args)
        case "create_task": return try createTask(args)
        case "update_task": return try updateTask(args)
        case "complete_task": return try completeTask(args)
        case "reopen_task": return try reopenTask(args)
        case "create_project": return try createProject(args)
        case "update_project": return try updateProject(args)
        case "rename_tag": return try renameTag(args)
        case "create_note": return try createNote(args)
        case "update_note": return try updateNote(args)
        case "add_meeting": return try addMeeting(args)
        case "update_meeting": return try updateMeeting(args)
        case "set_absence": return try setAbsence(args)
        case "set_today_plan": return try setTodayPlan(args)
        default: throw ToolFailure("Outil inconnu : \(name)")
        }
    }

    // MARK: Lecture

    private func overview() throws -> JSONValue {
        let store = try workspace.loadTasks()
        let notes = workspace.loadNotes()
        let now = clock()
        let today = Format.dayKey(now)
        let plan = SharedPlan.current(snapshot: workspace.planSnapshot(), request: workspace.planRequest(), day: today)
        var fields: [String: JSONValue] = [
            "today": .string(today),
            "weekday": .string(Format.longDay(now)),
            "time": .string(Format.time(now)),
        ]
        if let absence = store.absence(on: now) { fields["absence"] = .string(absence.title) }
        var planFields: [String: JSONValue] = [
            "tasks": .array(plan.taskIDs.compactMap { store[$0] }.map { .object(taskFields($0, in: store, now: now)) }),
            "max_size": .int(Rules.maxPlanSize),
        ]
        if !plan.doneIDs.isEmpty {
            planFields["done"] = .array(plan.doneIDs.compactMap { store[$0] }.map(taskRef))
        }
        if plan.pending { planFields["waiting_for_done_app"] = true }
        fields["plan"] = .object(planFields)
        let due = WorkWeek.dueTasks(on: now, in: store.openTasks, today: now)
            .filter { !plan.taskIDs.contains($0.id) }
            .sorted(by: Planner.priorityOrder)
        fields["due_or_late"] = .array(due.map { .object(taskFields($0, in: store, now: now)) })
        fields["meetings_today"] = .array(store.meetings(on: now).map { meetingFields($0, notes: notes, store: store) })
        let done = DayAgenda.doneToday(in: store.tasks, today: now)
        if !done.isEmpty { fields["done_today"] = .array(done.prefix(30).map(taskRef)) }
        let topLevel = store.openTasks.filter { $0.parentID == nil }
        fields["inbox_open"] = .int(topLevel.filter { store.contains($0, in: .inbox) }.count)
        fields["open_tasks"] = .int(topLevel.count)
        if let journal = notes.first(where: { $0.kind == .journal && ($0.date.map { calendar.isDate($0, inSameDayAs: now) } ?? false) }) {
            fields["journal_note"] = noteRef(journal)
        }
        return .object(fields)
    }

    private func listTasks(_ args: ToolArguments) throws -> JSONValue {
        let store = try workspace.loadTasks()
        let now = clock()
        var lists: [TaskList] = []
        if let reference = try args.string("project"), !reference.isEmpty {
            lists.append(ConnectorFormat.isInbox(reference) ? .inbox : .project(try ConnectorFormat.project(reference, in: store).id))
        }
        if let name = try args.string("tag"), !name.isEmpty {
            lists.append(.tag(try ConnectorFormat.tag(name, in: store)))
        }
        if try args.bool("inbox") == true { lists.append(.inbox) }
        let status = try args.string("status") ?? "open"
        guard ["open", "done", "all"].contains(status) else {
            throw ToolFailure("« status » vaut open, done ou all.")
        }
        let dueBefore = try args.string("due_before").map { try ConnectorFormat.day($0, field: "due_before", now: now) }
        let doneSince = try args.string("done_since").map { try ConnectorFormat.day($0, field: "done_since", now: now) }
        let words = (try args.string("query") ?? "").split(whereSeparator: \.isWhitespace).map(String.init)
        let limit = min(max(try args.int("limit") ?? 100, 1), 500)

        var tasks = store.tasks.filter { $0.parentID == nil }
        switch status {
        case "open": tasks = tasks.filter(\.isOpen)
        case "done": tasks = tasks.filter { !$0.isOpen }
        default: break
        }
        for list in lists {
            tasks = tasks.filter { store.contains($0, in: list) }
        }
        if let dueBefore {
            tasks = tasks.filter { $0.due.map { $0 <= dueBefore } ?? false }
        }
        if let doneSince {
            tasks = tasks.filter { $0.completedAt.map { $0 >= doneSince } ?? false }
        }
        if !words.isEmpty {
            tasks = tasks.filter { task in
                let text = searchableText(task, in: store)
                return words.allSatisfy { text.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
            }
        }
        let open = tasks.filter(\.isOpen).sorted(by: Planner.priorityOrder)
        let closed = tasks.filter { !$0.isOpen }.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        let ordered = open + closed
        var fields: [String: JSONValue] = [
            "count": .int(ordered.count),
            "tasks": .array(ordered.prefix(limit).map { listEntry($0, in: store, now: now) }),
        ]
        if ordered.count > limit { fields["truncated"] = true }
        return .object(fields)
    }

    private func getTask(_ args: ToolArguments) throws -> JSONValue {
        let store = try workspace.loadTasks()
        let id = try args.required("id")
        guard let task = store[id] else { throw ToolFailure("Tâche introuvable : \(id). Cherche-la avec list_tasks.") }
        return taskDetail(task, in: store, notes: workspace.loadNotes())
    }

    private func listProjects() throws -> JSONValue {
        let store = try workspace.loadTasks()
        let notes = workspace.loadNotes()
        let topLevel = store.openTasks.filter { $0.parentID == nil }
        func openCount(_ list: TaskList) -> Int {
            topLevel.filter { store.contains($0, in: list) }.count
        }
        func entry(_ project: Project) -> [String: JSONValue] {
            var fields: [String: JSONValue] = [
                "id": .string(project.id),
                "name": .string(project.name),
                "open_tasks": .int(openCount(.project(project.id))),
            ]
            if let page = notes.first(where: { $0.kind == .project && $0.projectID == project.id }) {
                fields["page_note_id"] = .string(page.id)
            }
            return fields
        }
        let projects: [JSONValue] = store.topLevelProjects.map { project in
            var fields = entry(project)
            let children = store.subprojects(of: project.id)
            if !children.isEmpty { fields["subprojects"] = .array(children.map { .object(entry($0)) }) }
            return .object(fields)
        }
        let tags: [JSONValue] = store.tags.map { ["name": .string($0), "open_tasks": .int(openCount(.tag($0)))] }
        return ["inbox_open": .int(openCount(.inbox)), "projects": .array(projects), "tags": .array(tags)]
    }

    private func calendarDays(_ args: ToolArguments) throws -> JSONValue {
        let store = try workspace.loadTasks()
        let notes = workspace.loadNotes()
        let now = clock()
        let start = try args.string("start").map { try ConnectorFormat.day($0, field: "start", now: now) } ?? calendar.startOfDay(for: now)
        let count = min(max(try args.int("days") ?? 7, 1), 31)
        let days: [JSONValue] = (0..<count).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            var fields: [String: JSONValue] = [
                "date": .string(Format.dayKey(day)),
                "weekday": .string(Format.longDay(day)),
            ]
            if let absence = store.absence(on: day) { fields["absence"] = .string(absence.title) }
            let meetings = store.meetings(on: day)
            if !meetings.isEmpty { fields["meetings"] = .array(meetings.map { meetingFields($0, notes: notes, store: store) }) }
            let due = WorkWeek.dueTasks(on: day, in: store.openTasks, today: now).sorted(by: Planner.priorityOrder)
            if !due.isEmpty { fields["due"] = .array(due.map { .object(taskFields($0, in: store, now: now)) }) }
            return .object(fields)
        }
        return ["days": .array(days)]
    }

    private func listNotes(_ args: ToolArguments) throws -> JSONValue {
        var notes = workspace.loadNotes()
        if let kind = try ConnectorFormat.noteKind(args.string("kind")) {
            notes = notes.filter { $0.kind == kind }
        }
        var store: TaskStore?
        if let reference = try args.string("project"), !reference.isEmpty {
            let loaded = try workspace.loadTasks()
            store = loaded
            let family = loaded.projectFamily(try ConnectorFormat.project(reference, in: loaded).id)
            notes = notes.filter { $0.projectID.map(family.contains) ?? false }
        }
        if let tag = try args.string("tag"), !tag.isEmpty {
            let wanted = RemindersInbox.matchKey(tag)
            notes = notes.filter { $0.tags.contains { RemindersInbox.matchKey($0) == wanted } }
        }
        if let taskID = try args.string("task_id"), !taskID.isEmpty {
            notes = notes.filter { $0.taskIDs.contains(taskID) }
        }
        let words = (try args.string("query") ?? "").split(whereSeparator: \.isWhitespace).map(String.init)
        if !words.isEmpty {
            notes = notes.filter { note in
                let text = note.title + "\n" + note.body + "\n" + note.tags.joined(separator: " ")
                return words.allSatisfy { text.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
            }
        }
        let limit = min(max(try args.int("limit") ?? 50, 1), 300)
        notes.sort { $0.updatedAt > $1.updatedAt }
        let tasks = store ?? (try? workspace.loadTasks())
        var fields: [String: JSONValue] = [
            "count": .int(notes.count),
            "notes": .array(notes.prefix(limit).map { noteSummary($0, store: tasks) }),
        ]
        if notes.count > limit { fields["truncated"] = true }
        return .object(fields)
    }

    private func readNote(_ args: ToolArguments) throws -> JSONValue {
        let notes = workspace.loadNotes()
        let note = try findNote(args.required("note"), in: notes)
        return noteDetail(note, notes: notes, store: try? workspace.loadTasks())
    }

    // MARK: Tâches

    private func createTask(_ args: ToolArguments) throws -> JSONValue {
        let title = try args.required("title")
        let notes = (try args.string("notes") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let priority = try ConnectorFormat.priority(args.values["priority"])
        let kind = try ConnectorFormat.kind(args.string("kind"))
        let now = clock()
        let due = try args.string("due").flatMap { text -> Date? in
            text.trimmingCharacters(in: .whitespaces).isEmpty ? nil : try ConnectorFormat.day(text, field: "due", now: now)
        }
        let tags = try args.strings("tags") ?? []
        let steps = try args.strings("steps") ?? []
        let projectReference = try args.string("project")
        let parentID = try args.string("parent_id").flatMap { $0.isEmpty ? nil : $0 }
        let recurrence = try Self.recurrence(args.string("repeat")) ?? nil

        let (task, store) = try workspace.updateTasks { (store: inout TaskStore) throws -> (TodoTask, TaskStore) in
            if let parentID {
                guard let parent = store[parentID] else { throw ToolFailure("Tâche parente introuvable : \(parentID).") }
                guard parent.isOpen else { throw ToolFailure("La tâche parente est cochée : rouvre-la d'abord avec reopen_task.") }
                guard tags.isEmpty else { throw ToolFailure("Une étape ne porte pas d'étiquette : seules les tâches principales en ont.") }
                guard recurrence == nil else { throw ToolFailure("Une étape ne se répète pas : seules les tâches principales le peuvent.") }
                guard var step = store.addTask(title: title, projectID: nil, parentID: parent.id, now: now) else {
                    throw ToolFailure("« title » est obligatoire.")
                }
                step.notes = notes
                step.priority = priority ?? step.priority
                step.kind = kind ?? step.kind
                step.due = due
                store.update(step)
                for title in steps {
                    store.addTask(title: title, projectID: nil, parentID: step.id, now: now)
                }
                return (store[step.id] ?? step, store)
            }
            var draft = TaskDraft()
            draft.title = title
            draft.notes = notes
            if let projectReference, !projectReference.isEmpty, !ConnectorFormat.isInbox(projectReference) {
                draft.projectID = try ConnectorFormat.project(projectReference, in: store).id
            }
            draft.priority = priority ?? draft.priority
            draft.kind = kind ?? draft.kind
            draft.due = due
            draft.tags = tags
            draft.steps = steps
            draft.recurrence = recurrence
            guard let created = store.addTask(draft, now: now) else { throw ToolFailure("« title » est obligatoire.") }
            return (created, store)
        }
        return taskDetail(task, in: store, notes: [])
    }

    private func updateTask(_ args: ToolArguments) throws -> JSONValue {
        let id = try args.required("id")
        let now = clock()
        let title = try args.string("title")
        let notes = try args.string("notes")
        let extra = try args.string("append_notes")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let projectReference = try args.string("project")
        let priority = try ConnectorFormat.priority(args.values["priority"])
        let kind = try ConnectorFormat.kind(args.string("kind"))
        let dueText = try args.string("due")
        let tags = try args.strings("tags")
        let blocked = try args.bool("blocked")
        let recurrence = try Self.recurrence(args.string("repeat"))

        let (task, store) = try workspace.updateTasks { (store: inout TaskStore) throws -> (TodoTask, TaskStore) in
            guard var task = store[id] else { throw ToolFailure("Tâche introuvable : \(id). Cherche-la avec list_tasks.") }
            if let title {
                guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ToolFailure("« title » ne peut pas être vide.") }
                task.title = title
            }
            if let notes { task.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines) }
            if let extra, !extra.isEmpty {
                task.notes = task.notes.isEmpty ? extra : task.notes + "\n\n" + extra
            }
            if let projectReference {
                guard task.parentID == nil else {
                    throw ToolFailure("Une étape suit le projet de sa tâche : change le projet de la tâche principale.")
                }
                if projectReference.trimmingCharacters(in: .whitespaces).isEmpty || ConnectorFormat.isInbox(projectReference) {
                    task.projectID = nil
                } else {
                    task.projectID = try ConnectorFormat.project(projectReference, in: store).id
                }
            }
            if let priority { task.priority = priority }
            if let kind { task.kind = kind }
            if let dueText {
                task.due = dueText.trimmingCharacters(in: .whitespaces).isEmpty ? nil : try ConnectorFormat.day(dueText, field: "due", now: now)
            }
            if let tags {
                guard task.parentID == nil || tags.isEmpty else {
                    throw ToolFailure("Une étape ne porte pas d'étiquette : seules les tâches principales en ont.")
                }
                task.tags = tags
            }
            if let recurrence {
                guard task.parentID == nil || recurrence == nil else {
                    throw ToolFailure("Une étape ne se répète pas : seules les tâches principales le peuvent.")
                }
                task.recurrence = recurrence
            }
            store.update(task, now: now)
            if let blocked { store.setBlocked(id, blocked) }
            return (store[id] ?? task, store)
        }
        return taskDetail(task, in: store, notes: workspace.loadNotes())
    }

    private func completeTask(_ args: ToolArguments) throws -> JSONValue {
        let id = try args.required("id")
        let now = clock()
        let (task, store) = try workspace.updateTasks { (store: inout TaskStore) throws -> (TodoTask, TaskStore) in
            guard let task = store[id] else { throw ToolFailure("Tâche introuvable : \(id).") }
            guard task.isOpen else { throw ToolFailure("« \(task.title) » est déjà cochée.") }
            store.complete(id, at: now)
            return (store[id] ?? task, store)
        }
        return taskDetail(task, in: store, notes: [])
    }

    private func reopenTask(_ args: ToolArguments) throws -> JSONValue {
        let id = try args.required("id")
        let (task, store) = try workspace.updateTasks { (store: inout TaskStore) throws -> (TodoTask, TaskStore) in
            guard let task = store[id] else { throw ToolFailure("Tâche introuvable : \(id).") }
            guard !task.isOpen else { throw ToolFailure("« \(task.title) » est déjà ouverte.") }
            store.reopen(id)
            return (store[id] ?? task, store)
        }
        return taskDetail(task, in: store, notes: [])
    }

    private func setTodayPlan(_ args: ToolArguments) throws -> JSONValue {
        let ids = try args.strings("task_ids") ?? []
        let mode = try args.string("mode") ?? "replace"
        guard ["replace", "append"].contains(mode) else { throw ToolFailure("« mode » vaut replace ou append.") }
        let store = try workspace.loadTasks()
        for id in ids {
            guard let task = store[id] else { throw ToolFailure("Tâche introuvable : \(id).") }
            guard task.isOpen else { throw ToolFailure("« \(task.title) » est cochée : elle ne peut pas entrer dans le plan.") }
        }
        let now = clock()
        let today = Format.dayKey(now)
        var plan: [String] = []
        if mode == "append" {
            let current = SharedPlan.current(snapshot: workspace.planSnapshot(), request: workspace.planRequest(), day: today)
            plan = current.taskIDs.filter { store[$0]?.isOpen == true }
        }
        for id in ids where !plan.contains(id) {
            plan.append(id)
        }
        guard !plan.isEmpty else { throw ToolFailure("Donne au moins une tâche dans « task_ids ».") }
        guard plan.count <= Rules.maxPlanSize else {
            throw ToolFailure("Le plan du jour tient en \(Rules.maxPlanSize) tâches au plus ; celui-ci en aurait \(plan.count).")
        }
        try workspace.requestPlan(PlanRequest(day: today, taskIDs: plan, requestedAt: now))
        return [
            "day": .string(today),
            "plan": .array(plan.compactMap { store[$0] }.map { .object(taskFields($0, in: store, now: now)) }),
            "info": "Done applique ce plan dès qu'il est ouvert, en quelques instants s'il l'est déjà.",
        ]
    }

    // MARK: Projets et étiquettes

    private func createProject(_ args: ToolArguments) throws -> JSONValue {
        let name = try args.required("name")
        let parentReference = try args.string("parent")
        let (project, store) = try workspace.updateTasks { (store: inout TaskStore) throws -> (Project, TaskStore) in
            var parentID: String?
            if let parentReference, !parentReference.trimmingCharacters(in: .whitespaces).isEmpty {
                let parent = try ConnectorFormat.project(parentReference, in: store)
                guard parent.parentID == nil else {
                    throw ToolFailure("« \(store.projectPath(parent.id) ?? parent.name) » est déjà un sous-projet : un seul niveau de sous-projets.")
                }
                parentID = parent.id
            }
            let key = RemindersInbox.matchKey(name)
            if let existing = store.projects.first(where: { $0.parentID == parentID && RemindersInbox.matchKey($0.name) == key }) {
                throw ToolFailure("Ce projet existe déjà : « \(store.projectPath(existing.id) ?? existing.name) » (\(existing.id)).")
            }
            guard let created = store.addProject(named: name, parentID: parentID) else { throw ToolFailure("« name » est obligatoire.") }
            return (created, store)
        }
        return projectFields(project, in: store)
    }

    private func updateProject(_ args: ToolArguments) throws -> JSONValue {
        let reference = try args.required("project")
        let name = try args.string("name")
        let parentReference = try args.string("parent")
        let (project, store) = try workspace.updateTasks { (store: inout TaskStore) throws -> (Project, TaskStore) in
            let project = try ConnectorFormat.project(reference, in: store)
            if let name {
                guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ToolFailure("« name » ne peut pas être vide.") }
                store.renameProject(project.id, to: name)
            }
            if let parentReference {
                let trimmed = parentReference.trimmingCharacters(in: .whitespaces)
                let parentID = trimmed.isEmpty ? nil : try ConnectorFormat.project(trimmed, in: store).id
                if parentID != project.parentID {
                    store.moveProject(project.id, under: parentID)
                    guard store.project(project.id)?.parentID == parentID else {
                        throw ToolFailure("Rangement refusé : un seul niveau de sous-projets. Un projet qui a des sous-projets reste au premier niveau, et un sous-projet n'en reçoit pas.")
                    }
                }
            }
            return (store.project(project.id) ?? project, store)
        }
        return projectFields(project, in: store)
    }

    private func renameTag(_ args: ToolArguments) throws -> JSONValue {
        let from = try args.required("from")
        let to = try args.required("to")
        let (name, count) = try workspace.updateTasks { (store: inout TaskStore) throws -> (String, Int) in
            let old = try ConnectorFormat.tag(from, in: store)
            let count = store.tasks.filter { $0.tags.contains(old) }.count
            store.renameTag(old, to: to)
            return (old, count)
        }
        return ["renamed": .string(name), "to": .string(to), "tasks": .int(count)]
    }

    // MARK: Notes

    private func createNote(_ args: ToolArguments) throws -> JSONValue {
        let notes = workspace.loadNotes()
        let store = try workspace.loadTasks()
        let now = clock()
        var kind = try ConnectorFormat.noteKind(args.string("kind")) ?? .note
        var projectID: String?
        if let reference = try args.string("project"), !reference.isEmpty {
            projectID = try ConnectorFormat.project(reference, in: store).id
        }
        let taskIDs = try existingTaskIDs(args.strings("task_ids") ?? [], in: store)
        var date = try args.string("date").flatMap { text -> Date? in
            text.isEmpty ? nil : try ConnectorFormat.dayOrMoment(text, field: "date", now: now)
        }
        var title = (try args.string("title") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        var body = try args.string("body") ?? ""
        var meetingID: String?
        if let id = try args.string("meeting_id"), !id.isEmpty {
            guard let meeting = store.meetings.first(where: { $0.id == id }) else { throw ToolFailure("Réunion introuvable : \(id).") }
            if let existing = notes.first(where: { $0.kind == .meeting && $0.meetingID == id }) {
                throw ToolFailure("Cette réunion a déjà sa note : « \(existing.title) » (\(existing.id)). Complète-la avec update_note.")
            }
            kind = .meeting
            meetingID = id
            if title.isEmpty { title = NoteTemplates.meetingTitle(meeting) }
            if body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { body = NoteTemplates.meetingBody(meeting) }
            date = date ?? meeting.start
        }
        switch kind {
        case .project:
            guard let projectID else { throw ToolFailure("Une page de projet demande « project ».") }
            if let page = notes.first(where: { $0.kind == .project && $0.projectID == projectID }) {
                throw ToolFailure("Ce projet a déjà sa page : « \(page.title) » (\(page.id)). Complète-la avec update_note.")
            }
            if title.isEmpty { title = store.projectPath(projectID) ?? "Projet" }
            if body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { body = NoteTemplates.projectPage }
        case .journal:
            let day = calendar.startOfDay(for: date ?? now)
            if let existing = notes.first(where: { $0.kind == .journal && ($0.date.map { calendar.isDate($0, inSameDayAs: day) } ?? false) }) {
                throw ToolFailure("La note de ce jour existe déjà : « \(existing.title) » (\(existing.id)). Complète-la avec update_note.")
            }
            date = day
            if title.isEmpty { title = NoteTemplates.journalTitle(day) }
        default:
            break
        }
        guard !title.isEmpty else { throw ToolFailure("« title » est obligatoire.") }
        let note = Note(
            kind: kind,
            title: NoteLinks.uniqueTitle(title, among: notes),
            body: body,
            projectID: projectID,
            tags: TaskStore.normalizedTags(try args.strings("tags") ?? [], known: notes.flatMap(\.tags)),
            taskIDs: taskIDs,
            date: date,
            meetingID: meetingID,
            createdAt: now,
            updatedAt: now
        )
        try workspace.writeNote(note)
        return noteDetail(note, notes: notes + [note], store: store)
    }

    private func updateNote(_ args: ToolArguments) throws -> JSONValue {
        let notes = workspace.loadNotes()
        var note = try findNote(args.required("note"), in: notes)
        var store: TaskStore?
        func tasks() throws -> TaskStore {
            if let store { return store }
            let loaded = try workspace.loadTasks()
            store = loaded
            return loaded
        }
        if let title = try args.string("title") {
            guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ToolFailure("« title » ne peut pas être vide.") }
            note.title = NoteLinks.uniqueTitle(title, among: notes, excluding: note.id)
        }
        if let body = try args.string("body") { note.body = body }
        if let extra = try args.string("append")?.trimmingCharacters(in: .newlines), !extra.trimmingCharacters(in: .whitespaces).isEmpty {
            let current = note.body.trimmingCharacters(in: .newlines)
            note.body = current.isEmpty ? extra : current + "\n\n" + extra
        }
        if let kind = try ConnectorFormat.noteKind(args.string("kind")), kind != note.kind {
            guard NoteKind.creatable.contains(kind), NoteKind.creatable.contains(note.kind) else {
                throw ToolFailure("Une page de projet et une note du jour gardent leur type ; les autres notes passent de note à meeting, decision, person ou reference.")
            }
            note.kind = kind
        }
        if let reference = try args.string("project") {
            if reference.trimmingCharacters(in: .whitespaces).isEmpty {
                guard note.kind != .project else { throw ToolFailure("Une page de projet reste rattachée à un projet.") }
                note.projectID = nil
            } else {
                let projectID = try ConnectorFormat.project(reference, in: tasks()).id
                if note.kind == .project, let page = notes.first(where: { $0.kind == .project && $0.projectID == projectID && $0.id != note.id }) {
                    throw ToolFailure("Ce projet a déjà sa page : « \(page.title) » (\(page.id)).")
                }
                note.projectID = projectID
            }
        }
        if let tags = try args.strings("tags") {
            note.tags = TaskStore.normalizedTags(tags, known: notes.filter { $0.id != note.id }.flatMap(\.tags))
        }
        if let ids = try args.strings("task_ids") {
            note.taskIDs = try existingTaskIDs(ids, in: tasks())
        }
        if let text = try args.string("date") {
            note.date = text.isEmpty ? nil : try ConnectorFormat.dayOrMoment(text, field: "date", now: clock())
        }
        note.updatedAt = clock()
        try workspace.writeNote(note)
        let updated = notes.map { $0.id == note.id ? note : $0 }
        return noteDetail(note, notes: updated, store: try? tasks())
    }

    // MARK: Réunions et absences

    private func addMeeting(_ args: ToolArguments) throws -> JSONValue {
        let title = try args.required("title")
        let start = try ConnectorFormat.moment(args.required("start"), field: "start")
        let end: Date
        if let text = try args.string("end"), !text.isEmpty {
            end = try ConnectorFormat.moment(text, field: "end")
        } else if let minutes = try args.int("duration_minutes") {
            end = start.addingTimeInterval(TimeInterval(minutes) * 60)
        } else {
            throw ToolFailure("Donne « end » ou « duration_minutes ».")
        }
        try checkMeetingTimes(start: start, end: end)
        var recurrence: Recurrence?
        if let raw = try args.string("repeat"), !raw.isEmpty {
            guard let rule = Recurrence(raw: raw) else {
                throw ToolFailure("Répétition inconnue : \(raw). Formes : daily, weekdays, weekly ou weekly:2,5, biweekly, monthly ou monthly:15.")
            }
            recurrence = rule
        }
        let now = clock()
        let (meeting, store) = try workspace.updateTasks { (store: inout TaskStore) throws -> (Meeting, TaskStore) in
            let created: Meeting?
            if let recurrence {
                created = store.addMeetingSeries(title: title, start: start, end: end, recurrence: recurrence, now: now)
            } else {
                created = store.addMeeting(title: title, start: start, end: end)
            }
            guard let created else { throw ToolFailure("La fin doit venir après le début.") }
            return (created, store)
        }
        return meetingFields(meeting, notes: [], store: store)
    }

    private func updateMeeting(_ args: ToolArguments) throws -> JSONValue {
        let id = try args.required("id")
        let title = try args.string("title")
        let start = try args.string("start").map { try ConnectorFormat.moment($0, field: "start") }
        let end = try args.string("end").map { try ConnectorFormat.moment($0, field: "end") }
        let meeting = try workspace.updateTasks { (store: inout TaskStore) throws -> Meeting in
            guard var meeting = store.meetings.first(where: { $0.id == id }) else { throw ToolFailure("Réunion introuvable : \(id).") }
            if let title { meeting.title = title }
            if let start {
                // Sans nouvelle fin, la réunion garde sa durée.
                if end == nil { meeting.end = start.addingTimeInterval(meeting.end.timeIntervalSince(meeting.start)) }
                meeting.start = start
            }
            if let end { meeting.end = end }
            try checkMeetingTimes(start: meeting.start, end: meeting.end)
            store.updateMeeting(meeting)
            return store.meetings.first { $0.id == id } ?? meeting
        }
        return meetingFields(meeting, notes: workspace.loadNotes())
    }

    private func checkMeetingTimes(start: Date, end: Date) throws {
        guard end > start else { throw ToolFailure("La fin doit venir après le début.") }
        guard end >= Stats.week(containing: clock()).start else {
            throw ToolFailure("Done ne garde pas les réunions des semaines passées.")
        }
    }

    private func setAbsence(_ args: ToolArguments) throws -> JSONValue {
        let now = clock()
        let day = try ConnectorFormat.day(args.required("date"), field: "date", now: now)
        let label = try args.string("label") ?? ""
        let absence = try workspace.updateTasks { (store: inout TaskStore) throws -> Absence? in
            store.setAbsence(on: day, title: label)
            return store.absence(on: day)
        }
        return ["date": .string(Format.dayKey(day)), "label": .string(absence?.title ?? label), "weekday": .string(Format.longDay(day))]
    }

    // MARK: Mise en forme

    private func taskRef(_ task: TodoTask) -> JSONValue {
        ["id": .string(task.id), "title": .string(task.title)]
    }

    private func taskFields(_ task: TodoTask, in store: TaskStore, now: Date) -> [String: JSONValue] {
        var fields: [String: JSONValue] = [
            "id": .string(task.id),
            "title": .string(task.title),
            "priority": .string("P\(task.priority)"),
        ]
        if let path = store.projectPath(task.projectID), let projectID = task.projectID {
            fields["project"] = .string(path)
            fields["project_id"] = .string(projectID)
        } else if task.parentID == nil, task.tags.isEmpty {
            fields["inbox"] = true
        }
        if let parentID = task.parentID { fields["parent_id"] = .string(parentID) }
        if task.kind != .normal { fields["kind"] = .string(task.kind.rawValue) }
        if let due = task.due {
            fields["due"] = .string(Format.dayKey(due))
            if task.isOpen, due < calendar.startOfDay(for: now) { fields["late"] = true }
        }
        if !task.tags.isEmpty { fields["tags"] = .array(task.tags.map { .string($0) }) }
        if let recurrence = task.recurrence {
            fields["repeat"] = .string(recurrence.raw)
            fields["repeat_label"] = .string(recurrence.label)
        }
        if task.isBlocked { fields["blocked"] = true }
        if let done = task.completedAt { fields["done_at"] = .string(ConnectorFormat.stamp(done)) }
        return fields
    }

    private func children(of id: String, in store: TaskStore) -> [TodoTask] {
        store.tasks.filter { $0.parentID == id }.sorted { $0.position < $1.position }
    }

    /// Une tâche dans une liste : notes en extrait, étapes ouvertes.
    private func listEntry(_ task: TodoTask, in store: TaskStore, now: Date) -> JSONValue {
        var fields = taskFields(task, in: store, now: now)
        if !task.notes.isEmpty { fields["notes"] = .string(ConnectorFormat.excerpt(task.notes, 240)) }
        let steps = children(of: task.id, in: store)
        let open = steps.filter(\.isOpen)
        if !open.isEmpty { fields["open_steps"] = .array(open.map(taskRef)) }
        if steps.count > open.count { fields["done_steps"] = .int(steps.count - open.count) }
        return .object(fields)
    }

    /// Une tâche en entier : notes, étapes cochées comprises, parente, notes rattachées, note de reprise.
    private func taskDetail(_ task: TodoTask, in store: TaskStore, notes: [Note]) -> JSONValue {
        let now = clock()
        var fields = taskFields(task, in: store, now: now)
        fields["notes"] = .string(task.notes)
        fields["created_at"] = .string(ConnectorFormat.stamp(task.createdAt))
        fields["steps"] = .array(children(of: task.id, in: store).map { step in
            var stepFields = taskFields(step, in: store, now: now)
            stepFields["project"] = nil
            stepFields["project_id"] = nil
            stepFields["parent_id"] = nil
            if !step.notes.isEmpty { stepFields["notes"] = .string(step.notes) }
            let sub = children(of: step.id, in: store).count
            if sub > 0 { stepFields["steps_count"] = .int(sub) }
            return .object(stepFields)
        })
        if let parentID = task.parentID, let parent = store[parentID] {
            fields["parent"] = taskRef(parent)
        }
        let linked = notes.filter { $0.taskIDs.contains(task.id) }
        if !linked.isEmpty { fields["linked_notes"] = .array(linked.map(noteRef)) }
        if let resume = workspace.resumeNote(for: task.id) { fields["resume_note"] = .string(resume) }
        return .object(fields)
    }

    private func projectFields(_ project: Project, in store: TaskStore) -> JSONValue {
        var fields: [String: JSONValue] = [
            "id": .string(project.id),
            "name": .string(project.name),
            "path": .string(store.projectPath(project.id) ?? project.name),
        ]
        if let parentID = project.parentID { fields["parent_id"] = .string(parentID) }
        return .object(fields)
    }

    private func meetingFields(_ meeting: Meeting, notes: [Note], store: TaskStore? = nil) -> JSONValue {
        var fields: [String: JSONValue] = [
            "id": .string(meeting.id),
            "title": .string(meeting.title),
            "start": .string(ConnectorFormat.stamp(meeting.start)),
            "end": .string(ConnectorFormat.stamp(meeting.end)),
        ]
        // Occurrence d'une réunion récurrente : la répétition de sa série.
        if let rule = store?.series(of: meeting)?.recurrence {
            fields["repeat"] = .string(rule.raw)
            fields["repeat_label"] = .string(rule.label)
        }
        if let note = notes.first(where: { $0.kind == .meeting && $0.meetingID == meeting.id }) {
            fields["note_id"] = .string(note.id)
        }
        return .object(fields)
    }

    private func noteRef(_ note: Note) -> JSONValue {
        ["id": .string(note.id), "title": .string(note.title), "kind": .string(note.kind.rawValue)]
    }

    private func noteFields(_ note: Note, store: TaskStore?) -> [String: JSONValue] {
        var fields: [String: JSONValue] = [
            "id": .string(note.id),
            "title": .string(note.title),
            "kind": .string(note.kind.rawValue),
            "updated_at": .string(ConnectorFormat.stamp(note.updatedAt)),
        ]
        if let projectID = note.projectID {
            fields["project_id"] = .string(projectID)
            if let path = store?.projectPath(projectID) { fields["project"] = .string(path) }
        }
        if !note.tags.isEmpty { fields["tags"] = .array(note.tags.map { .string($0) }) }
        if let date = note.date {
            fields["date"] = .string(note.kind == .journal ? Format.dayKey(date) : ConnectorFormat.stamp(date))
        }
        if let meetingID = note.meetingID { fields["meeting_id"] = .string(meetingID) }
        return fields
    }

    private func noteSummary(_ note: Note, store: TaskStore?) -> JSONValue {
        var fields = noteFields(note, store: store)
        if !note.body.isEmpty { fields["excerpt"] = .string(ConnectorFormat.excerpt(note.body, 200)) }
        if !note.taskIDs.isEmpty { fields["task_ids"] = .array(note.taskIDs.map { .string($0) }) }
        return .object(fields)
    }

    /// Une note en entier : contenu, tâches rattachées, liens [[Titre]] sortants et notes qui la citent.
    private func noteDetail(_ note: Note, notes: [Note], store: TaskStore?) -> JSONValue {
        var fields = noteFields(note, store: store)
        fields["body"] = .string(note.body)
        fields["created_at"] = .string(ConnectorFormat.stamp(note.createdAt))
        if !note.taskIDs.isEmpty {
            fields["tasks"] = .array(note.taskIDs.map { id -> JSONValue in
                guard let task = store?[id] else { return ["id": .string(id)] }
                return ["id": .string(id), "title": .string(task.title), "done": .bool(!task.isOpen)]
            })
        }
        let links = NoteLinks.titles(in: note.body)
        if !links.isEmpty {
            fields["links"] = .array(links.map { title -> JSONValue in
                guard let target = NoteLinks.resolve(title, in: notes) else { return ["title": .string(title), "missing": true] }
                return ["title": .string(title), "id": .string(target.id)]
            })
        }
        let backlinks = NoteLinks.backlinks(to: note, in: notes)
        if !backlinks.isEmpty { fields["backlinks"] = .array(backlinks.map(noteRef)) }
        return .object(fields)
    }

    /// `nil` : rien de demandé ; `.some(nil)` : retirer la répétition (chaîne vide).
    private static func recurrence(_ text: String?) throws -> Recurrence?? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return .some(nil) }
        guard let value = Recurrence(raw: trimmed) else {
            throw ToolFailure("« repeat » vaut daily, weekdays, weekly ou weekly:<jours> (1 = dimanche, 2 = lundi… 7 = samedi, par exemple weekly:2,5), biweekly, monthly ou monthly:<jour du mois>, ou une chaîne vide pour arrêter la répétition.")
        }
        return .some(value)
    }

    private func searchableText(_ task: TodoTask, in store: TaskStore) -> String {
        let steps = store.descendants(of: task.id).compactMap { store[$0]?.title }
        return ([task.title, task.notes, store.projectPath(task.projectID) ?? ""] + task.tags + steps).joined(separator: "\n")
    }

    private func findNote(_ reference: String, in notes: [Note]) throws -> Note {
        if let note = notes.first(where: { $0.id == reference }) ?? NoteLinks.resolve(reference, in: notes) {
            return note
        }
        throw ToolFailure("Note introuvable : « \(reference) ». Cherche-la avec list_notes.")
    }

    private func existingTaskIDs(_ ids: [String], in store: TaskStore) throws -> [String] {
        var result: [String] = []
        for id in ids where !result.contains(id) {
            guard store[id] != nil else { throw ToolFailure("Tâche introuvable : \(id).") }
            result.append(id)
        }
        return result
    }
}
