import SwiftUI

struct RootView: View {
    enum Screen: Hashable {
        /// Ma journée : l'écran d'arrivée, et la session de focus en plein écran.
        case home
        case calendar
        case notes
        /// L'écran Listes, sur une liste : l'Inbox, un projet ou une étiquette.
        case lists(TaskList)
        case stats
        case settings
    }

    @Environment(AppModel.self) private var model
    @Environment(FocusEngine.self) private var engine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var screen: Screen = .home
    /// La dernière liste ouverte : ⌘4 et le rail y reviennent.
    @State private var lastList: TaskList = .inbox
    @State private var revealRail = false
    @State private var showCapture = false
    /// ⌘K : la recherche de Ma journée prend le focus.
    @State private var searchRequested = false
    /// Augmente quand le plan du jour vient d'être bouclé : éclat sur le bouton Ma journée du rail.
    @State private var planCelebrations = 0
    /// Bloc de travail à déplacer, ouvert depuis son rappel.
    @State private var blockToMove: WorkBlock?

    var body: some View {
        ZStack(alignment: .leading) {
            HStack(spacing: 0) {
                if !inSession {
                    rail
                        .transition(railTransition)
                }
                content
            }
            if inSession {
                // Bord gauche : le rail revient au survol, par-dessus la session.
                Color.clear
                    .frame(width: 12)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onHover { inside in
                        if inside { revealRail = true }
                    }
                if revealRail {
                    rail
                        .shadow(color: DoneColor.shadowRaised, radius: 14, x: 4)
                        .onHover { inside in
                            if !inside { revealRail = false }
                        }
                        .transition(railTransition)
                }
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .animation(DoneMotion.motion(DoneMotion.move, reduced: reduceMotion), value: inSession)
        .animation(DoneMotion.motion(DoneMotion.move, reduced: reduceMotion), value: revealRail)
        .background {
            ShortcutKeys(
                open: open,
                openLists: { open(.lists(lastList)) },
                onCapture: { showCapture = true },
                onSearch: {
                    screen = .home
                    if engine.phase == .idle { searchRequested = true }
                }
            )
        }
        .onChange(of: inSession) { revealRail = false }
        .onChange(of: model.isPlanFinished) { _, finished in
            if finished { planCelebrations += 1 }
        }
        // Rappel d'un bloc de travail, ou sa fiche : lancer le pomodoro, ou ouvrir le bloc pour le déplacer.
        .onChange(of: model.workBlockRequest) { _, request in
            guard let request else { return }
            model.workBlockRequest = nil
            handle(request)
        }
        // Rappel quand rien n'est lancé : « Lancer le pomodoro » part sur la prochaine action du plan.
        .onChange(of: model.startNextRequest) { _, request in
            guard request != nil else { return }
            model.startNextRequest = nil
            startNextAction()
        }
        .sheet(item: $blockToMove) { block in
            WorkBlockSheet(blockID: block.id)
                .environment(model)
        }
        .sheet(isPresented: $showCapture) {
            CaptureSheet()
                .environment(model)
        }
    }

    /// Le rail : l'écran affiché, l'Inbox à trier, et le minuteur d'une session qui tourne ailleurs.
    private var rail: some View {
        // Chaque seconde pendant une session, pour le minuteur ; sinon chaque minute.
        TimelineView(.periodic(from: .now, by: engine.phase == .idle ? 60 : 1)) { _ in
            Rail(
                selection: railSelection,
                inboxCount: model.openCount(in: .inbox),
                timer: engine.phase == .idle || inSession ? nil : engine.menuBarText,
                homeBursts: planCelebrations,
                onCapture: { showCapture = true },
                onSelect: { destination in
                    revealRail = false
                    switch destination {
                    case .home: open(.home)
                    case .calendar: open(.calendar)
                    case .notes: open(.notes)
                    case .lists: open(.lists(lastList))
                    case .stats: open(.stats)
                    case .settings: open(.settings)
                    }
                },
                onTimer: { open(.home) }
            )
        }
    }

    private var railSelection: RailDestination? {
        switch screen {
        case .home: .home
        case .calendar: .calendar
        case .notes: .notes
        case .lists: .lists
        case .stats: .stats
        case .settings: .settings
        }
    }

    /// « Lancer le pomodoro » : la session part sur la prochaine action de la tâche du bloc, pour un
    /// pomodoro selon son type (ou la pause due avant de changer de tâche principale). « Déplacer… » :
    /// le calendrier s'ouvre avec la fiche du bloc.
    private func handle(_ request: AppModel.WorkBlockRequest) {
        guard let block = model.workBlock(request.blockID) else { return }
        switch request.action {
        case .move:
            open(.calendar)
            blockToMove = block
        case .start:
            open(.home)
            guard engine.phase == .idle, let task = model.store[block.taskID], task.isOpen else { return }
            let now = Date.now
            let root = model.index.root(of: task)
            if engine.needsBreak(before: root, now: now), let pause = engine.breakDue?.remainingMinutes(now: now) {
                engine.takeBreak(minutes: pause, mandatory: true)
                return
            }
            let action = Planner.nextAction(for: task, in: model.index, rules: model.rules, now: now) ?? task
            engine.start(action: action, root: root, minutes: Planner.minutes(for: action, root: root, rules: model.rules))
        }
    }

    /// La prochaine action du plan, ou la pause due avant de changer de tâche principale. Sans plan ni
    /// action faisable, Ma journée s'ouvre seulement : sa carte dit quoi faire.
    private func startNextAction() {
        open(.home)
        guard engine.phase == .idle else { return }
        let now = Date.now
        let suggestion = Planner.suggest(plan: model.planIDs, index: model.index, meetings: model.meetingsToday, rules: model.rules, now: now)
        guard suggestion.status == .ready, let action = suggestion.action, let root = suggestion.planTask else { return }
        if engine.needsBreak(before: root, now: now), let pause = engine.breakDue?.remainingMinutes(now: now) {
            engine.takeBreak(minutes: pause, mandatory: true)
        } else {
            engine.start(action: action, root: root, minutes: suggestion.minutes)
        }
    }

    private func open(_ target: Screen) {
        if case .lists(let list) = target { lastList = list }
        screen = target
    }

    /// Le rail glisse depuis la gauche ; avec « Réduire les animations », il apparaît en fondu.
    private var railTransition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .leading)
    }

