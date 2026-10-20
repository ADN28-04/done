import Foundation
import Observation
import SwiftData

/// Minuteur et cycle de vie d'une session : focus, pause, interruption, fin, pause café.
@Observable
@MainActor
final class FocusEngine {
    enum Phase: Equatable {
        case idle
        case focusing
        case paused
        case interrupted(InterruptionReason)
        case awaitingOutcome
        case onBreak
    }

    struct Current {
        let action: TodoistTask
        let root: TodoistTask
        let projectName: String
        let planned: TimeInterval
    }

    private(set) var phase: Phase = .idle
    private(set) var current: Current?
    /// Avance chaque seconde tant qu'un minuteur tourne : les vues s'y abonnent.
    private(set) var now = Date()
    private(set) var interruptedAt: Date?
    private(set) var breakEnd: Date?
    private(set) var breakDuration: TimeInterval = 0
    private(set) var isClosing = false
    var errorMessage: String?

    private var elapsedBefore: TimeInterval = 0
    private var segmentStart: Date?

    @ObservationIgnored private var record: FocusSession?
    @ObservationIgnored private var openInterruption: Interruption?
    @ObservationIgnored private var ticker: Timer?

    let model: AppModel
    let context: ModelContext

    init(model: AppModel, context: ModelContext) {
        self.model = model
        self.context = context
        closeStaleSessions()
    }

    // MARK: Lecture

    var elapsed: TimeInterval {
        elapsedBefore + (segmentStart.map { now.timeIntervalSince($0) } ?? 0)
    }

    var remaining: TimeInterval { max(0, (current?.planned ?? 0) - elapsed) }

    var breakRemaining: TimeInterval { max(0, (breakEnd ?? now).timeIntervalSince(now)) }

    /// Part restante du minuteur, pour l'anneau qui se vide depuis le haut.
    var remainingFraction: Double {
        guard let planned = current?.planned, planned > 0 else { return 0 }
        return remaining / planned
    }

    var breakRemainingFraction: Double {
        breakDuration > 0 ? breakRemaining / breakDuration : 0
    }

    var menuBarText: String {
        switch phase {
        case .idle: ""
        case .focusing, .paused, .interrupted: Format.clock(remaining)
        case .awaitingOutcome: "Fini"
        case .onBreak: Format.clock(breakRemaining)
        }
    }

    // MARK: Actions

    func start(action: TodoistTask, root: TodoistTask, minutes: Int) {
        endBreak()
        let planned = TimeInterval(max(1, minutes) * 60)
        let projectName = model.projectName(for: root)
        current = Current(action: action, root: root, projectName: projectName, planned: planned)
        elapsedBefore = 0
        segmentStart = .now
        now = .now
        interruptedAt = nil
        errorMessage = nil

        let session = FocusSession(action: action, root: root, projectName: projectName, plannedSeconds: planned)
        context.insert(session)
        record = session
        save()

        transition(to: .focusing)
        scheduleFocusEnd()
        startTicker()
    }

    func pause() {
        guard phase == .focusing else { return }
        closeSegment()
        transition(to: .paused)
        Notifier.shared.cancel(Notifier.focusEnd)
    }

    func resume() {
        guard current != nil, phase == .paused || isInterrupted else { return }
        closeInterruption()
        segmentStart = .now
        now = .now
        transition(to: .focusing)
        scheduleFocusEnd()
        startTicker()
        save()
    }

    func interrupt(_ reason: InterruptionReason) {
        guard phase == .focusing || phase == .paused, let record else { return }
        closeSegment()
        let interruption = Interruption(reason: reason)
        context.insert(interruption)
        interruption.session = record
        openInterruption = interruption
        interruptedAt = .now
        transition(to: .interrupted(reason))
        Notifier.shared.cancel(Notifier.focusEnd)
        save()
    }

    /// « Terminer » pendant la session : on passe directement au bilan.
    func finishEarly() {
        guard current != nil, phase != .awaitingOutcome else { return }
        closeSegment()
        closeInterruption()
        transition(to: .awaitingOutcome)
        Notifier.shared.cancel(Notifier.focusEnd)
    }

    /// L'action est finie : on la coche dans Todoist, puis pause.
    func markDone() async {
        guard let current, !isClosing else { return }
        isClosing = true
        defer { isClosing = false }
        do {
            try await model.close(current.action)
            finishRecord(.done)
            startBreakAfterSession()
        } catch {
            if let todoistError = error as? TodoistError, case .unauthorized = todoistError {
                errorMessage = error.localizedDescription
            } else {
                errorMessage = "Todoist n'a pas répondu : la tâche n'est pas cochée. Vérifie ta connexion et réessaie."
            }
        }
    }

    /// Nouvelle session sur la même action, même durée.
    func continueSameAction() {
        guard let current else { return }
        finishRecord(.partial)
        start(action: current.action, root: current.root, minutes: Int(current.planned / 60))
    }

