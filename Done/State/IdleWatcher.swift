import Foundation

/// Regarde chaque minute si rien n'est lancé depuis 20 min (`IdleReminder`), et envoie alors le rappel.
/// Tourne tant que Done tourne, même fenêtre fermée. Une session ou une pause remet le compte à zéro.
@MainActor
final class IdleWatcher {
    static let shared = IdleWatcher()

    private weak var model: AppModel?
    private weak var engine: FocusEngine?
    private var timer: Timer?
    /// Depuis quand rien ne tourne : le lancement de Done, puis la fin de la dernière session ou pause.
    private(set) var idleSince = Date.now
    private(set) var lastReminder: Date?
    /// Dernier passage. Un long trou (Mac en veille) remet le compte à zéro : pas de rappel au réveil.
    private var lastCheck: Date?

    func start(model: AppModel, engine: FocusEngine) {
        self.model = model
        self.engine = engine
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.check() }
        }
    }

    func check(now: Date = .now) {
        guard let model, let engine else { return }
        defer { lastCheck = now }
        if let lastCheck, now.timeIntervalSince(lastCheck) > 5 * 60 {
            idleSince = now
            return
        }
        // Une session, une interruption, une fin de session ou une pause : le compte repart de là.
        guard engine.phase == .idle else {
            idleSince = now
            return
        }
        guard Rules.current.idleReminder else { return }
        guard IdleReminder.isDue(
            now: now,
            idleSince: idleSince,
            lastReminder: lastReminder,
            store: model.store,
            absence: model.absence(on: now) != nil
        ) else { return }
        let suggestion = Planner.suggest(
            plan: model.planIDs,
            index: model.index,
            meetings: model.meetingsToday,
            rules: model.rules,
            now: now
        )
        // Une réunion trop proche pour un pomodoro : rien à proposer, le rappel attend.
        guard suggestion.status != .noTimeBeforeMeeting else { return }
        let message = IdleReminder.message(nextAction: suggestion.status == .ready ? suggestion.action?.title : nil)
        lastReminder = now
        Notifier.shared.notifyIdle(title: message.title, body: message.body)
    }
}
