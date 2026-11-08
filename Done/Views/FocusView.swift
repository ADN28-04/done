import SwiftUI

/// Session de focus, en plein écran : une seule chose à la fois. Au repos, Ma journée prend la place.
struct FocusView: View {
    @Environment(AppModel.self) private var model
    @Environment(FocusEngine.self) private var engine
    @State private var showBlocked = false

    var body: some View {
        Group {
            switch engine.phase {
            case .idle:
                EmptyView()
            case .focusing, .paused:
                SessionView { showBlocked = true }
            case .interrupted(let reason):
                InterruptionView(reason: reason)
            case .awaitingOutcome:
                OutcomeView { showBlocked = true }
            case .onBreak:
                BreakView()
            }
        }
        .padding(.horizontal, 48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Ici plutôt que sur l'écran de session : la feuille reste ouverte si le minuteur sonne pendant la saisie.
        .sheet(isPresented: $showBlocked) {
            BlockedSheet()
                .environment(model)
                .environment(engine)
        }
    }
}
