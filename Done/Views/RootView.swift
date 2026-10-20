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
    @State private var choseInitialScreen = false
    @State private var revealTabBar = false

    /// Pendant une session, la barre s'efface : il ne reste que la tâche et le minuteur.
    private var showTabBar: Bool {
        let sessionRunning = engine.phase == .focusing || engine.phase == .paused
        return !sessionRunning || revealTabBar
    }

    var body: some View {
        Group {
            if model.hasToken {
                main
            } else {
                OnboardingView()
            }
        }
        .background(Theme.background)
    }

    private var main: some View {
        VStack(spacing: 0) {
            if let message = model.errorMessage {
                ErrorBanner(message: message) { model.errorMessage = nil }
            }
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.background)
        // La barre flotte au-dessus du contenu, qui garde de la place pour elle.
        // Masquée pendant une session, elle revient quand la souris approche du bas.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FloatingTabBar(selection: $screen)
                .opacity(showTabBar ? 1 : 0)
                .offset(y: showTabBar ? 0 : 24)
                .allowsHitTesting(showTabBar)
                .animation(.easeInOut(duration: 0.3), value: showTabBar)
                .padding(.bottom, 20)
                .padding(.top, 8)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onHover { inside in revealTabBar = inside }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await model.refresh() }
                } label: {
                    Label("Rafraîchir", systemImage: "arrow.clockwise")
                }
                .help("Recharger les tâches Todoist (⌘R)")
                .keyboardShortcut("r")
                .disabled(model.isLoading)
            }
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
                .navigationTitle("Focus")
        case .plan:
            PlanView(onValidate: { screen = .focus })
                .navigationTitle("")
        case .stats:
            StatsView()
                .navigationTitle("Stats")
        case .settings:
            SettingsView()
                .navigationTitle("Réglages")
        }
    }
}

/// Barre d'onglets flottante, centrée en bas, façon iOS : une pilule en Liquid Glass.
struct FloatingTabBar: View {
    @Binding var selection: RootView.Screen
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(RootView.Screen.allCases) { screen in
                TabBarItem(screen: screen, isSelected: selection == screen, namespace: namespace) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        selection = screen
                    }
                }
                .keyboardShortcut(screen.shortcut, modifiers: .command)
            }
        }
        .padding(6)
        .liquidGlassCapsule()
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
            VStack(spacing: 4) {
                icon
                    .frame(width: 24, height: 22)
                Text(screen.title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Theme.accent : (hovered ? Theme.label : Theme.label2))
            .frame(width: 96, height: 60)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Theme.accent.opacity(0.14))
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
                .frame(width: 21, height: 21)
        case .plan:
            Image(systemName: "text.alignleft")
                .font(.system(size: 19, weight: .medium))
        case .stats:
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 19, weight: .medium))
        case .settings:
            Image(systemName: "smallcircle.filled.circle")
                .font(.system(size: 20, weight: .medium))
        }
    }
}

extension View {
    #if compiler(>=6.2)
    /// Liquid Glass sur macOS 26, verre dépoli avant.
    @ViewBuilder
    func liquidGlassCapsule() -> some View {
        if #available(macOS 26.0, *) {
            glassEffect(.regular, in: Capsule())
                .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
        } else {
            frostedCapsule()
        }
    }
    #else
    /// Xcode antérieur à la version 26 : verre dépoli uniquement.
    func liquidGlassCapsule() -> some View {
        frostedCapsule()
    }
    #endif

    fileprivate func frostedCapsule() -> some View {
        background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.15), radius: 18, y: 8)
    }
}

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .help("Masquer")
        }
        .font(.system(size: 13))
        .foregroundStyle(Theme.redText)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Theme.redTint)
    }
}
