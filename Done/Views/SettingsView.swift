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
    @State private var dndStatus: DndStatus = .unknown

    private enum DndStatus: Equatable {
        case unknown, checking, ready, problem(String)
    }

    var body: some View {
        Form {
            Section("Todoist") {
                LabeledContent("Connexion", value: model.hasToken ? "Connecté" : "Non connecté")
                if let last = model.lastRefresh {
                    LabeledContent("Dernière synchro", value: Format.time(last))
                }
                HStack {
                    SecureField("Nouveau token API", text: $newToken)
                    Button("Remplacer") {
                        Task {
                            if await model.connect(token: newToken) { newToken = "" }
                        }
                    }
                    .disabled(newToken.isEmpty)
                }
                Button("Se déconnecter", role: .destructive) { model.disconnect() }
            }

            Section("Durées des sessions") {
                Stepper("@\(Rules.quickLabel) : \(quickMinutes) min", value: $quickMinutes, in: 5...60, step: 5)
                Stepper("Par défaut : \(defaultMinutes) min", value: $defaultMinutes, in: 10...90, step: 5)
                Stepper("@\(Rules.deepworkLabel) : \(deepworkMinutes) min", value: $deepworkMinutes, in: 15...120, step: 5)
                Stepper("Pause courte : \(shortBreakMinutes) min", value: $shortBreakMinutes, in: 1...30)
                Stepper("Pause longue, après une session Deepwork : \(longBreakMinutes) min", value: $longBreakMinutes, in: 1...30)
            }

            Section {
                Stepper("Échéance proche : \(horizonDays) jour\(horizonDays > 1 ? "s" : "")", value: $horizonDays, in: 0...14)
                TextField("Préfixe des réunions", text: $meetingPrefix)
                TextField("Mots-clés des blocs de travail", text: $focusBlockKeywords)
            } header: {
                Text("Plan du jour")
            } footer: {
                Text("Une tâche datée avec une heure et qui commence par le préfixe est lue comme une réunion. Si son titre contient un des mots-clés (séparés par des virgules), c'est un bloc de travail : il ne raccourcit pas les sessions.")
            }

            Section {
                Stepper("Chantiers actifs visés : \(maxActive)", value: $maxActive, in: 1...10)
                ForEach(model.projects) { project in
                    Toggle(project.name, isOn: binding(for: project.id))
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
                HStack {
                    dndStatusLabel
                    Spacer()
                    Button("Ouvrir Raccourcis") { SystemBridge.openShortcutsApp() }
                    Button("Vérifier") { Task { await checkShortcuts() } }
                    Button("Tester") { Task { await testShortcuts() } }
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
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
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

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "scope")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
            Text("Done").font(.largeTitle.bold())
            Text("Une tâche à la fois, avec un minuteur.")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                Text("Colle ton token API Todoist").font(.headline)
                Text("Dans Todoist : Réglages › Intégrations › Développeur. Le token reste dans le trousseau de ton Mac.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Link("Ouvrir la page Développeur de Todoist", destination: URL(string: "https://app.todoist.com/app/settings/integrations/developer")!)
                SecureField("Token API", text: $token)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(connect)
                if let message = model.errorMessage {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
                HStack {
                    Spacer()
                    if isConnecting {
                        ProgressView().controlSize(.small)
                    }
                    Button("Se connecter", action: connect)
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        .disabled(token.isEmpty || isConnecting)
                }
            }
            .frame(width: 440)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