    /// Pause sans cocher la tâche.
    func takeBreakAfterSession() {
        guard current != nil else { return }
        finishRecord(.partial)
        startBreakAfterSession()
    }

    /// Pause libre, par exemple avant une réunion.
    func takeBreak(minutes: Int) {
        if current != nil { stop(as: .partial) }
        beginBreak(seconds: TimeInterval(max(1, minutes) * 60))
    }

    /// Retour à l'écran Focus sans pause.
    func stop(as outcome: SessionOutcome) {
        closeSegment()
        closeInterruption()
        finishRecord(outcome)
        reset()
    }

    func skipBreak() {
        endBreak()
        transition(to: .idle)
        stopTicker()
    }

    // MARK: Interne

    private var isInterrupted: Bool {
        if case .interrupted = phase { return true }
        return false
    }

    private func startBreakAfterSession() {
        let rules = Rules.current
        let wasLong = (current?.planned ?? 0) >= TimeInterval(rules.deepworkMinutes * 60)
        let minutes = wasLong ? rules.longBreakMinutes : rules.shortBreakMinutes
        beginBreak(seconds: TimeInterval(minutes * 60))
    }

    private func beginBreak(seconds: TimeInterval) {
        reset()
        now = .now
        breakEnd = now.addingTimeInterval(seconds)
        breakDuration = seconds
        transition(to: .onBreak)
        Notifier.shared.schedule(
            Notifier.breakEnd,
            title: "Fin de la pause",
            body: "Ta prochaine tâche t'attend dans Done.",
            after: seconds
        )
        startTicker()
    }

    private func endBreak() {
        breakEnd = nil
        Notifier.shared.cancel(Notifier.breakEnd)
    }

    private func reset() {
        current = nil
        elapsedBefore = 0
        segmentStart = nil
        interruptedAt = nil
        record = nil
        openInterruption = nil
        transition(to: .idle)
    }

    private func closeSegment() {
        if let segmentStart {
            elapsedBefore += Date.now.timeIntervalSince(segmentStart)
            self.segmentStart = nil
        }
        now = .now
        record?.focusedSeconds = elapsedBefore
    }

    private func closeInterruption() {
        openInterruption?.endedAt = .now
        openInterruption = nil
        interruptedAt = nil
    }

    private func finishRecord(_ outcome: SessionOutcome) {
        guard let record else { return }
        record.focusedSeconds = elapsedBefore
        record.endedAt = .now
        record.outcome = outcome
        self.record = nil
        save()
    }

    /// Point de passage unique des changements de phase.
    private func transition(to newPhase: Phase) {
        phase = newPhase
        DoNotDisturb.shared.update(focusing: newPhase == .focusing)
        SystemBridge.keepTimerAccurate(newPhase != .idle && newPhase != .awaitingOutcome)
    }

    private func scheduleFocusEnd() {
        // Avec « Ne pas déranger », la notification serait masquée : elle part
        // depuis tick(), une fois le mode coupé.
        guard let current, !Rules.current.dndEnabled else { return }
        Notifier.shared.schedule(
            Notifier.focusEnd,
            title: "Session terminée",
            body: current.action.content,
            after: remaining
        )
    }

    private func startTicker() {
        guard ticker == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        now = .now
        switch phase {
        case .focusing:
            // Sauvegarde régulière, pour ne pas tout perdre si l'app est quittée.
            if Int(now.timeIntervalSince1970) % 15 == 0 {
                record?.focusedSeconds = elapsed
            }
            if remaining <= 0 {
                closeSegment()
                transition(to: .awaitingOutcome)
                SystemBridge.requestAttention()
                if Rules.current.dndEnabled, let title = current?.action.content {
                    Task {
                        await DoNotDisturb.shared.settle()
                        Notifier.shared.notifyNow(Notifier.focusEnd, title: "Session terminée", body: title)
                    }
                }
            }
        case .onBreak:
            if breakRemaining <= 0 {
                endBreak()
                transition(to: .idle)
            }
        default:
            break
        }
        if phase == .idle || phase == .awaitingOutcome {
            stopTicker()
        }
    }

    /// Les sessions restées « en cours » viennent d'une app quittée en pleine session.
    private func closeStaleSessions() {
        let inProgress = SessionOutcome.inProgress.rawValue
        let descriptor = FetchDescriptor<FocusSession>(predicate: #Predicate { $0.outcomeRaw == inProgress })
        guard let stale = try? context.fetch(descriptor), !stale.isEmpty else { return }
        for session in stale {
            session.outcome = .abandoned
            session.endedAt = session.startedAt.addingTimeInterval(session.focusedSeconds)
        }
        save()
    }

    private func save() {
        try? context.save()
    }
}
