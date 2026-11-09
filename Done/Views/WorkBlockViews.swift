import SwiftUI

/// Fiche d'un bloc de travail : la tâche, le jour et l'horaire (à changer ici ou en glissant le bloc
/// dans la grille), puis « Lancer le pomodoro », « Ouvrir la tâche » et « Retirer le bloc ». C'est
/// aussi là que mène « Déplacer… » sur le rappel du bloc.
struct WorkBlockSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let blockID: String

    @State private var day = Date.now
    @State private var start = Date.now
    @State private var end = Date.now
    @State private var loaded = false
    @State private var editingTask: TodoTask?

    var body: some View {
        let block = model.workBlock(blockID)
        let task = block.flatMap { model.store[$0.taskID] }
        let from = combine(day, start)
        let to = combine(day, end)
        let isValid = to > from
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Bloc de travail")
            if let task, let block {
                Text(task.title)
                    .doneText(.displayM)
                    .foregroundStyle(DoneColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, DoneSpace.s8)
                Text(details(task))
                    .doneText(.callout)
                    .foregroundStyle(DoneColor.textSecondary)
                    .padding(.top, DoneSpace.s4)
                HStack(alignment: .top, spacing: DoneSpace.s20) {
                    labeled("Jour") {
                        DatePicker("Jour", selection: $day, displayedComponents: .date)
                            .labelsHidden()
                    }
                    labeled("De") {
                        DatePicker("De", selection: $start, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    labeled("À") {
                        DatePicker("À", selection: $end, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                }
                .padding(.top, DoneSpace.s16)
                if !isValid {
                    Text("La fin doit venir après le début.")
                        .doneText(.caption)
                        .foregroundStyle(DoneColor.stateRiskText)
                        .padding(.top, DoneSpace.s8)
                }
                Text("Done te prévient 5 min avant le début : lancer le pomodoro, le décaler de 30 min, ou déplacer le bloc. Pendant le bloc, Ma journée propose cette tâche. Au calendrier, glisse le bloc au-dessus de la grille pour rendre la tâche aux échéances du jour.")
                    .doneText(.caption)
                    .foregroundStyle(DoneColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, DoneSpace.s12)
                // Actions sur le bloc et la tâche, à gauche ; la session et l'enregistrement, en bas.
                HStack(spacing: DoneSpace.s8) {
                    Button {
                        editingTask = task
                    } label: {
                        Label("Ouvrir la tâche", systemImage: "checkmark.square")
                    }
                    .buttonStyle(DoneButtonStyle(kind: .plain, compact: true))
                    .fixedSize()
                    Button {
                        model.deleteWorkBlock(block.id)
                        dismiss()
                    } label: {
                        Label("Retirer le bloc", systemImage: "calendar.badge.minus")
                    }
                    .buttonStyle(DoneButtonStyle(kind: .plain, compact: true))
                    .fixedSize()
                    .help("La tâche reste dans sa liste ; seul le temps réservé est retiré")
                }
                .padding(.top, DoneSpace.s16)
                HStack(spacing: DoneSpace.s8) {
                    if task.isOpen {
                        Button {
                            save(block, from: from, to: to)
                            model.requestWorkBlock(block.id, .start)
                            dismiss()
                        } label: {
                            Label("Lancer le pomodoro", systemImage: "play.fill")
                        }
                        .buttonStyle(DoneButtonStyle())
                        .fixedSize()
                    }
                    Spacer(minLength: DoneSpace.s8)
                    Button("Annuler") { dismiss() }
                        .buttonStyle(DoneButtonStyle())
                        .keyboardShortcut(.cancelAction)
                        .fixedSize()
                    Button("Enregistrer") {
                        save(block, from: from, to: to)
                        dismiss()
                    }
                    .buttonStyle(DoneButtonStyle(kind: .primary))
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
                    .fixedSize()
                }
                .padding(.top, DoneSpace.s16)
            } else {
                Text("Ce bloc n'existe plus.")
                    .doneText(.body)
                    .foregroundStyle(DoneColor.textSecondary)
                    .padding(.top, DoneSpace.s8)
                HStack {
                    Spacer()
                    Button("Fermer") { dismiss() }
                        .buttonStyle(DoneButtonStyle())
                        .keyboardShortcut(.cancelAction)
                }
                .padding(.top, DoneSpace.s20)
            }
        }
        .padding(DoneSpace.s24)
        .frame(width: 580)
        .background(DoneColor.bgCanvas)
        .onAppear {
            guard !loaded, let block else { return }
            day = block.start
            start = block.start
            end = block.end
            loaded = true
        }
        .sheet(item: $editingTask) { task in
            TaskEditorSheet(taskID: task.id)
                .environment(model)
        }
    }

    /// « Préparer le bilan · Deepwork, 50 min » : la liste et la durée d'un pomodoro pour cette tâche.
    private func details(_ task: TodoTask) -> String {
        let minutes = model.store.blockMinutes(for: task, rules: model.rules)
        var parts = [model.listName(for: task)]
        parts.append("pomodoro de \(Format.minutes(Double(minutes)))")
        if !task.isOpen { parts.append("faite") }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func save(_ block: WorkBlock, from: Date, to: Date) {
        guard to > from, from != block.start || to != block.end else { return }
        var updated = block
        updated.start = from
        updated.end = to
        model.updateWorkBlock(updated)
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DoneSpace.s6) {
            Eyebrow(text: title)
            content()
        }
    }

    /// Le jour choisi, à l'heure choisie.
    private func combine(_ day: Date, _ time: Date) -> Date {
        let calendar = Calendar.current
        let parts = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: 0, of: day) ?? day
    }
}

/// Un clic sur un créneau libre de la grille : une réunion, ou du temps réservé pour une tâche.
struct SlotChoice: Identifiable {
    let id = UUID()
    let start: Date
}

extension View {
    /// Propose, pour le créneau cliqué, « Nouvelle réunion » ou « Bloquer pour une tâche… » ; le second
    /// ouvre le choix d'une tâche, qui prend un bloc d'un pomodoro à cette heure.
    func slotChoice(_ choice: Binding<SlotChoice?>, meeting: @escaping (Date) -> Void, pickTask: @escaping (Date) -> Void) -> some View {
        confirmationDialog(
            choice.wrappedValue.map { "\(Format.longDay($0.start).prefix(1).uppercased() + Format.longDay($0.start).dropFirst()), \(Format.time($0.start))" } ?? "",
            isPresented: Binding(get: { choice.wrappedValue != nil }, set: { if !$0 { choice.wrappedValue = nil } }),
            presenting: choice.wrappedValue
        ) { slot in
            Button("Nouvelle réunion") { meeting(slot.start) }
            Button("Bloquer pour une tâche…") { pickTask(slot.start) }
            Button("Annuler", role: .cancel) {}
        }
    }
}
