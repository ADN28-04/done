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
        /// Change quand on enchaîne sur l'étape suivante dans le même pomodoro.
        var action: TodoTask
        let root: TodoTask
        let projectName: String
        /// Durée du pomodoro, rallonge comprise.
        var planned: TimeInterval
    }

    private(set) var phase: Phase = .idle
    private(set) var current: Current?
    /// Avance chaque seconde tant qu'un minuteur tourne : les vues s'y abonnent.
    private(set) var now = Date()
    private(set) var interruptedAt: Date?
    private(set) var breakEnd: Date?
    private(set) var breakDuration: TimeInterval = 0
    /// Minutes ajoutées à ce pomodoro.
    private(set) var extendedSeconds: TimeInterval = 0
    /// Action cochée avant la fin du pomodoro : l'écran de fin propose la suite.
    private(set) var checkedAction: TodoTask?
    private(set) var followUp: Planner.FollowUp?
    /// Pause entre deux tâches principales : elle ne se passe pas.
    private(set) var breakIsMandatory = false
    /// Pause due avant de changer de tâche principale.
    private(set) var breakDue: BreakDue?

    private var elapsedBefore: TimeInterval = 0
    private var segmentStart: Date?
    /// Temps du pomodoro déjà compté dans les étapes précédentes, quand on enchaîne.
    @ObservationIgnored private var recordOffset: TimeInterval = 0
    /// Tâche principale de la session qui précède la pause en cours.
    @ObservationIgnored private var breakRootID: String?

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

    /// Temps passé sur l'action en cours, sans les étapes déjà cochées de ce pomodoro.
    var stepElapsed: TimeInterval { max(0, elapsed - recordOffset) }

    var breakRemaining: TimeInterval { max(0, (breakEnd ?? now).timeIntervalSince(now)) }

    /// Part restante du minuteur, pour l'anneau qui se vide depuis le haut.
    var remainingFraction: Double {
        guard let planned = current?.planned, planned > 0 else { return 0 }
        return remaining / planned
    }

    var breakRemainingFraction: Double {
        breakDuration > 0 ? breakRemaining / breakDuration : 0
    }

    /// Pause longue après un pomodoro long, courte sinon.
    var breakMinutesAfterSession: Int {
        let rules = Rules.current
        let wasLong = (current?.planned ?? 0) >= TimeInterval(rules.deepworkMinutes * 60)
        return wasLong ? rules.longBreakMinutes : rules.shortBreakMinutes
    }

    var canExtend: Bool {
        current != nil && checkedAction == nil && extendedSeconds < TimeInterval(Rules.maxExtensionMinutes * 60)
    }

    /// Changer de tâche principale juste après une session demande d'abord une pause.
    func needsBreak(before root: TodoTask, now: Date = .now) -> Bool {
        breakDue?.blocks(rootID: root.id, now: now) ?? false
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

    func start(action: TodoTask, root: TodoTask, minutes: Int) {
        endBreak()
        let planned = TimeInterval(max(1, minutes) * 60)
        let projectName = model.listName(for: root)
        current = Current(action: action, root: root, projectName: projectName, planned: planned)
        elapsedBefore = 0
        recordOffset = 0
        extendedSeconds = 0
        checkedAction = nil
        followUp = nil
        breakDue = nil
        segmentStart = .now
        now = .now
        interruptedAt = nil

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

    /// L'action est finie : on la coche, puis on décide de la suite.
    /// Étape suivante de la même tâche et du temps devant soi : l'écran de fin propose d'enchaîner.
    /// Tâche principale finie : pause obligatoire avant la suivante.
    func markDone() {
        guard let current else { return }
        model.complete(current.action)
        finishRecord(.done)
        let next = Planner.followUp(after: current.action, root: current.root, in: model.index, rules: Rules.current)
        switch next {
        case .step:
            if remaining >= Rules.minChainSeconds {
                checkedAction = current.action
                followUp = next
            } else {
                startBreakAfterSession(mandatory: false)
            }
        case .closeRoot:
            checkedAction = current.action
            followUp = next
        case .switchTask:
            startBreakAfterSession(mandatory: true)
        }
    }

    /// Enchaîne sur l'étape suivante de la même tâche, dans le temps qui reste au pomodoro.
    func chainToNext() {
        guard case .step(let next)? = followUp, remaining > 0 else { return }
        startStep(next)
    }

    /// Bloqué sur l'action : elle reste ouverte mais n'est plus proposée, et on passe à l'étape
    /// suivante de la même tâche. Faute d'étape, pause obligatoire avant une autre tâche.
    func markBlocked(reason: String) {
        guard let current else { return }
        model.markBlocked(current.action, reason: reason)
        closeSegment()
        closeInterruption()
        finishRecord(.partial)
        switch Planner.followUp(blocking: current.action, root: current.root, in: model.index, rules: Rules.current) {
        case .step(let next) where remaining >= Rules.minChainSeconds:
            startStep(next)
        case .step:
            startBreakAfterSession(mandatory: false)
        case .closeRoot, .switchTask:
            startBreakAfterSession(mandatory: true)
        }
    }

    /// Toutes les étapes sont faites : coche la tâche principale, puis pause obligatoire.
    func closeRoot() {
        guard case .closeRoot(let root)? = followUp else { return }
        model.complete(root)
        startBreakAfterSession(mandatory: true)
    }

    /// Ajoute quelques minutes au pomodoro, 10 au plus en tout. Relance le minuteur s'il était fini.
    func extend(minutes: Int = Rules.extensionStepMinutes) {
        guard var current = self.current, checkedAction == nil else { return }
        let added = min(TimeInterval(minutes * 60), TimeInterval(Rules.maxExtensionMinutes * 60) - extendedSeconds)
        guard added > 0 else { return }
        current.planned += added
        self.current = current
        extendedSeconds += added
        record?.plannedSeconds += added
        switch phase {
        case .focusing:
            scheduleFocusEnd()
        case .awaitingOutcome:
            segmentStart = .now
            now = .now
            transition(to: .focusing)
            scheduleFocusEnd()
            startTicker()
        default:
            // En pause ou interrompu : le temps ajouté attend la reprise.
            break
        }
        save()
    }

    /// Pause sans cocher la tâche, ou après une étape cochée.
    func takeBreakAfterSession() {
        guard current != nil else { return }
        finishRecord(.partial)
        startBreakAfterSession(mandatory: false)
    }

    /// Pause libre, par exemple avant une réunion, ou obligatoire avant de changer de tâche.
    func takeBreak(minutes: Int, mandatory: Bool = false) {
        if current != nil { stop(as: .partial) }
        beginBreak(seconds: TimeInterval(max(1, minutes) * 60), mandatory: mandatory)
    }

    /// Retour à l'écran Focus sans pause. Sauf après une interruption, une pause reste due
    /// avant de passer à une autre tâche principale.
    func stop(as outcome: SessionOutcome) {
        let root = current?.root
        closeSegment()
        closeInterruption()
        finishRecord(outcome)
        reset()
        if let root, outcome != .interrupted {
            breakDue = BreakDue(rootID: root.id, minutes: Rules.current.shortBreakMinutes, since: .now)
        }
    }

    /// Sans effet sur une pause obligatoire. Une pause passée reste due avant de changer de tâche principale.
    func skipBreak() {
        guard !breakIsMandatory else { return }
        let rootID = breakRootID
        endBreak()
        transition(to: .idle)
        stopTicker()
        if let rootID {
            breakDue = BreakDue(rootID: rootID, minutes: Rules.current.shortBreakMinutes, since: .now)
        }
    }

    // MARK: Interne

    private var isInterrupted: Bool {
        if case .interrupted = phase { return true }
        return false
    }

    /// Lance `next` dans le temps qui reste au pomodoro, avec sa propre session.
    private func startStep(_ next: TodoTask) {
        guard var current = self.current else { return }
        current.action = next
        self.current = current
        let session = FocusSession(action: next, root: current.root, projectName: current.projectName, plannedSeconds: remaining)
        context.insert(session)
        record = session
        recordOffset = elapsedBefore
        checkedAction = nil
        followUp = nil
        interruptedAt = nil
        segmentStart = .now
        now = .now
        transition(to: .focusing)
        scheduleFocusEnd()
        startTicker()
        save()
    }

    private func startBreakAfterSession(mandatory: Bool) {
        beginBreak(seconds: TimeInterval(breakMinutesAfterSession * 60), mandatory: mandatory)
    }

    private func beginBreak(seconds: TimeInterval, mandatory: Bool) {
        let rootID = current?.root.id ?? breakDue?.rootID
        reset()
        breakRootID = rootID
        now = .now
        breakEnd = now.addingTimeInterval(seconds)
        breakDuration = seconds
        breakIsMandatory = mandatory
        breakDue = nil
        transition(to: .onBreak)
        Notifier.shared.schedule(
            Notifier.breakEnd,
            title: "Fin de la pause",
            body: "Ta prochaine tâche t'attend dans Done.",
            after: seconds,
            sound: !Rules.current.endSound
        )
        startTicker()
    }

    private func endBreak() {
        breakEnd = nil
        breakIsMandatory = false
        breakRootID = nil
        Notifier.shared.cancel(Notifier.breakEnd)
    }

    private func reset() {
        current = nil
        elapsedBefore = 0
        recordOffset = 0
        extendedSeconds = 0
        checkedAction = nil
        followUp = nil
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
        record?.focusedSeconds = elapsedBefore - recordOffset
    }

    private func closeInterruption() {
        openInterruption?.endedAt = .now
        openInterruption = nil
        interruptedAt = nil
    }

    private func finishRecord(_ outcome: SessionOutcome) {
        guard let record else { return }
        record.focusedSeconds = elapsedBefore - recordOffset
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
            body: current.action.title,
            after: remaining,
            sound: !Rules.current.endSound
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
                record?.focusedSeconds = elapsed - recordOffset
            }
            if remaining <= 0 {
                closeSegment()
                transition(to: .awaitingOutcome)
                // Son et Dock : la fin se remarque même sans notification.
                let rules = Rules.current
                if rules.endSound { SystemBridge.playSound("Glass") }
                SystemBridge.requestAttention()
                if rules.dndEnabled, let title = current?.action.title {
                    Task {
                        await DoNotDisturb.shared.settle()
                        Notifier.shared.notifyNow(Notifier.focusEnd, title: "Session terminée", body: title, sound: !rules.endSound)
                    }
                }
            }
        case .onBreak:
            if breakRemaining <= 0 {
                endBreak()
                transition(to: .idle)
                if Rules.current.endSound { SystemBridge.playSound("Hero") }
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
