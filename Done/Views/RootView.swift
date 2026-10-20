import AppKit
import SwiftUI

struct RootView: View {
    enum Screen: Hashable {
        case focus, plan, stats, settings
    }

    @Environment(AppModel.self) private var model
    @State private var screen: Screen?

    var body: some View {
        if model.hasToken {
            main
        } else {
            OnboardingView()
        }
    }

    private var main: some View {
        NavigationSplitView {
            List(selection: $screen) {
                NavigationLink(value: Screen.focus) { Label("Focus", systemImage: "scope") }
                NavigationLink(value: Screen.plan) { Label("Plan du jour", systemImage: "list.number") }
                NavigationLink(value: Screen.stats) { Label("Stats", systemImage: "chart.bar.xaxis") }
                NavigationLink(value: Screen.settings) { Label("Réglages", systemImage: "gearshape") }
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190)
        } detail: {
            VStack(spacing: 0) {
                if let message = model.errorMessage {
                    ErrorBanner(message: message) { model.errorMessage = nil }
                }
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .toolbar {
                ToolbarItem {
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
        }
        .onAppear {
            if screen == nil {
                screen = model.todayPlan == nil ? .plan : .focus
            }
        }
        .task { await model.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await model.refreshIfStale() }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch screen ?? .focus {
        case .focus:
            FocusView(openPlan: { screen = .plan })
        case .plan:
            PlanView(onValidate: { screen = .focus })
        case .stats:
            StatsView()
        case .settings:
            SettingsView()
        }
    }
}

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.85))
    }
}
