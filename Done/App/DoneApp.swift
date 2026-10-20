import SwiftData
import SwiftUI

@main
struct DoneApp: App {
    private let container: ModelContainer
    @State private var model: AppModel
    @State private var engine: FocusEngine

    init() {
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
    }

    var body: some Scene {
        Window("Done", id: "main") {
            RootView()
                .environment(model)
                .environment(engine)
                .frame(minWidth: 860, minHeight: 580)
        }
        .modelContainer(container)

        // Le minuteur reste visible dans la barre de menus, même fenêtre fermée.
        MenuBarExtra {
            MenuBarView()
                .environment(model)
                .environment(engine)
        } label: {
            MenuBarLabel(engine: engine)
        }
        .menuBarExtraStyle(.window)
    }
}
