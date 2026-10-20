import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    @AppStorage(SettingsKey.quickMinutes) private var quickMinutes = Rules().quickMinutes
    @AppStorage(SettingsKey.defaultMinutes) private var defaultMinutes = Rules().defaultMinutes
    @AppStorage(SettingsKey.deepworkMinutes) private var deepworkMinutes = Rules().deepworkMinutes
    @AppStorage(SettingsKey.shortBreakMinutes) private var shortBreakMinutes = Rules().shortBreakMinutes
    @AppStorage(SettingsKey.longBreakMinutes) private var longBreakMinutes = Rules().longBreakMinutes
    @AppStorage(SettingsKey.horizonDays) private var horizonDays = Rules().horizonDays
    @AppStorage(SettingsKey.maxActive) private var maxActive = Rules().maxActive
    @AppStorage(SettingsKey.meetingPrefix) private var meetingPrefix = Rules().meetingPrefix
    @AppStorage(SettingsKey.focusBlockKeywords) private var focusBlockKeywords = Rules().focusBlockKeywords
    @AppStorage(SettingsKey.backlogProjectIDs) private var backlogProjectIDs = Rules().backlogProjectIDs
    @AppStorage(SettingsKey.dndEnabled) private var dndEnabled = Rules().dndEnabled
    @AppStorage(SettingsKey.dndOnShortcut) private var dndOnShortcut = Rules().dndOnShortcut
    @AppStorage(SettingsKey.dndOffShortcut) private var dndOffShortcut = Rules().dndOffShortcut

    @State private var newToken = ""
    @State private var isEditingToken = false
    @State private var dndStatus: DndStatus = .unknown

    private enum DndStatus: Equatable {
        case unknown, checking, ready, problem(String)
    }

    var body: some View {
        Form {
            Section("Todoist") {
                LabeledContent("Connexion") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(model.hasToken ? Theme.accent : Theme.label3)
                            .frame(width: 6, height: 6)
                        Text(model.hasToken ? "Connecté" : "Non connecté")
                    }
                }
                if let last = model.lastRefresh {
                    LabeledContent("Dernière synchro", value: "Aujourd'hui à \(Format.time(last))")
                }
                LabeledContent("Token API") {
                    HStack(spacing: 8) {
                        Button("Changer de token…") { isEditingToken.toggle() }
                            .buttonStyle(PillButtonStyle())
                        Button("Se déconnecter") { model.disconnect() }
                            .buttonStyle(PillButtonStyle())
                    }
                }
                if isEditingToken {
                    HStack {
                        SecureField("Nouveau token API", text: $newToken)
                        Button("Remplacer") {
                            Task {
                                if await model.connect(token: newToken) {
                                    newToken = ""
                                    isEditingToken = false
                                }
                            }
                        }
                        .buttonStyle(PillButtonStyle(kind: .primary))
                        .disabled(newToken.isEmpty)
                    }
                }
            }

            Section("Durées des sessions") {
                minutesStepper("Par défaut", value: $defaultMinutes, range: 10...90, step: 5)
                minutesStepper("Tâches @\(Rules.quickLabel)", value: $quickMinutes, range: 5...60, step: 5)
                minutesStepper("Tâches @\(Rules.deepworkLabel)", value: $deepworkMinutes, range: 15...120, step: 5)
                minutesStepper("Pause", value: $shortBreakMinutes, range: 1...30, step: 1)
                minutesStepper("Pause après une session Deepwork", value: $longBreakMinutes, range: 1...30, step: 1)
            }

            Section {
                Stepper(value: $horizonDays, in: 0...14) {
                    valueRow("Échéance proche", "\(horizonDays) jour\(horizonDays > 1 ? "s" : "")")
                }
                TextField("Préfixe des réunions", text: $meetingPrefix)
                TextField("Mots-clés des blocs de travail", text: $focusBlockKeywords)
            } header: {
                Text("Plan du jour")
            } footer: {
                Text("Une tâche datée avec une heure et qui commence par le préfixe est lue comme une réunion. Si son titre contient un des mots-clés (séparés par des virgules), c'est un bloc de travail : il ne raccourcit pas les sessions.")
            }

            Section {
                Stepper(value: $maxActive, in: 1...10) {
                    valueRow("Cible de chantiers actifs", "\(maxActive)")
                }
                ForEach(model.projects) { project in
                    Toggle(project.name, isOn: binding(for: project.id))
                        .toggleStyle(.checkbox)
                }
            } header: {
                Text("Backlog")
            } footer: {
                Text("Projets suivis dans les stats. Aucun coché : tous les projets.")
            }

            Section {
                Toggle("Activer Ne pas déranger pendant les sessions", isOn: $dndEnabled)
                TextField("Raccourci pour activer", text: $dndOnShortcut)
                TextField("Raccourci pour couper", text: $dndOffShortcut)
                HStack(spacing: 8) {
                    dndStatusLabel
                    Spacer()
                    Button("Ouvrir Raccourcis") { SystemBridge.openShortcutsApp() }
                        .buttonStyle(PillButtonStyle())
                    Button("Vérifier") { Task { await checkShortcuts() } }
                        .buttonStyle(PillButtonStyle())
                    Button("Tester") { Task { await testShortcuts() } }
                        .buttonStyle(PillButtonStyle())
                }
                .disabled(dndStatus == .checking)
            } header: {
                Text("Ne pas déranger")
            } footer: {
                Text("""
                macOS ne laisse pas une app activer ce mode directement. Crée deux raccourcis dans l'app Raccourcis avec l'action « Définir la concentration » (Set Focus) : le premier active « Ne pas déranger » jusqu'à désactivation, le second le désactive. Donne-leur exactement les noms ci-dessus. Done les lance au début et à la fin de chaque session, et coupe le mode quand tu le quittes.
                """)
            }

            Section("Notifications") {
                Text("Si les fins de session ne s'affichent pas, autorise Done dans Réglages Système › Notifications.")
                    .foregroundStyle(Theme.label2)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
    }

    private func minutesStepper(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int) -> some View {
        Stepper(value: value, in: range, step: step) {
            valueRow(title, "\(value.wrappedValue) min")
        }
    }

    private func valueRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(Theme.label)
        }
    }

    @ViewBuilder
    private var dndStatusLabel: some View {
        switch dndStatus {
        case .unknown:
            EmptyView()
        case .checking:
            ProgressView().controlSize(.small)
        case .ready:
            Label("Raccourcis opérationnels", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .problem(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
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

    private func binding(for id: String) -> Binding<Bool> {
        Binding(
            get: { Rules.parseIDs(backlogProjectIDs).contains(id) },
            set: { isOn in
                var ids = Rules.parseIDs(backlogProjectIDs)
                if isOn { ids.insert(id) } else { ids.remove(id) }
                backlogProjectIDs = ids.sorted().joined(separator: ",")
            }
        )
    }
}

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var token = ""
    @State private var isConnecting = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            DoneAppIcon(size: 84)
            Text("Done")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.label)
                .padding(.top, 24)
            Text("Une tâche à la fois, avec un minuteur.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.label2)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 0) {
                Text("Token API Todoist")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.label2)
                SecureField("Colle ton token ici", text: $token)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($fieldFocused)
                    .onSubmit(connect)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(Theme.field, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(fieldBorder, lineWidth: fieldFocused || model.errorMessage != nil ? 3 : 1)
                    )
                    .padding(.top, 6)
                if let message = model.errorMessage {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.redText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                }
                Link(destination: URL(string: "https://app.todoist.com/app/settings/integrations/developer")!) {
                    Text("Ouvrir la page Développeur de Todoist ↗")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.accentText)
                }
                .padding(.top, 8)
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
                .padding(.top, 28)
            }
            .frame(width: 340)
            .padding(.top, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .onAppear { fieldFocused = true }
    }

    private var fieldBorder: Color {
        if model.errorMessage != nil { return Theme.redText.opacity(0.35) }
        return fieldFocused ? Theme.accent.opacity(0.35) : Theme.separator
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
