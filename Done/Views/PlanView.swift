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
    @State private var showReview = false

    private var planSize: Int { model.rules.planSize }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DoneSpace.s4) {
                    Text("Plan du jour")
                        .doneText(.displayL)
                        .foregroundStyle(DoneColor.textPrimary)
                    Text("Choisis \(planSize) tâche\(planSize > 1 ? "s" : ""), dans l'ordre. Le reste attendra.")
                        .doneText(.body)
                        .foregroundStyle(DoneColor.textSecondary)
                }
                Spacer()
                if model.todayPlan != nil {
                    Button(model.reviewDoneToday ? "Revoir le bilan" : "Bilan du soir") { showReview = true }
                        .buttonStyle(DoneButtonStyle())
                }
            }
            HStack(alignment: .top, spacing: DoneSpace.s32) {
                candidateColumn
                planColumn
            }
            .padding(.top, DoneSpace.s24)
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, DoneSpace.s40)
        .padding(.top, DoneSpace.s4)
        .padding(.bottom, DoneSpace.s24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            if !loaded {
                // Sans plan aujourd'hui, on part des tâches reportées par le bilan de la veille.
                draft = model.planIDs.isEmpty ? model.carriedOverIDs : model.planIDs
                loaded = true
            }
        }
        .onChange(of: model.store.tasks) {
            // Retire les tâches cochées ou supprimées entre-temps.
            draft.removeAll { model.index[$0] == nil }
        }
        .sheet(isPresented: $showPicker) {
            TaskPickerView(title: "Ajouter une tâche au plan") { add($0.id) }
                .environment(model)
        }
        .sheet(isPresented: $showReview) {
            ReviewSheet()
                .environment(model)
                .modelContext(model.context)
        }
    }

    private func validate() {
        model.savePlan(draft)
        onValidate()
    }

    // MARK: Candidates

    private var candidateColumn: some View {
        let candidates = model.candidates.filter { !draft.contains($0.id) }
        return VStack(alignment: .leading, spacing: DoneSpace.s8) {
            Eyebrow(text: "Candidates")
                .padding(.leading, DoneSpace.s2)
            if candidates.isEmpty {
                VStack(spacing: DoneSpace.s6) {
                    Text(model.index.all.isEmpty ? "Aucune tâche pour l'instant" : "Plus aucune candidate")
                        .doneText(.title)
                        .foregroundStyle(DoneColor.textPrimary)
                    Text(model.index.all.isEmpty ? "Ajoute-les dans l'Inbox, ou avec ⌘N." : "Les tâches P1 et P2 et celles qui arrivent à échéance sont déjà dans le plan. Les autres sont dans « Chercher une autre tâche ».")
                        .doneText(.callout)
                        .foregroundStyle(DoneColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DoneSpace.s40)
                .doneCard(radius: DoneRadius.lg)
            } else {
                ScrollView {
                    VStack(spacing: DoneSpace.s2) {
                        ForEach(candidates) { task in
                            candidateRow(task)
                        }
                    }
                    .padding(DoneSpace.s6)
                    .doneCard(radius: DoneRadius.lg)
                    .padding(.bottom, DoneSpace.s2)
                }
                .scrollIndicators(.never)
                .fixedSize(horizontal: false, vertical: candidates.count <= 8)
            }
            Button("Chercher une autre tâche…") { showPicker = true }
                .buttonStyle(DoneButtonStyle(kind: .plain))
                .disabled(draft.count >= Rules.maxPlanSize)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func candidateRow(_ task: TodoTask) -> some View {
        let isFull = draft.count >= Rules.maxPlanSize
        return HStack(spacing: DoneSpace.s12) {
            TaskRowContent(task: task)
            Button {
                add(task.id)
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(DoneIconButtonStyle())
            .disabled(isFull)
            .help(isFull ? "Le plan compte déjà \(Rules.maxPlanSize) tâches" : "Ajouter au plan")
        }
        .padding(.horizontal, DoneSpace.s12)
        .frame(minHeight: 52)
        .background(hovered == task.id ? DoneColor.surfaceHover : Color.clear, in: RoundedRectangle(cornerRadius: DoneRadius.md, style: .continuous))
        .contentShape(Rectangle())
        .onHover { inside in setHovered(task.id, inside) }
        .draggable(task.id)
    }

    // MARK: Aujourd'hui

    private var planColumn: some View {
        VStack(alignment: .leading, spacing: DoneSpace.s8) {
            Eyebrow(text: "Aujourd'hui")
                .padding(.leading, DoneSpace.s2)
            ScrollView {
                VStack(alignment: .leading, spacing: DoneSpace.s8) {
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
                            .doneText(.caption)
                            .foregroundStyle(DoneColor.textSecondary)
                            .padding(.horizontal, DoneSpace.s4)
                    }
                }
                .padding(.bottom, DoneSpace.s2)
            }
            .scrollIndicators(.never)
            Spacer(minLength: 0)
            MeetingsCard()
                .padding(.bottom, DoneSpace.s16)
            HStack {
                Text(doneText)
                    .doneText(.caption)
                    .foregroundStyle(DoneColor.textSecondary)
                Spacer()
                Button("Valider le plan", action: validate)
                    .buttonStyle(DoneButtonStyle(kind: .primary))
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
        HStack(spacing: DoneSpace.s12) {
            NumberTile(position: position, isFilled: !isSecondary)
            VStack(alignment: .leading, spacing: DoneSpace.s2) {
                if let task = model.index[id] {
                    Text(task.title)
                        .doneText(.bodyStrong)
                        .foregroundStyle(DoneColor.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: DoneSpace.s6) {
                        Text(model.projectName(for: task))
                            .foregroundStyle(DoneColor.textSecondary)
                        if model.carriedOverIDs.contains(id) {
                            Text("· Reportée")
                                .foregroundStyle(DoneColor.stateActiveText)
                        }
                    }
                    .doneText(.caption)
                } else {
                    Text("Tâche terminée ou introuvable")
                        .doneText(.body)
                        .foregroundStyle(DoneColor.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(isSecondary ? 0.6 : 1)
            if let task = model.index[id] {
                TaskChips(task: task)
            }
            Button {
                draft.removeAll { $0 == id }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DoneColor.textSecondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0)
            .help("Retirer du plan")
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DoneColor.textDisabled)
                .help("Glisser pour réordonner")
        }
        .padding(.horizontal, DoneSpace.s16)
        .frame(minHeight: 60)
        .doneCard()
        .overlay(
            RoundedRectangle(cornerRadius: DoneRadius.md, style: .continuous)
                .strokeBorder(DoneColor.focusRing, lineWidth: dropTarget == id ? 2 : 0)
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
        HStack(spacing: DoneSpace.s12) {
            NumberTile(position: position, isFilled: false)
            Text("Emplacement libre : ajoute une \(position == 1 ? "1re" : "\(position)e") tâche depuis la liste")
                .doneText(.callout)
                .foregroundStyle(DoneColor.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DoneSpace.s16)
        .frame(height: 60)
        .overlay(
            RoundedRectangle(cornerRadius: DoneRadius.md, style: .continuous)
                .strokeBorder(DoneColor.stateWaiting, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
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

/// Tuile numérotée de 24 : la place dans le plan. Pleine pour les tâches retenues, en contour sinon.
struct NumberTile: View {
    let position: Int
    var isFilled = true

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DoneRadius.sm, style: .continuous)
        Text("\(position)")
            .font(.mono(13, .semibold))
            .foregroundStyle(isFilled ? DoneColor.stateOnActive : DoneColor.textSecondary)
            .frame(width: 24, height: 24)
            .background(isFilled ? DoneColor.stateActive : Color.clear, in: shape)
            .overlay {
                if !isFilled {
                    shape.strokeBorder(DoneColor.borderDefault, lineWidth: 1)
                }
            }
    }
}
