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
    @AppStorage(SettingsKey.maxActive) private var maxActive = Rules().maxActive
    @AppStorage(SettingsKey.meetingPrefix) private var meetingPrefix = Rules().meetingPrefix
    @AppStorage(SettingsKey.focusBlockKeywords) private var focusBlockKeywords = Rules().focusBlockKeywords
    @AppStorage(SettingsKey.backlogProjectIDs) private var backlogProjectIDs = Rules().backlogProjectIDs
    @AppStorage(SettingsKey.dndEnabled) private var dndEnabled = Rules().dndEnabled
    @AppStorage(SettingsKey.dndOnShortcut) private var dndOnShortcut = Rules().dndOnShortcut
    @AppStorage(SettingsKey.dndOffShortcut) private var dndOffShortcut = Rules().dndOffShortcut
    @AppStorage(SettingsKey.reviewHour) private var reviewHour = Rules().reviewHour
    @AppStorage(SettingsKey.reviewReminder) private var reviewReminder = Rules().reviewReminder
    @AppStorage(SettingsKey.meetingReminder) private var meetingReminder = Rules().meetingReminder
    @AppStorage(SettingsKey.meetingReminderMinutes) private var meetingReminderMinutes = Rules().meetingReminderMinutes
    @AppStorage(SettingsKey.endSound) private var endSound = Rules().endSound
    @AppStorage(SettingsKey.claudeModel) private var claudeModel = Rules().claudeModel.rawValue
    @AppStorage(SettingsKey.claudeContextFolder) private var claudeContextFolder = Rules().claudeContextFolder
    @AppStorage(SettingsKey.claudeMethod) private var claudeMethod = Rules().claudeMethod

    @State private var newToken = ""
    @State private var isEditingToken = false
    @State private var dndStatus: CheckStatus = .unknown
    @State private var notificationStatus: Notifier.Permission?
    @State private var claudeKey = ""
    @State private var claudeKeyStatus: CheckStatus = .unknown
    @State private var contextFileCount: Int?
    @State private var notificationTestError: String?

    /// Résultat d'une vérification : raccourcis « Ne pas déranger » ou clé Claude.
    private enum CheckStatus: Equatable {
        case unknown, checking, ready, problem(String)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Réglages")
                    .font(.display(30, bold: true))
                    .tracking(-0.45)

                SettingsSection("Todoist") {
                    SettingsRow {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(model.hasToken ? Theme.ring : Theme.label3)
                                .frame(width: 8, height: 8)
                            Text(model.hasToken ? "Connecté" : "Non connecté")
                            if let last = model.lastRefresh {
                                Text("· synchro à \(Format.time(last))")
                                    .foregroundStyle(Theme.label2)
                            }
                        }
                    } trailing: {
                        Button("Changer de token…") { isEditingToken.toggle() }
                            .buttonStyle(PillButtonStyle(size: .mini))
                    }
                    if isEditingToken {
                        RowDivider()
                        SettingsRow {
                            SecureField("Nouveau token API", text: $newToken)
                                .textFieldStyle(.plain)
                        } trailing: {
                            HStack(spacing: 6) {
                                Button("Se déconnecter") { model.disconnect() }
                                    .buttonStyle(PillButtonStyle(kind: .plain, size: .mini))
                                Button("Remplacer") {
                                    Task {
                                        if await model.connect(token: newToken) {
                                            newToken = ""
                                            isEditingToken = false
                                        }
                                    }
                                }
                                .buttonStyle(PillButtonStyle(kind: .primary, size: .mini))
                                .disabled(newToken.isEmpty)
                            }
                        }
                    }
                }

                SettingsSection("Rythme") {
                    stepperRow("Session", value: $defaultMinutes, range: 10...90, step: 5, unit: "min")
                    RowDivider()
                    stepperRow("Session @\(Rules.quickLabel)", value: $quickMinutes, range: 5...60, step: 5, unit: "min")
                    RowDivider()
                    stepperRow("Session @\(Rules.deepworkLabel)", value: $deepworkMinutes, range: 15...120, step: 5, unit: "min")
                    RowDivider()
                    stepperRow("Pause", value: $shortBreakMinutes, range: 1...30, step: 1, unit: "min")
                    RowDivider()
                    stepperRow("Pause après Deepwork", value: $longBreakMinutes, range: 1...30, step: 1, unit: "min")
                    RowDivider()
                    stepperRow("Tâches par jour", value: $planSize, range: 1...Rules.maxPlanSize, step: 1, unit: nil)
                }

                SettingsSection("Plan du jour", footer: "Une tâche P1 ou P2 datée dans l'échéance proche devient candidate. Datée plus loin, Done ne la propose pas avant : ni au plan, ni comme prochaine action. Une tâche datée avec une heure et qui commence par le préfixe est une réunion. Si son titre contient un des mots-clés (séparés par des virgules), c'est un bloc de travail : il ne raccourcit pas les sessions.") {
                    stepperRow("Échéance proche", value: $horizonDays, range: 0...14, step: 1, unit: horizonDays > 1 ? "jours" : "jour")
                    RowDivider()
                    textRow("Préfixe des réunions", text: $meetingPrefix)
                    RowDivider()
                    textRow("Blocs de travail", text: $focusBlockKeywords)
                }

                SettingsSection("Backlog") {
                    stepperRow("Chantiers actifs visés", value: $maxActive, range: 1...10, step: 1, unit: nil)
                    RowDivider()
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Projets suivis")
                        FlowLayout(spacing: 8) {
                            ForEach(model.projects) { project in
                                Chip(title: project.name, isOn: scope.contains(project.id)) { toggleProject(project.id) }
                            }
                        }
                        Text("Aucun projet choisi : tous sont suivis.")
                            .font(.text(12))
                            .foregroundStyle(Theme.label2)
                    }
                    .font(.text(14))
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 14)
                }

                SettingsSection("Bilan du soir") {
                    stepperRow("Proposé à partir de", value: $reviewHour, range: 12...22, step: 1, unit: "h")
                    RowDivider()
                    toggleRow("Rappel du lundi au vendredi", isOn: $reviewReminder)
                }
                .onChange(of: reviewHour) { updateReviewReminder() }
                .onChange(of: reviewReminder) { updateReviewReminder() }

                SettingsSection("Claude", footer: "Sur l'écran Focus, « Découper avec Claude… » sous l'action proposée : Claude propose toutes les étapes de la tâche, dans l'ordre, que tu peux modifier avant de les ajouter à Todoist. Done lui envoie la tâche, ta méthode, quelques-unes de tes sous-tâches comme exemples et la liste des fichiers du dossier ; Claude lit ensuite ceux qui l'aident. Tout cela part chez Anthropic. Fichiers lus : Markdown, texte, CSV, JSON, PDF, Word et RTF.") {
                    SettingsRow {
                        Text("Clé API")
                    } trailing: {
                        if model.hasClaudeKey {
                            HStack(spacing: 8) {
                                Text("Enregistrée")
                                    .foregroundStyle(Theme.label2)
                                Button("Supprimer") { model.deleteClaudeKey() }
                                    .buttonStyle(PillButtonStyle(kind: .plain, size: .mini))
                            }
                        } else {
                            HStack(spacing: 6) {
                                SecureField("sk-ant-…", text: $claudeKey)
                                    .textFieldStyle(.plain)
                                    .frame(width: 200)
                                Button("Enregistrer") { Task { await saveClaudeKey() } }
                                    .buttonStyle(PillButtonStyle(kind: .primary, size: .mini))
                                    .disabled(claudeKey.trimmingCharacters(in: .whitespaces).isEmpty || claudeKeyStatus == .checking)
                            }
                        }
                    }
                    if case .problem(let message) = claudeKeyStatus {
                        Text(message)
                            .font(.text(12))
                            .foregroundStyle(Theme.orangeText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 10)
                    }
                    if !model.hasClaudeKey {
                        Link("Créer une clé sur console.anthropic.com", destination: URL(string: "https://console.anthropic.com/settings/keys")!)
                            .font(.text(12))
                            .foregroundStyle(Theme.accentText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 10)
                    }
                    RowDivider()
                    SettingsRow {
                        Text("Modèle")
                    } trailing: {
                        GlassSegmented(
                            selection: Binding(
                                get: { ClaudeModel(rawValue: claudeModel) ?? .opus },
                                set: { claudeModel = $0.rawValue }
                            ),
                            options: ClaudeModel.allCases.map { (value: $0, title: $0.label) }
                        )
                    }
                    RowDivider()
                    SettingsRow {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Dossier de contexte")
                            Text(contextFolderCaption)
                                .font(.text(12))
                                .foregroundStyle(Theme.label2)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    } trailing: {
                        HStack(spacing: 6) {
                            if !claudeContextFolder.isEmpty {
                                Button("Retirer") { claudeContextFolder = "" }
                                    .buttonStyle(PillButtonStyle(kind: .plain, size: .mini))
                            }
                            Button("Choisir…") {
                                if let url = SystemBridge.chooseFolder(prompt: "Utiliser ce dossier") {
                                    claudeContextFolder = url.path
                                }
                            }
                            .buttonStyle(PillButtonStyle(size: .mini))
                        }
                    }
                    .padding(.vertical, 4)
                    RowDivider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ta méthode pour découper")
                        TextEditor(text: $claudeMethod)
                            .font(.text(13))
                            .scrollContentBackground(.hidden)
                            .frame(height: 84)
                            .padding(8)
                            .background(Theme.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .font(.text(14))
                    .padding(16)
                }
                .task(id: claudeContextFolder) { await countContextFiles() }

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

    private var contextFolderCaption: String {
        guard !claudeContextFolder.isEmpty else { return "Aucun : Claude ne voit que la tâche et ta méthode" }
        let path = (claudeContextFolder as NSString).abbreviatingWithTildeInPath
        guard let contextFileCount else { return path }
        return "\(path) · \(contextFileCount) fichier\(contextFileCount > 1 ? "s" : "") lisible\(contextFileCount > 1 ? "s" : "")"
    }

    private func countContextFiles() async {
        contextFileCount = nil
        guard !claudeContextFolder.isEmpty else { return }
        let folder = ContextFolder(root: URL(fileURLWithPath: claudeContextFolder))
        contextFileCount = await Task.detached { folder.files().count }.value
    }

    private func saveClaudeKey() async {
        claudeKeyStatus = .checking
        do {
            try await model.saveClaudeKey(claudeKey)
            claudeKey = ""
            claudeKeyStatus = .unknown
        } catch {
            claudeKeyStatus = (error as? ClaudeError) == .unauthorized
                ? .problem("Claude refuse cette clé. Copie-la à nouveau depuis console.anthropic.com.")
                : .problem("Clé non enregistrée : \(error.localizedDescription)")
        }
    }

    private func testNotification() async {
        notificationTestError = await Notifier.shared.sendTest()
        notificationStatus = await Notifier.shared.permission()
    }

    private var scope: Set<String> { Rules.parseIDs(backlogProjectIDs) }

    private func toggleProject(_ id: String) {
        var ids = scope
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
        backlogProjectIDs = ids.sorted().joined(separator: ",")
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

/// Disposition en lignes qui passent à la ligne, pour les pastilles de projets.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let extra = rows[rows.count - 1].indices.isEmpty ? size.width : size.width + spacing
            if rows[rows.count - 1].width + extra > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            let isFirst = rows[rows.count - 1].indices.isEmpty
            rows[rows.count - 1].indices.append(index)
            rows[rows.count - 1].width += isFirst ? size.width : size.width + spacing
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
        }
        return rows.filter { !$0.indices.isEmpty }
    }
}