    /// Sur Ma journée, toute phase autre que le repos est une session : le rail s'efface, il ne reste
    /// que la tâche et le minuteur. Ailleurs, la session continue et le rail montre son minuteur.
    private var inSession: Bool {
        screen == .home && engine.phase != .idle
    }

    private var content: some View {
        VStack(spacing: 0) {
            if let message = model.errorMessage {
                ErrorBanner(message: message) { model.errorMessage = nil }
                    .padding(.horizontal, DoneSpace.s32)
                    .padding(.top, DoneSpace.s20)
                    .padding(.bottom, DoneSpace.s8)
            }
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            // La lumière change en dur-slow, en même temps que l'anneau de la pause arrive.
            DoneCanvas(isOnBreak: isOnBreak)
        }
    }

    /// Fond bleuté pendant la pause, sans halos : on sait dans quelle phase on est sans lire.
    private var isOnBreak: Bool {
        screen == .home && engine.phase == .onBreak
    }

    @ViewBuilder
    private var detail: some View {
        switch screen {
        case .home:
            if engine.phase == .idle {
                HomeView(searchRequested: $searchRequested, onCapture: { showCapture = true }, open: open)
            } else {
                SessionScreen()
            }
        case .calendar:
            CalendarView()
                .padding(.top, 26)
        case .notes:
            NotesView()
                .padding(.top, 26)
        case .lists:
            ListsView(list: Binding(
                get: {
                    if case .lists(let list) = screen { return list }
                    return lastList
                },
                set: { open(.lists($0)) }
            ))
        case .stats:
            StatsView()
                .padding(.top, 26)
        case .settings:
            SettingsView()
                .padding(.top, 26)
        }
    }
}

/// La session de focus en plein écran : une réunion en cours en haut quand la session est interrompue,
/// puis la phase (minuteur, interruption, bilan de la session, pause).
private struct SessionScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(FocusEngine.self) private var engine

    var body: some View {
        VStack(spacing: 0) {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                HStack {
                    if isInterrupted, let pill = MeetingPill.make(meetings: model.meetingsToday, now: context.date, includeNext: false) {
                        MeetingPill(content: pill)
                    }
                }
                .frame(height: 52)
            }
            FocusView()
        }
    }

    private var isInterrupted: Bool {
        if case .interrupted = engine.phase { return true }
        return false
    }
}

/// Raccourcis clavier, toujours actifs, même en session quand le rail est masqué.
private struct ShortcutKeys: View {
    let open: (RootView.Screen) -> Void
    /// ⌘4 : la dernière liste ouverte.
    let openLists: () -> Void
    let onCapture: () -> Void
    let onSearch: () -> Void

    var body: some View {
        ZStack {
            Button("Ma journée") { open(.home) }
                .keyboardShortcut("1")
            Button("Calendrier") { open(.calendar) }
                .keyboardShortcut("2")
            Button("Notes") { open(.notes) }
                .keyboardShortcut("3")
            Button("Listes", action: openLists)
                .keyboardShortcut("4")
            Button("Stats") { open(.stats) }
                .keyboardShortcut("5")
            Button("Réglages") { open(.settings) }
                .keyboardShortcut(",")
            Button("Nouvelle tâche", action: onCapture)
                .keyboardShortcut("n")
            Button("Rechercher", action: onSearch)
                .keyboardShortcut("k")
        }
        .buttonStyle(.plain)
        .opacity(0)
        .frame(width: 1, height: 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Pastille de réunion : pleine (meeting.now) pendant une réunion, hachurée pour la prochaine.
struct MeetingPill: View {
    struct Content {
        let text: String
        let isOngoing: Bool
        let help: String
    }

    let content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DoneRadius.sm, style: .continuous)
        Text(content.text)
            .font(.sans(13, .medium))
            .foregroundStyle(content.isOngoing ? DoneColor.meetingOnNow : DoneColor.textPrimary)
            .lineLimit(1)
            .padding(.horizontal, DoneSpace.s12)
            .frame(height: 28)
            .background {
                if content.isOngoing {
                    shape.fill(DoneColor.meetingNow)
                } else {
                    ZStack {
                        DoneColor.meetingBg
                        Hatching()
                    }
                    .clipShape(shape)
                }
            }
            .help(content.help)
    }

    static func make(meetings: [Meeting], now: Date, includeNext: Bool) -> Content? {
        if let ongoing = meetings.first(where: { $0.contains(now) }) {
            return Content(text: "\(ongoing.title) · fin \(Format.time(ongoing.end))", isOngoing: true, help: "Réunion en cours")
        }
        guard includeNext, let next = meetings.first(where: { $0.start > now }) else { return nil }
        let minutes = Format.minutes(next.start.timeIntervalSince(now) / 60)
        return Content(text: "\(next.title) à \(Format.time(next.start)) · dans \(minutes)", isOngoing: false, help: "Prochaine réunion")
    }
}

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: DoneSpace.s8) {
            NoticeBox(text: message, tone: .error)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DoneColor.textSecondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Masquer")
        }
        .frame(maxWidth: 640)
    }
}
