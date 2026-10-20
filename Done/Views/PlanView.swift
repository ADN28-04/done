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

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Plan du jour")
                    .font(.system(size: 26, weight: .bold))
                    .tracking(-0.26)
                    .foregroundStyle(Theme.label)
                Text("Choisis tes \(Rules.recommendedPlanSize) tâches les plus importantes, dans l'ordre. Le reste attendra.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.label2)
            }
            TimelineView(.periodic(from: .now, by: 60)) { context in
                AgendaStrip(meetings: model.meetingsToday, now: context.date)
            }
            HStack(alignment: .top, spacing: 24) {
                candidateColumn
                planColumn
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    // MARK: Candidates

    private var candidateColumn: some View {
        let candidates = model.candidates.filter { !draft.contains($0.id) }
        return VStack(alignment: .leading, spacing: 10) {
            ColumnHeader(title: "Candidates", count: candidates.isEmpty ? nil : candidates.count)
            if candidates.isEmpty {
                EmptyPanel(
                    title: model.isLoading ? "Chargement…" : "Plus aucune candidate",
                    message: model.isLoading ? "Done récupère tes tâches Todoist." : "Toutes tes tâches prioritaires sont dans le plan.",
                    actionTitle: model.isLoading ? nil : "Rafraîchir",
                    action: { Task { await model.refresh() } }
                )
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(candidates) { task in
                            candidateRow(task)
                        }
                    }
                    .padding(4)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            Button("Chercher une autre tâche…") { showPicker = true }
                .buttonStyle(PillButtonStyle(kind: .plain))
                .disabled(draft.count >= Rules.maxPlanSize)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func candidateRow(_ task: TodoistTask) -> some View {
        let isHovered = hovered == task.id
        let isFull = draft.count >= Rules.maxPlanSize
        return HStack(spacing: 12) {
            TaskRowContent(task: task)
            Button {
                add(task.id)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isHovered ? Theme.label : Theme.label2)
                    .frame(width: 24, height: 24)
                    .background(isHovered ? Theme.surface : Theme.fill, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isFull)
            .opacity(isFull ? 0.4 : 1)
            .help(isFull ? "Le plan compte déjà \(Rules.maxPlanSize) tâches" : "Ajouter au plan")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isHovered ? Theme.fill : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .onHover { inside in setHovered(task.id, inside) }
        .draggable(task.id)
    }

    // MARK: Aujourd'hui

    private var planColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            ColumnHeader(title: "Aujourd'hui", count: draft.isEmpty ? nil : draft.count)
            if draft.isEmpty {
                EmptyPanel(
                    title: "Aucune tâche pour l'instant",
                    message: "Ajoute tes \(Rules.recommendedPlanSize) tâches les plus importantes avec +.",
                    actionTitle: nil,
                    action: {}
                )
                .dropDestination(for: String.self) { items, _ in
                    items.forEach(add)
                    return true
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(spacing: 0) {
                            ForEach(Array(draft.enumerated()), id: \.element) { offset, id in
                                if offset == Rules.recommendedPlanSize {
                                    Hairline().padding(.horizontal, 10).padding(.vertical, 4)
                                }
                                planRow(id, position: offset + 1)
                            }
                        }
                        .padding(4)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .dropDestination(for: String.self) { items, _ in
                            items.forEach(add)
                            return true
                        }
                        if draft.count > Rules.recommendedPlanSize {
                            Text("\(draft.count) tâches. Au-delà de trois, les suivantes passent en retrait.")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.orangeText)
                                .padding(.horizontal, 6)
                        }
                    }
                }
            }
            HStack {
                Text(doneText)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.label2)
                Spacer()
                Button("Valider le plan") {
                    model.savePlan(draft)
                    onValidate()
                }
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
        let isSecondary = position > Rules.recommendedPlanSize
        HStack(spacing: 12) {
            Text("\(position)")
                .font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(isSecondary ? Theme.label3 : Theme.label)
                .frame(width: 14, alignment: .trailing)
            if let task = model.index[id] {
                TaskRowContent(task: task, emphasized: !isSecondary)
                    .opacity(isSecondary ? 0.5 : 1)
            } else {
                Text("Tâche terminée ou introuvable")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.label2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button {
                draft.removeAll { $0 == id }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.label2)
                    .frame(width: 20, height: 20)
                    .overlay(Circle().strokeBorder(Theme.label3, lineWidth: 1))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .opacity(isHovered || isSecondary ? 1 : 0)
            .help("Retirer du plan")
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12))
                .foregroundStyle(Theme.label3)
                .help("Glisser pour réordonner")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(rowBackground(id: id, hovered: isHovered), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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

    // MARK: Aides

    private var doneText: String {
        let done = model.todayPlan?.doneIDs.count ?? 0
        switch done {
        case 0: return "Aucune tâche terminée aujourd'hui"
        case 1: return "1 tâche terminée aujourd'hui"
        default: return "\(done) tâches terminées aujourd'hui"
        }
    }

    private func rowBackground(id: String, hovered: Bool) -> Color {
        if dropTarget == id { return Theme.accentTint }
        return hovered ? Theme.fill : .clear
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

private struct ColumnHeader: View {
    let title: String
    let count: Int?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.label)
            if let count {
                Text("\(count)")
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(Theme.label2)
            }
        }
        .padding(.horizontal, 4)
    }
}

/// Panneau vide qui occupe la colonne, avec un message centré.
private struct EmptyPanel: View {
    let title: String
    let message: String
    let actionTitle: String?
    let action: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.label)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Theme.label2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
            if let actionTitle {
                Button(actionTitle, action: action)
                    .buttonStyle(PillButtonStyle())
                    .controlSize(.small)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
