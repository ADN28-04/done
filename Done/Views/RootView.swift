import AppKit
import SwiftUI

struct RootView: View {
    enum Screen: CaseIterable, Identifiable, Hashable {
        case focus, plan, stats, settings

        var id: Self { self }

        var title: String {
            switch self {
            case .focus: "Focus"
            case .plan: "Plan du jour"
            case .stats: "Stats"
            case .settings: "Réglages"
            }
        }

        var shortcut: KeyEquivalent {
            switch self {
            case .focus: "1"
            case .plan: "2"
            case .stats: "3"
            case .settings: "4"
            }
        }
    }

    @Environment(AppModel.self) private var model
    @Environment(FocusEngine.self) private var engine
    @State private var screen: Screen = .focus
    @State private var statsTab: StatsView.Tab = .focus
    @State private var choseInitialScreen = false
    @State private var revealTabBar = false

    var body: some View {
        Group {
            if model.hasToken {
                main
            } else {
                OnboardingView()
            }
        }
    }

    /// Sur l'écran Focus, toute phase autre que le repos est une session :
    /// la navigation s'efface, il ne reste que la tâche et le minuteur.
    private var inSession: Bool {
        screen == .focus && engine.phase != .idle
    }

    private var showTabBar: Bool { !inSession || revealTabBar }

    private var backdropStyle: BackdropStyle {
        guard screen == .focus else { return .wash }
        switch engine.phase {
        case .idle: return .wash
        case .focusing, .paused: return .session
        case .interrupted: return .interruption
        case .awaitingOutcome: return .finished
        case .onBreak: return .rest
        }
    }

    private var main: some View {
        ZStack {
            Backdrop(style: backdropStyle)
                .animation(.easeInOut(duration: 0.6), value: backdropStyle)
            VStack(spacing: 0) {
                TopBar(screen: screen, inSession: inSession, statsTab: $statsTab)
                if let message = model.errorMessage {
                    ErrorBanner(message: message) { model.errorMessage = nil }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 8)
                }
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .ignoresSafeArea(.container, edges: .top)
        }
        // La barre flotte au-dessus du contenu, qui garde de la place pour elle.
        // Masquée pendant une session, elle revient quand la souris approche du bas.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FloatingTabBar(selection: $screen)
                .opacity(showTabBar ? 1 : 0)
                .offset(y: showTabBar ? 0 : 20)
                .allowsHitTesting(showTabBar)
                .animation(.easeInOut(duration: 0.3), value: showTabBar)
                .padding(.bottom, 16)
                .padding(.top, 8)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onHover { inside in revealTabBar = inside }
        }
        .onAppear {
            if !choseInitialScreen {
                screen = model.todayPlan == nil ? .plan : .focus
                choseInitialScreen = true
            }
        }
        .task { await model.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await model.refreshIfStale() }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch screen {
        case .focus:
            FocusView(openPlan: { screen = .plan })
        case .plan:
            PlanView(onValidate: { screen = .focus })
        case .stats:
            StatsView(tab: statsTab)
        case .settings:
            SettingsView()
        }
    }
}

/// Barre du haut, dans la zone de titre : pastille centrale (réunion, ou choix Focus/Backlog
/// dans les stats) et bouton rafraîchir. Les feux de la fenêtre restent à gauche.
private struct TopBar: View {
    @Environment(AppModel.self) private var model
    @Environment(FocusEngine.self) private var engine
    let screen: RootView.Screen
    let inSession: Bool
    @Binding var statsTab: StatsView.Tab

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            HStack(spacing: 12) {
                Color.clear.frame(width: 80)
                Spacer(minLength: 0)
                center(now: context.date)
                Spacer(minLength: 0)
                HStack {
                    if !inSession && screen != .settings {
                        Button {
                            Task { await model.refresh() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(RoundGlassButtonStyle())
                        .help("Recharger les tâches Todoist (⌘R)")
                        .keyboardShortcut("r")
                        .disabled(model.isLoading)
                    }
                }
                .frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .frame(height: 60)
        }
    }

    @ViewBuilder
    private func center(now: Date) -> some View {
        if screen == .stats {
            StatsTabPicker(selection: $statsTab)
        } else if screen == .focus || screen == .plan {
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

/// Pastille en verre : réunion en cours, bloc de travail ou prochaine réunion.
struct MeetingPill: View {
    struct Content {
        enum Dot { case filled, accent, hollow }
        let text: String
        let dot: Dot
        let help: String
    }

    let content: Content

    var body: some View {
        HStack(spacing: 8) {
            dot
            Text(content.text)
                .font(.text(13))
                .foregroundStyle(Theme.label)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .frame(height: 32)
        .glassBackground(Capsule())
        .help(content.help)
    }

    @ViewBuilder
    private var dot: some View {
        switch content.dot {
        case .filled:
            Circle().fill(Theme.label2).frame(width: 7, height: 7)
        case .accent:
            Circle().fill(Theme.ring).frame(width: 7, height: 7)
        case .hollow:
            Circle().strokeBorder(Theme.label2, lineWidth: 1.5).frame(width: 7, height: 7)
        }
    }

    static func make(meetings: [Meeting], now: Date, includeNext: Bool) -> Content? {
        if let ongoing = meetings.first(where: { $0.contains(now) }) {
            if ongoing.isFocusBlock {
                return Content(text: "Bloc \(ongoing.title) jusqu'à \(Format.time(ongoing.end))", dot: .accent, help: ongoing.title)
            }
            return Content(text: "Réunion en cours jusqu'à \(Format.time(ongoing.end))", dot: .filled, help: ongoing.title)
        }
        guard includeNext, let next = meetings.first(where: { !$0.isFocusBlock && $0.start > now }) else { return nil }
        let minutes = Format.minutes(next.start.timeIntervalSince(now) / 60)
        return Content(text: "Prochaine réunion à \(Format.time(next.start)) · dans \(minutes)", dot: .hollow, help: next.title)
    }
}

/// Barre d'onglets flottante, centrée en bas : une pilule en verre.
struct FloatingTabBar: View {
    @Binding var selection: RootView.Screen
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(RootView.Screen.allCases) { screen in
                TabBarItem(screen: screen, isSelected: selection == screen, namespace: namespace) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        selection = screen
                    }
                }
                .keyboardShortcut(screen.shortcut, modifiers: .command)
            }
        }
        .padding(5)
        .liquidGlass(Capsule())
    }
}

private struct TabBarItem: View {
    let screen: RootView.Screen
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                icon
                    .frame(width: 16, height: 16)
                Text(screen.title)
                    .font(.text(13, isSelected ? .semibold : .regular))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Theme.accentText : (hovered ? Theme.label : Theme.label2))
            .padding(.horizontal, 18)
            .frame(height: 40)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Theme.selection)
                        .matchedGeometryEffect(id: "selection", in: namespace)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help("\(screen.title) (⌘\(String(screen.shortcut.character)))")
    }

    @ViewBuilder
    private var icon: some View {
        switch screen {
        case .focus:
            Image("DoneGlyph")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
        case .plan:
            Image(systemName: "text.alignleft")
                .font(.system(size: 13, weight: .medium))
        case .stats:
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 13, weight: .medium))
        case .settings:
            Image(systemName: "smallcircle.filled.circle")
                .font(.system(size: 14, weight: .medium))
        }
    }
}

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            NoticeBox(text: message, tone: .error)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.label2)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Masquer")
        }
        .frame(maxWidth: 640)
    }
}
