import Foundation

/// Bloc de travail : du temps réservé au calendrier pour une tâche. Il dure par défaut un pomodoro,
/// selon le type de la tâche (rapide, normale, Deepwork), et se déplace ou s'étire comme une réunion.
/// Il compte comme du temps pris dans les créneaux libres, mais n'empêche pas de lancer une session
/// comme une réunion : pendant le bloc, Ma journée propose sa tâche. Gardé jusqu'à la fin de la
/// semaine, comme les réunions.
struct WorkBlock: Codable, Identifiable, Hashable {
    let id: String
    var taskID: String
    var start: Date
    var end: Date

    func contains(_ date: Date) -> Bool { start <= date && date < end }
}

extension TaskStore {
    /// Durée d'un bloc créé pour `task` : un pomodoro, selon son type, puis celui de sa tâche principale.
    func blockMinutes(for task: TodoTask, rules: Rules) -> Int {
        Planner.minutes(for: task, root: rootTask(of: task), rules: rules)
    }

    /// La tâche de premier niveau d'une tâche (elle-même si elle n'a pas de parente).
    func rootTask(of task: TodoTask) -> TodoTask {
        var current = task
        var steps = 0
        while let parent = current.parentID.flatMap({ self[$0] }), steps < 50 {
            current = parent
            steps += 1
        }
        return current
    }

    /// Réserve du temps pour une tâche ouverte, à partir de `start`, pour un pomodoro (ou jusqu'à
    /// `end`). Nil si la tâche n'existe pas, est faite, ou si la fin ne vient pas après le début.
    @discardableResult
    mutating func addWorkBlock(taskID: String, start: Date, end: Date? = nil, rules: Rules, id: String = UUID().uuidString) -> WorkBlock? {
        guard let task = self[taskID], task.isOpen else { return nil }
        let finish = end ?? start.addingTimeInterval(TimeInterval(blockMinutes(for: task, rules: rules)) * 60)
        guard finish > start else { return nil }
        let block = WorkBlock(id: id, taskID: taskID, start: start, end: finish)
        workBlocks.append(block)
        return block
    }

    /// Remplace le bloc du même identifiant. Refusé si la fin ne vient pas après le début.
    mutating func updateWorkBlock(_ block: WorkBlock) {
        guard block.end > block.start, let i = workBlocks.firstIndex(where: { $0.id == block.id }) else { return }
        workBlocks[i] = block
    }

    mutating func deleteWorkBlock(_ id: String) {
        workBlocks.removeAll { $0.id == id }
    }

    /// Blocs d'un jour, par heure de début.
    func workBlocks(on day: Date, calendar: Calendar = .current) -> [WorkBlock] {
        workBlocks
            .filter { calendar.isDate($0.start, inSameDayAs: day) }
            .sorted { $0.start < $1.start }
    }

    /// Tâches qui ont un bloc de travail pas encore fini : elles sont planifiées, et quittent les
    /// échéances du calendrier et de Ma journée. Le bloc passé sans que la tâche soit faite, elle y revient.
    func scheduledTaskIDs(at now: Date) -> Set<String> {
        Set(workBlocks.filter { $0.end > now }.map(\.taskID))
    }

    /// « Décaler de 30 min » : le bloc garde sa durée et commence `minutes` plus tard, à partir de son
    /// début s'il est encore à venir, sinon de maintenant (au quart d'heure suivant).
    @discardableResult
    mutating func postponeWorkBlock(_ id: String, minutes: Int = WorkBlockReminder.postponeMinutes, now: Date, calendar: Calendar = .current) -> WorkBlock? {
        guard let i = workBlocks.firstIndex(where: { $0.id == id }) else { return nil }
        let block = workBlocks[i]
        let duration = block.end.timeIntervalSince(block.start)
        var start = block.start.addingTimeInterval(TimeInterval(minutes) * 60)
        if block.start < now {
            // Déjà commencé : on repart de maintenant, au quart d'heure suivant.
            let quarter = TimelineEdit.currentQuarter(now, calendar: calendar).addingTimeInterval(TimeInterval(TimelineEdit.step) * 60)
            start = quarter.addingTimeInterval(TimeInterval(minutes) * 60)
        }
        workBlocks[i].start = start
        workBlocks[i].end = start.addingTimeInterval(max(duration, 60))
        return workBlocks[i]
    }

    /// Le bloc en cours d'une tâche encore ouverte, à `now`.
    func currentWorkBlock(at now: Date) -> WorkBlock? {
        workBlocks
            .filter { $0.contains(now) && (self[$0.taskID]?.isOpen ?? false) }
            .min { $0.start < $1.start }
    }
}

/// Ce que Ma journée propose pendant un bloc de travail.
enum WorkBlockPlan {
    /// Le plan, avec la tâche du bloc en cours (sa tâche principale) en tête : Done la propose d'abord.
    static func plan(_ plan: [String], leading taskID: String?) -> [String] {
        guard let taskID else { return plan }
        return [taskID] + plan.filter { $0 != taskID }
    }

    /// La durée proposée pendant un bloc : celle du pomodoro, raccourcie à ce qui reste du bloc s'il
    /// en reste au moins 5 min.
    static func minutes(_ minutes: Int, in block: WorkBlock?, now: Date) -> Int {
        guard let block else { return minutes }
        let left = Int(block.end.timeIntervalSince(now) / 60)
        return left >= 5 ? min(minutes, left) : minutes
    }
}

/// Rappel d'un bloc de travail, 5 min avant : lancer le pomodoro, ou déplacer le bloc.
struct WorkBlockReminder: Equatable {
    /// Préfixe des identifiants de notification ; la suite est l'identifiant du bloc.
    static let prefix = "done.workblock."
    static let minutesBefore = 5
    /// « Décaler de 30 min » : le décalage proposé par le rappel.
    static let postponeMinutes = 30

    /// Réponse au rappel d'un bloc.
    enum Answer: Equatable {
        /// « Lancer le pomodoro ».
        case start
        /// « Décaler de 30 min », sans ouvrir Done.
        case postpone
        /// « Déplacer… », ou un clic sur le rappel : Done ouvre le bloc.
        case move
    }

    let id: String
    let blockID: String
    let fireDate: Date
    let title: String
    let body: String

    /// L'identifiant du bloc d'une notification de Done, s'il s'agit d'un rappel de bloc.
    static func blockID(fromNotification id: String) -> String? {
        id.hasPrefix(prefix) ? String(id.dropFirst(prefix.count)) : nil
    }

    /// Rappels des blocs à venir d'une tâche ouverte. Un bloc trop proche pour être annoncé à temps
    /// n'a pas de rappel.
    static func plan(_ store: TaskStore, now: Date) -> [WorkBlockReminder] {
        store.workBlocks.compactMap { block in
            guard let task = store[block.taskID], task.isOpen else { return nil }
            let fireDate = block.start.addingTimeInterval(-TimeInterval(minutesBefore * 60))
            guard fireDate > now else { return nil }
            return WorkBlockReminder(
                id: prefix + block.id,
                blockID: block.id,
                fireDate: fireDate,
                title: "Bloc de travail à \(Format.time(block.start))",
                body: "« \(task.title) » dans \(minutesBefore) min. Lancer le pomodoro, le décaler, ou le déplacer ?"
            )
        }
    }
}
