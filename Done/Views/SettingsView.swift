import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    @AppStorage(SettingsKey.quickMinutes) private var quickMinutes = Rules().quickMinutes
    @AppStorage(SettingsKey.defaultMinutes) private var defaultMinutes = Rules().defaultMinutes
    @AppStorage(SettingsKey.deepworkMinutes) private var deepworkMinutes = Rules().deepworkMinutes
    @AppStorage(SettingsKey.shortBreakMinutes) private var shortBreakMinutes = Rules().shortBreakMinutes
    @AppStorage(SettingsKey.longBreakMinutes) private var longBreakMinutes = Rules().longBreakMinutes
    @AppStorage(SettingsKey.planSize) private var planSize = Rules().planSize
    @AppStorage(SettingsKey.horizonDays) private var horizonDays = Rules().horizonDays
    @AppStorage(SettingsKey.dndEnabled) private var dndEnabled = Rules().dndEnabled
    @AppStorage(SettingsKey.dndOnShortcut) private var dndOnShortcut = Rules().dndOnShortcut
    @AppStorage(SettingsKey.dndOffShortcut) private var dndOffShortcut = Rules().dndOffShortcut
    @AppStorage(SettingsKey.reviewHour) private var reviewHour = Rules().reviewHour
    @AppStorage(SettingsKey.reviewReminder) private var reviewReminder = Rules().reviewReminder
    @AppStorage(SettingsKey.meetingReminder) private var meetingReminder = Rules().meetingReminder
    @AppStorage(SettingsKey.meetingReminderMinutes) private var meetingReminderMinutes = Rules().meetingReminderMinutes
    @AppStorage(SettingsKey.endSound) private var endSound = Rules().endSound

    @State private var dndStatus: CheckStatus = .unknown
    @State private var notificationStatus: Notifier.Permission?
    @State private var notificationTestError: String?

    /// Résultat de la vérification des raccourcis « Ne pas déranger ».
    private enum CheckStatus: Equatable {
        case unknown, checking, ready, problem(String)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Réglages")
                    .font(.display(30, bold: true))
                    .tracking(-0.45)

                SettingsSection("Rythme") {
                    stepperRow("Session", value: $defaultMinutes, range: 10...90, step: 5, unit: "min")
                    RowDivider()
                    stepperRow("Session rapide", value: $quickMinutes, range: 5...60, step: 5, unit: "min")
                    RowDivider()
                    stepperRow("Session Deepwork", value: $deepworkMinutes, range: 15...120, step: 5, unit: "min")
                    RowDivider()
                    stepperRow("Pause", value: $shortBreakMinutes, range: 1...30, step: 1, unit: "min")
                    RowDivider()
                    stepperRow("Pause après Deepwork", value: $longBreakMinutes, range: 1...30, step: 1, unit: "min")
                    RowDivider()
                    stepperRow("Tâches par jour", value: $planSize, range: 1...Rules.maxPlanSize, step: 1, unit: nil)
                }

                SettingsSection("Plan du jour", footer: "Les tâches P1 et P2 sont candidates, comme toutes celles dont l'échéance tombe dans ce délai ou est dépassée. Une tâche datée plus loin n'est pas proposée avant : ni au plan, ni comme prochaine action.") {
                    stepperRow("Échéance proche", value: $horizonDays, range: 0...14, step: 1, unit: horizonDays > 1 ? "jours" : "jour")
                }

                SettingsSection("Bilan du soir") {
                    stepperRow("Proposé à partir de", value: $reviewHour, range: 12...22, step: 1, unit: "h")
                    RowDivider()
                    toggleRow("Rappel du lundi au vendredi", isOn: $reviewReminder)
                }
                .onChange(of: reviewHour) { updateReviewReminder() }
                .onChange(of: reviewReminder) { updateReviewReminder() }

                SettingsSection("Ne pas déranger", footer: "macOS ne laisse pas une app activer ce mode directement. Crée deux raccourcis dans l'app Raccourcis avec l'action « Définir la concentration » (Set Focus) : le premier active « Ne pas déranger » jusqu'à désactivation, le second le désactive. Donne-leur exactement les noms ci-dessus.") {
                    toggleRow("Pendant les sessions", isOn: $dndEnabled)
                    RowDivider()
                    textRow("Raccourci pour activer", text: $dndOnShortcut)
                    RowDivider()
                    textRow("Raccourci pour couper", text: $dndOffShortcut)
                    RowDivider()
                    SettingsRow {
                        dndStatusLabel
                    } trailing: {
                        HStack(spacing: 6) {
                            Button("Raccourcis") { SystemBridge.openShortcutsApp() }
                                .buttonStyle(PillButtonStyle(size: .mini))
                            Button("Vérifier") { Task { await checkShortcuts() } }
                                .buttonStyle(PillButtonStyle(size: .mini))
                            Button("Tester") { Task { await testShortcuts() } }
                                .buttonStyle(PillButtonStyle(size: .mini))
                        }
                        .disabled(dndStatus == .checking)
                    }
                }

                SettingsSection("Notifications", footer: "Pendant « Ne pas déranger », macOS masque les notifications : pour les garder, ajoute Done aux apps autorisées dans Réglages Système › Concentration › Ne pas déranger. Le son de fin, lui, passe toujours.") {
                    SettingsRow {
                        notificationStatusLabel
                    } trailing: {
                        HStack(spacing: 6) {
                            if notificationStatus == .notDetermined {
                                Button("Autoriser") {
                                    Task { notificationStatus = await Notifier.shared.requestPermission() }
                                }
                                .buttonStyle(PillButtonStyle(kind: .primary, size: .mini))
                            }
                            Button("Réglages") { SystemBridge.openNotificationSettings() }
                                .buttonStyle(PillButtonStyle(size: .mini))
                            Button("Tester") { Task { await testNotification() } }
                                .buttonStyle(PillButtonStyle(size: .mini))
                        }
                    }
                    RowDivider()
                    toggleRow("Son à la fin des sessions et des pauses", isOn: $endSound)
                    RowDivider()
                    toggleRow("Réunion proche", isOn: $meetingReminder)
                    RowDivider()
                    stepperRow("Prévenir avant la réunion", value: $meetingReminderMinutes, range: 1...30, step: 1, unit: "min")
                        .disabled(!meetingReminder)
                }
                .task { notificationStatus = await Notifier.shared.permission() }
                .onChange(of: meetingReminder) { model.updateMeetingReminders() }
                .onChange(of: meetingReminderMinutes) { model.updateMeetingReminders() }

                SettingsSection("Données", footer: "Tes tâches, projets et réunions restent sur ce Mac, dans un seul fichier. Done en garde une copie par jour, sur 30 jours, dans le dossier Sauvegardes à côté.") {
                    SettingsRow {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fichier des tâches")
                            Text((model.storage.fileURL.path as NSString).abbreviatingWithTildeInPath)
                                .font(.text(12))
                                .foregroundStyle(Theme.label2)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    } trailing: {
                        Button("Afficher dans le Finder") { SystemBridge.revealInFinder(model.storage.fileURL) }
                            .buttonStyle(PillButtonStyle(size: .mini))
                    }
                    .padding(.vertical, 4)
                }
            }
            .frame(width: 600)
            .padding(.top, 4)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.never)
    }

    // MARK: Lignes

    private func stepperRow(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, unit: String?) -> some View {
        SettingsRow {
            Text(title)
        } trailing: {
            HStack(spacing: 12) {
                Text(unit.map { "\(value.wrappedValue) \($0)" } ?? "\(value.wrappedValue)")
                    .monospacedDigit()
                GlassStepper(value: value, range: range, step: step)
            }
        }
    }

    private func textRow(_ title: String, text: Binding<String>) -> some View {
        SettingsRow {
            Text(title)
        } trailing: {
            TextField(title, text: text)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(Theme.label2)
                .frame(maxWidth: 260)
        }
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        SettingsRow {
            Text(title)
        } trailing: {
            Toggle(title, isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(Theme.accent)
        }
    }

    @ViewBuilder
    private var dndStatusLabel: some View {
        switch dndStatus {
        case .unknown:
            Text("État des raccourcis")
                .foregroundStyle(Theme.label2)
        case .checking:
            ProgressView().controlSize(.small)
        case .ready:
            Label("Raccourcis opérationnels", systemImage: "checkmark.circle.fill")
                .foregroundStyle(Theme.accentText)
        case .problem(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.orangeText)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private var notificationStatusLabel: some View {
        if let notificationTestError {
            Label("macOS a refusé la notification : \(notificationTestError)", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.orangeText)
                .lineLimit(2)
        } else {
            switch notificationStatus {
            case nil:
                ProgressView().controlSize(.small)
            case .allowed:
                Label("Notifications autorisées", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.accentText)
            case .notDetermined:
                Text("Autorisation pas encore donnée")
                    .foregroundStyle(Theme.label2)
            case .denied:
                Label("Refusées dans Réglages Système", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.orangeText)
            case .silent:
                Label("Autorisées, mais sans bannière", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.orangeText)
            case .failed(let message):
                Label("macOS bloque les notifications de Done : \(message)", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.orangeText)
                    .lineLimit(2)
            }
        }
    }

    // MARK: Actions

    private func testNotification() async {
        notificationTestError = await Notifier.shared.sendTest()
        notificationStatus = await Notifier.shared.permission()
    }

    private func updateReviewReminder() {
        Notifier.shared.updateReviewReminder(enabled: reviewReminder, hour: reviewHour)
    }

    private func checkShortcuts() async {
        dndStatus = .checking
        switch await DoNotDisturb.shared.missingShortcuts() {
        case .success(let missing) where missing.isEmpty:
            dndStatus = .ready
        case .success(let missing):
            dndStatus = .problem("Introuvable : \(missing.joined(separator: ", "))")
        case .failure(let error):
            dndStatus = .problem(error.message)
        }
    }

    private func testShortcuts() async {
        dndStatus = .checking
        if let message = await DoNotDisturb.shared.test() {
            dndStatus = .problem(message)
        } else {
            dndStatus = .ready
        }
    }
}

// MARK: Composants des réglages

/// Section : étiquette en DM Mono, carte, note facultative.
private struct SettingsSection<Content: View>: View {
    let title: String
    let footer: String?
    let content: Content

    init(_ title: String, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: title)
                .padding(.horizontal, 6)
            if Content.self != EmptyView.self {
                VStack(spacing: 0) {
                    content
                }
                .surface(radius: 16)
            }
            if let footer {
                Text(footer)
                    .font(.text(12))
                    .foregroundStyle(Theme.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 6)
            }
        }
    }
}

/// Ligne de réglage : libellé à gauche, contrôle à droite.
private struct SettingsRow<Leading: View, Trailing: View>: View {
    let leading: Leading
    let trailing: Trailing

    init(@ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            leading
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .font(.text(14))
        .padding(.horizontal, 16)
        .frame(minHeight: 42)
    }
}

private struct RowDivider: View {
    var body: some View {
        Hairline().padding(.horizontal, 16)
    }
}
