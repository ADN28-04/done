import AppKit
import SwiftUI

struct RootView: View {
    enum Screen: Hashable {
        case focus, plan, stats, settings
    }

    @Environment(AppModel.self) private var model
    @State private var screen: Screen?

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
        NavigationSplitView {
            List(selection: $screen) {
                NavigationLink(value: Screen.focus) {
                    Label {
                        Text("Focus")
                    } icon: {
                        DoneMark(color: iconColor(.focus), lineWidth: 2.2)
                            .frame(width: 15, height: 15)
                    }
                }
                sidebarLink(.plan, title: "Plan du jour", symbol: "text.alignleft")
                sidebarLink(.stats, title: "Stats", symbol: "chart.bar.fill")
                sidebarLink(.settings, title: "Réglages", symbol: "smallcircle.filled.circle")
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 220)
        } detail: {
            VStack(spacing: 0) {
                if let message = model.errorMessage {
                    ErrorBanner(message: message) { model.errorMessage = nil }
                }
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Theme.background)
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

    private func sidebarLink(_ target: Screen, title: String, symbol: String) -> some View {
        NavigationLink(value: target) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: symbol)
                    .foregroundStyle(iconColor(target))
            }
        }
    }

    private func iconColor(_ target: Screen) -> Color {
        (screen ?? .focus) == target ? Theme.accent : Theme.label2
    }

    @ViewBuilder
    private var detail: some View {
        switch screen ?? .focus {
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
