import SwiftUI

/// Rituel du matin : choisir et ordonner les tâches du jour.
struct PlanView: View {
    @Environment(AppModel.self) private var model
    var onValidate: () -> Void

    @State private var draft: [String] = []
    @State private var loaded = false
    @State private var showPicker = false
    @State private var hovered: String?
    @State private var dropTarget: String?
    @State private var showGuardrail = false
    /// Le garde-fou n'apparaît qu'une fois par jour.
    @AppStorage("guardrail.lastShownDay") private var guardrailLastShownDay = ""
    @State private var showReview = false

    private var planSize: Int { model.rules.planSize }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Plan du jour")
                        .font(.display(30, bold: true))
                        .tracking(-0.45)
                    Text("Choisis \(planSize) tâche\(planSize > 1 ? "s" : ""), dans l'ordre. Le reste attendra.")
                        .font(.text(15))
                        .foregroundStyle(Theme.label2)
                }
                Spacer()
                if model.todayPlan != nil {
                    Button(model.reviewDoneToday ? "Revoir le bilan" : "Bilan du soir") { showReview = true }
                        .buttonStyle(PillButtonStyle(size: .small))
                }
            }
            HStack(alignment: .top, spacing: 32) {
                candidateColumn
                planColumn
            }
            .padding(.top, 28)
            .frame(maxHeight: .infinity)
        }
        .padding(.leading, 32)
        .padding(.trailing, 40)
        .padding(.top, 4)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            if !loaded {
                // Sans plan aujourd'hui, on part des tâches reportées par le bilan de la veille.
                draft = model.planIDs.isEmpty ? model.carriedOverIDs : model.planIDs
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
        .sheet(isPresented: $showGuardrail) {
            GuardrailSheet(plan: draft) { commitPlan() }
                .environment(model)
        }
        .sheet(isPresented: $showReview) {
            ReviewSheet()
                .environment(model)
                .modelContext(model.context)
        }
    }

    /// Le garde-fou s'intercale quand il y a plus de chantiers actifs que la cible.
    private func validate() {
        let today = Format.dayKey(.now)
        if model.activeChantiers.count > model.rules.maxActive, guardrailLastShownDay != today {
            guardrailLastShownDay = today
            showGuardrail = true
        } else {
            commitPlan()
        }
    }

    private func commitPlan() {
        model.savePlan(draft)
        onValidate()
    }

    // MARK: Candidates

    private var candidateColumn: some View {
        let candidates = model.candidates.filter { !draft.contains($0.id) }
        return VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "Candidates")
                .padding(.leading, 2)
            if candidates.isEmpty {
                VStack(spacing: 6) {
                    Text(model.isLoading ? "Chargement…" : "Plus aucune candidate")
                        .font(.text(14, .semibold))
                    Text(model.isLoading ? "Done récupère tes tâches Todoist." : "Toutes tes tâches prioritaires sont dans le plan.")
                        .font(.text(13))
                        .foregroundStyle(Theme.label2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 260)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .surface(radius: 18)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(candidates) { task in
                            candidateRow(task)
                        }
                    }
                    .padding(6)
                    .surface(radius: 18)
                    .padding(.bottom, 2)
                }
                .scrollIndicators(.never)
                .fixedSize(horizontal: false, vertical: candidates.count <= 8)
            }
            Button("Chercher une autre tâche…") { showPicker = true }
                .buttonStyle(PillButtonStyle(kind: .plain, size: .small))
                .disabled(draft.count >= Rules.maxPlanSize)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func candidateRow(_ task: TodoistTask) -> some View {
        let isFull = draft.count >= Rules.maxPlanSize
        return HStack(spacing: 12) {
            TaskRowContent(task: task, showDetails: false)
            Button {
                add(task.id)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accentText)
                    .frame(width: 26, height: 26)
                    .background(Theme.accentTint, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isFull)
            .opacity(isFull ? 0.4 : 1)
            .help(isFull ? "Le plan compte déjà \(Rules.maxPlanSize) tâches" : "Ajouter au plan")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(hovered == task.id ? Theme.fill : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
        .onHover { inside in setHovered(task.id, inside) }
        .draggable(task.id)
    }

    // MARK: Aujourd'hui

    private var planColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "Aujourd'hui")
                .padding(.leading, 2)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(draft.enumerated()), id: \.element) { offset, id in
                        planRow(id, position: offset + 1)
                    }
                    if draft.count < planSize {
                        ForEach(draft.count..<planSize, id: \.self) { index in
                            emptySlot(position: index + 1)
                        }
                    }
                    if draft.count > planSize {
                        Text("\(draft.count) tâches. Au-delà de \(planSize), les suivantes passent en retrait.")
                            .font(.text(12))
                            .foregroundStyle(Theme.orangeText)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.bottom, 2)
            }
            .scrollIndicators(.never)
            Spacer(minLength: 0)
            HStack {
                Text(doneText)
                    .font(.text(12))
                    .foregroundStyle(Theme.label2)
                Spacer()
                Button("Valider le plan", action: validate)
                    .buttonStyle(PillButtonStyle(kind: .primary))
                    .keyboardShortcut(.defaultAction)
                    .disabled(draft.isEmpty)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func planRow(_ id: String, position: Int) -> some View {
        let isHovered = hovered == id
        let isSecondary = position > planSize
        HStack(spacing: 16) {
            Text("\(position)")
                .font(.mono(26))
                .foregroundStyle(isSecondary ? Theme.label3 : Theme.accentText)
                .frame(width: 22, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                if let task = model.index[id] {
                    Text(task.content)
                        .font(.text(15, .medium))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        Text(model.projectName(for: task))
                            .foregroundStyle(Theme.label2)
                        if model.carriedOverIDs.contains(id) {
                            Text("· Reportée")
                                .foregroundStyle(Theme.orangeText)
                        }
                    }
                    .font(.text(12))
                } else {
                    Text("Tâche terminée ou introuvable")
                        .font(.text(14))
                        .foregroundStyle(Theme.label2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(isSecondary ? 0.55 : 1)
            Button {
                draft.removeAll { $0 == id }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.label2)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().strokeBorder(Theme.label3, lineWidth: 1))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0)
            .help("Retirer du plan")
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 13))
                .foregroundStyle(Theme.label3)
                .help("Glisser pour réordonner")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .surface(radius: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.ring, lineWidth: dropTarget == id ? 2 : 0)
        )
        .contentShape(Rectangle())
        .onHover { inside in setHovered(id, inside) }
        .draggable(id)
        .dropDestination(for: String.self) { items, _ in
            for item in items { place(item, onto: id) }
            return true
        } isTargeted: { targeted in
            dropTarget = targeted ? id : (dropTarget == id ? nil : dropTarget)
        }
        .contextMenu {
            Button("Monter") { shift(id, by: -1) }
                .disabled(position == 1)
            Button("Descendre") { shift(id, by: 1) }
                .disabled(position == draft.count)
            Divider()
            Button("Retirer du plan") { draft.removeAll { $0 == id } }
        }
    }

    /// Emplacement en pointillés, en attendant une tâche.
    private func emptySlot(position: Int) -> some View {
        HStack(spacing: 16) {
            Text("\(position)")
                .font(.mono(26))
                .foregroundStyle(Theme.label3)
                .frame(width: 22, alignment: .leading)
            Text("Ajoute une \(position == 1 ? "1re" : "\(position)e") tâche depuis la liste")
                .font(.text(14))
                .foregroundStyle(Theme.label2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .frame(height: 66)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.label3, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        )
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { items, _ in
            items.forEach(add)
            return true
        }
    }

    // MARK: Aides

    private var doneText: String {
        let done = model.todayPlan?.doneIDs.count ?? 0
        switch done {
        case 0: return ""
        case 1: return "1 tâche terminée aujourd'hui"
        default: return "\(done) tâches terminées aujourd'hui"
        }
    }

    private func setHovered(_ id: String, _ inside: Bool) {
        if inside {
            hovered = id
        } else if hovered == id {
            hovered = nil
        }
    }

    private func add(_ id: String) {
        guard !draft.contains(id), draft.count < Rules.maxPlanSize, model.index[id] != nil else { return }
        draft.append(id)
    }

    /// Dépose une tâche à la place d'une autre : avant si elle remonte, après si elle descend.
    private func place(_ id: String, onto target: String) {
        guard id != target, let to = draft.firstIndex(of: target) else { return }
        if let from = draft.firstIndex(of: id) {
            draft.remove(at: from)
            draft.insert(id, at: to)
        } else if draft.count < Rules.maxPlanSize, model.index[id] != nil {
            draft.insert(id, at: to)
        }
    }

    private func shift(_ id: String, by offset: Int) {
        guard let from = draft.firstIndex(of: id) else { return }
        let to = from + offset
        guard draft.indices.contains(to) else { return }
        draft.swapAt(from, to)
    }
}
