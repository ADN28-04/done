import SwiftData
import SwiftUI

/// L'app. Le point d'entrée est `Launcher`, qui lance aussi le connecteur Claude.
struct DoneApp: App {
    private let container: ModelContainer
    @State private var model: AppModel
    @State private var engine: FocusEngine

    init() {
        FontLoader.registerBundledFonts()
        let container: ModelContainer
        do {
            container = try ModelContainer(for: DayPlan.self, FocusSession.self, Interruption.self, BacklogSnapshot.self)
        } catch {
            fatalError("Impossible d'ouvrir la base locale : \(error)")
        }
        self.container = container
        let model = AppModel(context: container.mainContext)
        _model = State(initialValue: model)
        _engine = State(initialValue: FocusEngine(model: model, context: container.mainContext))
        Notifier.shared.setUp()
        Notifier.shared.updateReviewReminder(enabled: Rules.current.reviewReminder, hour: Rules.current.reviewHour)
        model.updateMeetingReminders()
        model.updateWorkBlockReminders()
        // Rappel d'un bloc de travail : « Lancer le pomodoro » ou « Déplacer… ».
        Notifier.shared.onWorkBlock = { [weak model] blockID, start in
            model?.requestWorkBlock(blockID, start ? .start : .move)
        }
        DoNotDisturb.shared.onError = { [weak model] message in model?.errorMessage = message }
        SystemBridge.onTerminate { DoNotDisturb.shared.turnOffBeforeExit() }
        // Une tâche cochée juste avant de quitter reste cochée.
        SystemBridge.onTerminate { [weak model] in model?.flushFinishing() }
        // Saisie flottante, par le raccourci global choisi dans les réglages.
        QuickCapturePanel.shared.configure(model: model)
        // Boîte d'arrivée Rappels, si elle est activée dans les réglages.
        RemindersBridge.shared.start(model: model)
        // Notes : fichiers Markdown du dossier Notes, relus dès qu'il change.
        NoteBook.shared.start()
        // Connecteur Claude : tâches et plan du jour relus dès qu'il les change.
        model.startWatching()
    }

    var body: some Scene {
        Window("Done", id: "main") {
            RootView()
                .environment(model)
                .environment(engine)
                .font(.done(.body))
                .foregroundStyle(DoneColor.textPrimary)
                .tint(DoneColor.stateActive)
                .frame(minWidth: 1100, minHeight: 680)
        }
        .modelContainer(container)
        // Le contenu monte sous la barre de titre : le rail commence sous les feux de la fenêtre.
        .windowStyle(.hiddenTitleBar)

        // Le minuteur reste visible dans la barre de menus, même fenêtre fermée, et la capture rapide y est à un clic.
        MenuBarExtra {
            MenuBarView()
                .environment(model)
                .environment(engine)
                .font(.done(.body))
                .foregroundStyle(DoneColor.textPrimary)
                .tint(DoneColor.stateActive)
        } label: {
            MenuBarLabel(engine: engine, model: model)
        }
        .menuBarExtraStyle(.window)
    }
}
