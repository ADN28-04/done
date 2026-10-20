import SwiftUI

/// Rituel du matin : choisir et ordonner les tâches du jour.
struct PlanView: View {
    @Environment(AppModel.self) private var model
    var onValidate: () -> Void

    @State private var draft: [String] = []
    @State private var loaded = false
    @State private var showPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Plan du jour").font(.largeTitle.bold())
                Text("Choisis tes \(Rules.recommendedPlanSize) tâches les plus importantes, dans l'ordre. Le reste attendra.")
                    .foregroundStyle(.secondary)
            }
            AgendaStrip(meetings: model.meetingsToday)
            HStack(alignment: .top, spacing: 16) {
                candidateColumn
                planColumn
            }
        }
        .padding(24)
        .onAppear {
            // Reprend le plan déjà validé aujourd'hui.
            if !loaded {
                draft = model.planIDs
                loaded = true
            }
        }
        .onChange(of: model.lastRefresh) {
            // Retire les tâches fermées entre-temps dans Todoist.
            draft.removeAll { model.index[$0] == nil }
        }
        .sheet(isPresented: $showPicker) {
            TaskPickerView(title: "Ajouter une tâche au plan") { add($0.id) }
                .environment(model)
        }
    }

    private var candidateColumn: some View {
        let candidates = model.candidates.filter { !draft.contains($0.id) }
        return VStack(alignment: .leading, spacing: 8) {
            Text("Candidates").font(.headline)
            Text("P1/P2, hors @\(Rules.waitingLabel), avec @\(Rules.activeLabel) ou une échéance sous \(model.rules.horizonDays) jours.")
                .font(.caption)
                .foregroundStyle(.secondary)
            List(candidates) { task in
                HStack {
                    TaskRow(task: task)
                    Spacer()
                    Button {
                        add(task.id)
                    } label: {
                        Image(systemName: "plus.circle.fill").font(.title3)
                    }
                    .buttonStyle(.borderless)
                    .disabled(draft.count >= Rules.maxPlanSize)
                    .help("Ajouter au plan")
                }
            }
            .listStyle(.inset)
            .overlay {
                if candidates.isEmpty {
                    ContentUnavailableView(
                        model.isLoading ? "Chargement…" : "Aucune candidate",
                        systemImage: "tray",
                        description: Text("Cherche une tâche à la main avec le bouton ci-dessous.")
                    )
                }
            }
            Button("Chercher une autre tâche…") { showPicker = true }
                .disabled(draft.count >= Rules.maxPlanSize)
        }
        .frame(minWidth: 340, maxWidth: .infinity)
    }

    private var planColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aujourd'hui").font(.headline)
            Text("Glisse pour réordonner. La première est celle que tu attaques en premier.")
                .font(.caption)
                .foregroundStyle(.secondary)
            List {
                ForEach(Array(draft.enumerated()), id: \.element) { position, id in
                    HStack {
                        Text("\(position + 1)")
                            .font(.title3.weight(.semibold).monospacedDigit())
                            .foregroundStyle(position < Rules.recommendedPlanSize ? Color.accentColor : Color.secondary)
                            .frame(width: 24)
                        if let task = model.index[id] {
                            TaskRow(task: task)
                        } else {
                            Text("Tâche terminée ou introuvable").foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            draft.removeAll { $0 == id }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Retirer du plan")
                    }
                }
                .onMove { draft.move(fromOffsets: $0, toOffset: $1) }
            }
            .listStyle(.inset)
            .overlay {
                if draft.isEmpty {
                    ContentUnavailableView(
                        "Plan vide",
                        systemImage: "list.number",
                        description: Text("Ajoute tes tâches depuis la liste de gauche.")
                    )
                }
            }
            HStack {
                if let done = model.todayPlan?.doneIDs.count, done > 0 {
                    Label("\(done) terminée\(done > 1 ? "s" : "") aujourd'hui", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                if draft.count > Rules.recommendedPlanSize {
                    Text("\(draft.count) tâches, c'est plus que les \(Rules.recommendedPlanSize) recommandées.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Spacer()
                Button("Valider le plan") {
                    model.savePlan(draft)
                    onValidate()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(draft.isEmpty)
            }
        }
        .frame(minWidth: 340, maxWidth: .infinity)
    }

    private func add(_ id: String) {
        guard !draft.contains(id), draft.count < Rules.maxPlanSize else { return }
        draft.append(id)
    }
}