// MARK: Connexion

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var token = ""
    @State private var isConnecting = false
    @FocusState private var fieldFocused: Bool

    private static let developerPage = URL(string: "https://app.todoist.com/app/settings/integrations/developer")!

    var body: some View {
        ZStack {
            Backdrop(style: .wash)
            VStack(spacing: 0) {
                DoneAppIcon(size: 72)
                Text("Done")
                    .font(.display(36, bold: true))
                    .tracking(-0.54)
                    .padding(.top, 18)
                Text("Une tâche à la fois, avec un minuteur.")
                    .font(.text(15))
                    .foregroundStyle(Theme.label2)
                    .padding(.top, 6)
                SecureField("Token API Todoist", text: $token)
                    .textFieldStyle(.plain)
                    .font(.text(14))
                    .focused($fieldFocused)
                    .onSubmit(connect)
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .surface(radius: 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(model.errorMessage != nil ? Theme.redText.opacity(0.5) : Theme.ring.opacity(fieldFocused ? 0.45 : 0), lineWidth: 2)
                    )
                    .padding(.top, 36)
                if let message = model.errorMessage {
                    Text(message)
                        .font(.text(12))
                        .foregroundStyle(Theme.redText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                }
                Button(action: connect) {
                    if isConnecting {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Connexion…")
                        }
                    } else {
                        Text("Se connecter")
                    }
                }
                .buttonStyle(PillButtonStyle(kind: .primary, fullWidth: true))
                .keyboardShortcut(.defaultAction)
                .disabled(token.isEmpty || isConnecting)
                .padding(.top, 12)
                Link(destination: Self.developerPage) {
                    Text("Où trouver mon token ?")
                        .font(.text(13))
                        .foregroundStyle(Theme.accentText)
                }
                .help("Todoist › Réglages › Intégrations › Développeur. Le token reste dans le trousseau de ton Mac.")
                .padding(.top, 16)
            }
            .frame(width: 340)
        }
        .onAppear { fieldFocused = true }
    }

    private func connect() {
        guard !token.isEmpty, !isConnecting else { return }
        Task {
            isConnecting = true
            _ = await model.connect(token: token)
            isConnecting = false
        }
    }
}
