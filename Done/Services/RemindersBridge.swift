import EventKit
import Foundation

/// Boîte d'arrivée Rappels : Done lit la liste de capture (« Done » par défaut, remplie depuis l'iPhone),
/// applique chaque rappel aux tâches selon `RemindersInbox`, puis supprime les rappels traités. Elle passe
/// au lancement, à chaque changement apporté par iCloud et toutes les cinq minutes. Rien d'autre ne
/// repart vers Rappels, sauf une note sur un rappel ambigu.
@Observable
@MainActor
final class RemindersBridge {
    static let shared = RemindersBridge()
    static let defaultList = "Done"

    enum Status: Equatable {
        case off
        case denied
        case missingList(String)
        case ready
        case failed(String)
    }

    private(set) var status: Status = .off
    private(set) var lastPass: Date?
    /// « 2 ajoutées, 1 mise à jour », ou « rien de nouveau ».
    private(set) var lastReport: String?

    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private weak var model: AppModel?
    @ObservationIgnored private var observer: NSObjectProtocol?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var isRunning = false
    @ObservationIgnored private var runAgain = false

    private init() {}

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: SettingsKey.remindersEnabled) }

    var listName: String {
        let name = UserDefaults.standard.string(forKey: SettingsKey.remindersList)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? Self.defaultList : name
    }

    /// Au lancement : branche le modèle, écoute les changements venus d'iCloud et fait un premier passage.
    func start(model: AppModel) {
        self.model = model
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { _ in
            Task { @MainActor in await RemindersBridge.shared.sync() }
        }
        // Filet de sécurité si une notification d'iCloud se perd.
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task { @MainActor in await RemindersBridge.shared.sync() }
        }
        Task { await sync() }
    }

    /// Lit la liste et traite ses rappels. Un appel pendant un passage en relance un autre à la fin.
    func sync() async {
        guard !isRunning else {
            runAgain = true
            return
        }
        isRunning = true
        repeat {
            runAgain = false
            await pass()
        } while runAgain
        isRunning = false
    }

    private func pass() async {
        guard isEnabled, let model else {
            status = .off
            return
        }
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess:
            break
        case .notDetermined:
            do {
                guard try await store.requestFullAccessToReminders() else {
                    status = .denied
                    return
                }
            } catch {
                status = .failed(error.localizedDescription)
                return
            }
        default:
            status = .denied
            return
        }

        let name = listName
        guard let list = store.calendars(for: .reminder).first(where: {
            $0.title.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) else {
            status = .missingList(name)
            return
        }
        let reminders: [EKReminder] = await withCheckedContinuation { continuation in
            store.fetchReminders(matching: store.predicateForReminders(in: [list])) { found in
                continuation.resume(returning: found ?? [])
            }
        }

        var created = 0, updated = 0, completed = 0, waiting = 0
        var changed = false
        var failure: String?
        for reminder in reminders {
            switch RemindersInbox.action(for: ReminderItem(reminder), in: model.store) {
            case .create(let draft):
                if model.addTask(draft) != nil { created += 1 }
            case .update(let task):
                model.update(task)
                updated += 1
            case .complete(let id):
                if let task = model.store[id] {
                    model.complete(task)
                    completed += 1
                }
            case .ignore:
                break
            case .ambiguous(let count):
                // Le rappel reste, avec une note pour le préciser depuis l'iPhone.
                waiting += 1
                let notes = reminder.notes ?? ""
                if !notes.hasPrefix(ambiguityPrefix) {
                    let note = "\(ambiguityPrefix) \(count) tâches ouvertes portent ce titre. Modifie-le pour désigner la bonne."
                    reminder.notes = notes.isEmpty ? note : note + "\n\n" + notes
                    try? store.save(reminder, commit: false)
                    changed = true
                }
                continue
            }
            do {
                try store.remove(reminder, commit: false)
                changed = true
            } catch {
                failure = "rappel « \(reminder.title ?? "") » non supprimé : \(error.localizedDescription)"
            }
        }
        if changed {
            do {
                try store.commit()
            } catch {
                status = .failed(error.localizedDescription)
                return
            }
        }

        lastPass = .now
        let parts = [
            created > 0 ? "\(created) ajoutée\(created > 1 ? "s" : "")" : nil,
            updated > 0 ? "\(updated) mise\(updated > 1 ? "s" : "") à jour" : nil,
            completed > 0 ? "\(completed) cochée\(completed > 1 ? "s" : "")" : nil,
            waiting > 0 ? "\(waiting) à préciser" : nil,
        ].compactMap { $0 }
        lastReport = parts.isEmpty ? "rien de nouveau" : parts.joined(separator: ", ")
        status = failure.map(Status.failed) ?? .ready
    }
}

/// Début de la note que Done laisse sur un rappel ambigu, retirée quand le rappel est relu.
private let ambiguityPrefix = "Done :"

private extension ReminderItem {
    init(_ reminder: EKReminder) {
        let due = reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
        var notes = reminder.notes ?? ""
        if notes.hasPrefix(ambiguityPrefix) {
            notes = notes.components(separatedBy: "\n\n").dropFirst().joined(separator: "\n\n")
        }
        self.init(
            id: reminder.calendarItemIdentifier,
            title: reminder.title ?? "",
            notes: notes,
            url: reminder.url?.absoluteString,
            due: due.map { Calendar.current.startOfDay(for: $0) },
            priority: reminder.priority,
            isCompleted: reminder.isCompleted
        )
    }
}
