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

    @State private var newToken = ""

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

            Section("Notifications") {
                Text("Si les fins de session ne s'affichent pas, autorise Done dans Réglages Système › Notifications.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
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
