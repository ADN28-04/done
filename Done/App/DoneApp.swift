import SwiftData
import SwiftUI

@main
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
        DoNotDisturb.shared.onError = { [weak model] message in model?.errorMessage = message }
        SystemBridge.onTerminate { DoNotDisturb.shared.turnOffBeforeExit() }
    }

    var body: some Scene {
        Window("Done", id: "main") {
            RootView()
                .environment(model)
                .environment(engine)
                .font(.done(.body))
                .foregroundStyle(DoneColor.textPrimary)
                .tint(DoneColor.stateActive)
                .frame(minWidth: 1000, minHeight: 660)
        }
        .modelContainer(container)
        // Le contenu monte sous la barre de titre : barre latérale et barre du haut maison.
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
            MenuBarLabel(engine: engine)
        }
        .menuBarExtraStyle(.window)
    }
}
