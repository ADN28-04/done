import SwiftUI

struct RootView: View {
    enum Screen: Hashable {
        case focus
        case plan
        case calendar
        /// Une liste de tâches : l'Inbox, un projet ou une étiquette.
        case list(TaskList)
        case stats
        case settings
    }

    @Environment(AppModel.self) private var model
    @Environment(FocusEngine.self) private var engine
    @State private var screen: Screen = .focus
    @State private var choseInitialScreen = false
    @State private var revealSidebar = false
    @State private var showCapture = false

    var body: some View {
        ZStack(alignment: .leading) {
            HStack(spacing: 0) {
                if !inSession {
                    Sidebar(screen: $screen)
                        .transition(.move(edge: .leading))
                }
                content
            }
            if inSession {
                // Bord gauche : la barre latérale revient au survol, par-dessus la session.
                Color.clear
                    .frame(width: 12)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onHover { inside in
                        if inside { revealSidebar = true }
                    }
                if revealSidebar {
                    Sidebar(screen: $screen)
                        .shadow(color: DoneColor.shadowRaised, radius: 14, x: 4)
                        .onHover { inside in
                            if !inside { revealSidebar = false }
                        }
                        .transition(.move(edge: .leading))
                }
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .animation(.easeInOut(duration: 0.25), value: inSession)
        .animation(.easeInOut(duration: 0.2), value: revealSidebar)
        .background { ShortcutKeys(screen: $screen) { showCapture = true } }
        .onChange(of: inSession) { revealSidebar = false }
        .onAppear {
            if !choseInitialScreen {
                if model.index.all.isEmpty {
                    screen = .list(.inbox)
                } else {
                    screen = model.todayPlan == nil ? .plan : .focus
                }
                choseInitialScreen = true
            }
        }
        .sheet(isPresented: $showCapture) {
            CaptureSheet()
                .environment(model)
        }
    }

    /// Sur l'écran Focus, toute phase autre que le repos est une session :
    /// la navigation s'efface, il ne reste que la tâche et le minuteur.
    private var inSession: Bool {
        screen == .focus && engine.phase != .idle
    }

    private var content: some View {
        VStack(spacing: 0) {
            TopBar(screen: screen, inSession: inSession) { showCapture = true }
            if let message = model.errorMessage {
                ErrorBanner(message: message) { model.errorMessage = nil }
                    .padding(.horizontal, DoneSpace.s32)
                    .padding(.bottom, DoneSpace.s8)
            }
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(contentBackground)
    }

    /// Fond lavande pendant la pause : on sait dans quelle phase on est sans lire.
    private var contentBackground: Color {
        screen == .focus && engine.phase == .onBreak ? DoneColor.pomodoroBreakBg : DoneColor.bgCanvas
    }

    @ViewBuilder
    private var detail: some View {
        switch screen {
        case .focus:
            FocusView(openPlan: { screen = .plan }, openTasks: { screen = .list(.inbox) })
        case .plan:
            PlanView(onValidate: { screen = .focus })
        case .calendar:
            CalendarView()
        case .list(let list):
            TaskListView(list: list)
                .id(list)
        case .stats:
            StatsView()
        case .settings:
            SettingsView()
        }
    }
}

/// Raccourcis clavier, toujours actifs, même en session quand la barre latérale est masquée.
private struct ShortcutKeys: View {
    @Binding var screen: RootView.Screen
    let onCapture: () -> Void

    var body: some View {
        ZStack {
            Button("Focus") { screen = .focus }
                .keyboardShortcut("1")
            Button("Plan du jour") { screen = .plan }
                .keyboardShortcut("2")
            Button("Inbox") { screen = .list(.inbox) }
                .keyboardShortcut("3")
            Button("Stats") { screen = .stats }
                .keyboardShortcut("4")
            Button("Calendrier") { screen = .calendar }
                .keyboardShortcut("5")
            Button("Réglages") { screen = .settings }
                .keyboardShortcut(",")
            Button("Nouvelle tâche", action: onCapture)
                .keyboardShortcut("n")
        }
        .buttonStyle(.plain)
        .opacity(0)
        .frame(width: 1, height: 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: Barre latérale

/// Navigation à gauche : Focus et Plan du jour, puis l'Inbox et les projets, puis Stats et Réglages.
private struct Sidebar: View {
    @Environment(AppModel.self) private var model
    @Binding var screen: RootView.Screen

    @State private var dropTarget: String?
    @State private var naming: Naming?
    @State private var nameDraft = ""
    @State private var deletingProject: Project?

    @State private var removingTag: String?

    private enum Naming: Identifiable {
        case new
        case rename(Project)
        case renameTag(String)

        var id: String {
            switch self {
            case .new: "new"
            case .rename(let project): project.id
            case .renameTag(let tag): "tag:" + tag
            }
        }

        var title: String {
            switch self {
            case .new: "Nouveau projet"
            case .rename: "Renommer le projet"
            case .renameTag: "Renommer l'étiquette"
            }
        }

        var action: String {
            switch self {
            case .new: "Créer"
            case .rename, .renameTag: "Renommer"
            }
        }

        var placeholder: String {
            switch self {
            case .new, .rename: "Nom du projet"
            case .renameTag: "Nom de l'étiquette"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DoneSpace.s2) {
            NavItem(title: "Focus", icon: Image("DoneGlyph"), isSelected: screen == .focus) { screen = .focus }
                .help("Focus (⌘1)")
            NavItem(title: "Plan du jour", icon: Image(systemName: "calendar"), counter: planCounter, isSelected: screen == .plan) { screen = .plan }
                .help("Plan du jour (⌘2)")
            NavItem(title: "Calendrier", icon: Image(systemName: "calendar.day.timeline.left"), isSelected: screen == .calendar) { screen = .calendar }
                .help("Calendrier (⌘5)")

            Eyebrow(text: "Listes")
                .padding(.leading, DoneSpace.s8)
                .padding(.top, DoneSpace.s20)
                .padding(.bottom, DoneSpace.s6)
            ScrollView {
                VStack(alignment: .leading, spacing: DoneSpace.s2) {
                    listItem(.inbox, name: "Inbox", symbol: "tray")
                        .help("Inbox (⌘3)")
                    ForEach(model.projects) { project in
                        listItem(.project(project.id), name: project.name, symbol: "folder")
                            .contextMenu { projectMenu(project) }
                    }
                    Button {
                        nameDraft = ""
                        naming = .new
                    } label: {
                        Label("Nouveau projet", systemImage: "plus")
                    }
                    .buttonStyle(DoneButtonStyle(kind: .plain, compact: true))
                    .padding(.top, DoneSpace.s4)
                    if !model.tags.isEmpty {
                        Eyebrow(text: "Étiquettes")
                            .padding(.leading, DoneSpace.s8)
                            .padding(.top, DoneSpace.s16)
                            .padding(.bottom, DoneSpace.s6)
                        ForEach(model.tags, id: \.self) { tag in
                            listItem(.tag(tag), name: tag, symbol: "tag")
                                .contextMenu { tagMenu(tag) }
                        }
                    }
                }
            }
            .scrollIndicators(.never)

            Spacer(minLength: DoneSpace.s16)
            NavItem(title: "Stats", icon: Image(systemName: "chart.bar"), isSelected: screen == .stats) { screen = .stats }
                .help("Stats (⌘4)")
            NavItem(title: "Réglages", icon: Image(systemName: "gearshape"), isSelected: screen == .settings) { screen = .settings }
                .help("Réglages (⌘,)")
        }
        .padding(.horizontal, DoneSpace.s12)
        // Les feux de la fenêtre occupent le haut de la barre.
        .padding(.top, 52)
        .padding(.bottom, DoneSpace.s12)
        .frame(width: 228)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(DoneColor.bgSunken)
        .overlay(alignment: .trailing) {
            Rectangle().fill(DoneColor.borderSubtle).frame(width: 1)
        }
        .alert(naming?.title ?? "", isPresented: Binding(get: { naming != nil }, set: { if !$0 { naming = nil } })) {
            TextField(naming?.placeholder ?? "Nom", text: $nameDraft)
            Button("Annuler", role: .cancel) { naming = nil }
            Button(naming?.action ?? "OK") { commitNaming() }
        }
        .confirmationDialog(
            "Supprimer le projet « \(deletingProject?.name ?? "") » ?",
            isPresented: Binding(get: { deletingProject != nil }, set: { if !$0 { deletingProject = nil } }),
            presenting: deletingProject
        ) { project in
            Button("Supprimer le projet", role: .destructive) {
                if screen == .list(.project(project.id)) { screen = .list(.inbox) }
                model.deleteProject(project.id)
                deletingProject = nil
            }
        } message: { project in
            let count = model.openCount(in: .project(project.id))
            Text(count == 0 ? "Il ne contient aucune tâche ouverte." : "Ses \(count) tâche\(count > 1 ? "s" : "") passe\(count > 1 ? "nt" : "") dans l'Inbox.")
        }
        .confirmationDialog(
            "Retirer l'étiquette « \(removingTag ?? "") » ?",
            isPresented: Binding(get: { removingTag != nil }, set: { if !$0 { removingTag = nil } }),
            presenting: removingTag
        ) { tag in
            Button("Retirer l'étiquette", role: .destructive) {
                if screen == .list(.tag(tag)) { screen = .list(.inbox) }
                model.removeTag(tag)
                removingTag = nil
            }
        } message: { tag in
            let count = model.openCount(in: .tag(tag))
            Text("Elle disparaît de \(count == 1 ? "sa tâche" : "ses \(count) tâches") ; les tâches restent dans leur projet, ou dans l'Inbox.")
        }
    }

    /// Tâches du plan encore ouvertes.
    private var planCounter: String? {
        let count = model.planIDs.count
        return count > 0 ? "\(count)" : nil
    }

    private func listItem(_ list: TaskList, name: String, symbol: String) -> some View {
        let key = switch list {
        case .inbox: "inbox"
        case .project(let id): "project:" + id
        case .tag(let tag): "tag:" + tag
        }
        let count = model.openCount(in: list)
        return NavItem(
            title: name,
            icon: Image(systemName: symbol),
            counter: count > 0 ? "\(count)" : nil,
            isSelected: screen == .list(list),
            isDropTarget: dropTarget == key
        ) {
            screen = .list(list)
        }
        // Glisser une tâche sur une liste l'y range : projet, étiquette en plus, ou retour à l'Inbox.
        .dropDestination(for: String.self) { ids, _ in
            ids.forEach { model.file($0, into: list) }
            return true
        } isTargeted: { targeted in
            if targeted {
                dropTarget = key
            } else if dropTarget == key {
                dropTarget = nil
            }
        }
    }

    @ViewBuilder
    private func projectMenu(_ project: Project) -> some View {
        Button("Renommer…") {
            nameDraft = project.name
            naming = .rename(project)
        }
        Button("Monter") { model.shiftProject(project.id, by: -1) }
            .disabled(project.id == model.projects.first?.id)
        Button("Descendre") { model.shiftProject(project.id, by: 1) }
            .disabled(project.id == model.projects.last?.id)
        Divider()
        Button("Supprimer le projet…", role: .destructive) { deletingProject = project }
    }

    @ViewBuilder
    private func tagMenu(_ tag: String) -> some View {
        Button("Renommer…") {
            nameDraft = tag
            naming = .renameTag(tag)
        }
        Divider()
        Button("Retirer l'étiquette…", role: .destructive) { removingTag = tag }
    }

    private func commitNaming() {
        switch naming {
        case .new:
            if let project = model.addProject(named: nameDraft) { screen = .list(.project(project.id)) }
        case .rename(let project):
            model.renameProject(project.id, to: nameDraft)
        case .renameTag(let old):
            model.renameTag(old, to: nameDraft)
            // Reste sur la vue de l'étiquette, sous son nouveau nom (ou celui de l'étiquette où elle s'est fondue).
            if screen == .list(.tag(old)) {
                let name = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                if let renamed = model.tags.first(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
                    screen = .list(.tag(renamed))
                }
            }
        case nil:
            break
        }
        naming = nil
    }
}

// MARK: Barre du haut

/// Barre du haut, dans la zone de titre : réunion au centre, nouvelle tâche à droite.
private struct TopBar: View {
    @Environment(AppModel.self) private var model
    @Environment(FocusEngine.self) private var engine
    let screen: RootView.Screen
    let inSession: Bool
    let onCapture: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            HStack(spacing: DoneSpace.s12) {
                // Place des feux de la fenêtre quand la barre latérale est masquée.
                Color.clear.frame(width: 80)
                Spacer(minLength: 0)
                center(now: context.date)
                Spacer(minLength: 0)
                HStack {
                    Button(action: onCapture) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(DoneIconButtonStyle())
                    .help("Nouvelle tâche (⌘N)")
                    .opacity(inSession ? 0 : 1)
                    .allowsHitTesting(!inSession)
                }
                .frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal, DoneSpace.s16)
            .frame(height: 52)
        }
    }

    @ViewBuilder
    private func center(now: Date) -> some View {
        if screen == .focus || screen == .plan {
            let showPill = !inSession || isInterrupted
            if showPill, let pill = MeetingPill.make(meetings: model.meetingsToday, now: now, includeNext: !inSession) {
                MeetingPill(content: pill)
            }
        }
    }

    private var isInterrupted: Bool {
        if case .interrupted = engine.phase { return true }
        return false
    }
}

/// Pastille de réunion : pleine Indigo pendant une réunion, hachurée pour la prochaine.
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
