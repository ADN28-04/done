import Foundation
import SwiftData

/// Plan du jour : les tâches choisies le matin, dans l'ordre.
@Model
final class DayPlan {
    @Attribute(.unique) var day: Date
    var taskIDs: [String]
    var doneIDs: [String]
    var validatedAt: Date

    init(day: Date, taskIDs: [String]) {
        self.day = day
        self.taskIDs = taskIDs
        self.doneIDs = []
        self.validatedAt = .now
    }
}

/// Une session de focus. Le titre et le projet sont copiés pour que les stats
/// restent lisibles une fois la tâche fermée dans Todoist.
@Model
final class FocusSession {
    var taskID: String
    var title: String
    var rootTaskID: String
    var rootTitle: String
    var projectID: String
    var projectName: String
    var labels: [String]
    var startedAt: Date
    var endedAt: Date?
    var plannedSeconds: Double
    var focusedSeconds: Double
    var outcomeRaw: String
    @Relationship(deleteRule: .cascade, inverse: \Interruption.session)
    var interruptions: [Interruption] = []

    init(action: TodoistTask, root: TodoistTask, projectName: String, plannedSeconds: Double) {
        taskID = action.id
        title = action.content
        rootTaskID = root.id
        rootTitle = root.content
        projectID = root.projectId
        self.projectName = projectName
        labels = Array(Set(root.labels + action.labels)).sorted()
        startedAt = .now
        endedAt = nil
        self.plannedSeconds = plannedSeconds
        focusedSeconds = 0
        outcomeRaw = SessionOutcome.inProgress.rawValue
    }

    var outcome: SessionOutcome {
        get { SessionOutcome(rawValue: outcomeRaw) ?? .partial }
        set { outcomeRaw = newValue.rawValue }
    }

    var fact: SessionFact {
        SessionFact(
            startedAt: startedAt,
            focusedSeconds: focusedSeconds,
            projectName: projectName,
            outcome: outcome,
            interruptions: interruptions.map(\.reason)
        )
    }
}

@Model
final class Interruption {
    var reasonRaw: String
    var startedAt: Date
    var endedAt: Date?
    var session: FocusSession?

    init(reason: InterruptionReason, startedAt: Date = .now) {
        reasonRaw = reason.rawValue
        self.startedAt = startedAt
        endedAt = nil
        session = nil
    }

    var reason: InterruptionReason { InterruptionReason(rawValue: reasonRaw) ?? .other }
}

/// Photo quotidienne du backlog, pour tracer son évolution.
@Model
final class BacklogSnapshot {
    @Attribute(.unique) var day: Date
    var openTasks: Int
    var openTopLevel: Int
    var averageAgeDays: Double
    var oldestAgeDays: Double
    var activeCount: Int

    init(day: Date) {
        self.day = day
        openTasks = 0
        openTopLevel = 0
        averageAgeDays = 0
        oldestAgeDays = 0
        activeCount = 0
    }

    func update(_ numbers: BacklogNumbers) {
        openTasks = numbers.openTasks
        openTopLevel = numbers.openTopLevel
        averageAgeDays = numbers.averageAgeDays
        oldestAgeDays = numbers.oldestAgeDays
        activeCount = numbers.activeCount
    }
}
