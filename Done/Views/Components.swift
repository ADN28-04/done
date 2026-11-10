import SwiftUI

/// Puces d'une tâche, à droite de sa ligne : priorité, blocage, échéance, puis durée.
struct TaskChips: View {
    @Environment(AppModel.self) private var model
    let task: TodoTask
    /// L'étiquette de la vue en cours : inutile de la répéter sur chaque ligne.
    var hiding: String?
    /// Dans une carte étroite, les puces passent à la ligne au lieu de pousser le titre.
    var wraps = false

    var body: some View {
        let layout = wraps ? AnyLayout(FlowLayout()) : AnyLayout(HStackLayout(spacing: DoneSpace.s12))
        layout {
            PriorityChip(priority: task.priority)
            if task.isBlocked {
                StateChip(kind: .blocked, title: "Bloquée")
            }
            ForEach(task.tags.filter { $0 != hiding }, id: \.self) { tag in
                TagChip(name: tag)
            }
            if let due = task.due {
                InfoChip(symbol: "calendar", text: Format.chipDate(due), isAlert: Format.isOverdue(due))
            }
            if let recurrence = task.recurrence {
                InfoChip(symbol: "arrow.clockwise", text: recurrence.label)
                    .help("Revient \(recurrence.label.lowercased()), une fois cochée")
            }
            if let minutes = sessionMinutes {
                InfoChip(symbol: "clock", text: Format.minutes(Double(minutes)))
            }
        }
    }

    /// Durée de session d'une tâche rapide ou Deepwork. Une tâche normale n'affiche rien.
    private var sessionMinutes: Int? {
        switch task.kind {
        case .quick: model.rules.quickMinutes
        case .deepwork: model.rules.deepworkMinutes
        case .normal: nil
        }
    }
}

/// Contenu d'une ligne de tâche : titre (body.strong), métadonnées (caption) et puces à droite.
/// Tout juste cochée (`isFinishing`), le titre se barre et « Fait » remplace les puces.
/// Dans une carte étroite (`stacked`), le titre prend toute la largeur et les puces passent dessous,
/// à la ligne si la place manque : elles ne poussent jamais le titre.
struct TaskRowContent: View {
    @Environment(AppModel.self) private var model
    let task: TodoTask
    var showDetails = true
    var isFinishing = false
    var stacked = false

    var body: some View {
        if stacked {
            VStack(alignment: .leading, spacing: DoneSpace.s4) {
                TaskTitle(title: task.title, isFinishing: isFinishing)
                if showDetails, !details.isEmpty {
                    Text(details)
                        .doneText(.caption)
                        .foregroundStyle(DoneColor.textSecondary)
                        .lineLimit(1)
                }
                TaskRowTrailing(isFinishing: isFinishing, alignment: .leading) {
                    TaskChips(task: task, wraps: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .help(details)
        } else {
            inline
        }
    }

    private var inline: some View {
        HStack(spacing: DoneSpace.s12) {
            VStack(alignment: .leading, spacing: DoneSpace.s2) {
                TaskTitle(title: task.title, isFinishing: isFinishing)
                if showDetails, !details.isEmpty {
                    Text(details)
                        .doneText(.caption)
                        .foregroundStyle(DoneColor.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            TaskRowTrailing(isFinishing: isFinishing) {
                TaskChips(task: task)
            }
        }
        .help(details)
    }

    var details: String {
        var parts = [model.listName(for: task)]
        let steps = model.index.children(of: task.id).count
        if steps > 0 { parts.append("\(steps) étape\(steps > 1 ? "s" : "")") }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

/// Titre d'une ligne de tâche (body.strong, deux lignes au plus). Quand la tâche vient d'être cochée,
/// le trait se dessine de gauche à droite, 80 ms après la coche (dur-base), et le titre passe en texte
/// secondaire. Avec « Réduire les animations », le trait arrive en fondu.
struct TaskTitle: View {
    let title: String
    var isFinishing = false
    /// Tâche bloquée : titre en texte secondaire.
    var isMuted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        text
            .foregroundStyle(isFinishing || isMuted ? DoneColor.textSecondary : DoneColor.textPrimary)
            .overlay {
                // Le trait seul : le même texte, transparent et barré, découvert de gauche à droite.
                text
                    .strikethrough(true, color: DoneColor.textSecondary)
                    .foregroundStyle(Color.clear)
                    .mask(alignment: .leading) {
                        GeometryReader { proxy in
                            Rectangle()
                                .frame(width: isFinishing || reduceMotion ? proxy.size.width : 0)
                        }
                    }
                    .opacity(isFinishing ? 1 : 0)
            }
            .animation(reduceMotion ? DoneMotion.fade : DoneMotion.appear.delay(0.08), value: isFinishing)
    }

    private var text: some View {
        Text(title)
            .doneText(.bodyStrong)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Bout droit d'une ligne de tâche : ses puces, que « Fait » remplace en rebondissant quand la tâche
/// vient d'être cochée (DoneMotion.pop). Avec « Réduire les animations », un fondu.
struct TaskRowTrailing<Chips: View>: View {
    let isFinishing: Bool
    /// À droite de la ligne, ou sous le titre (`.leading`) dans une ligne à deux étages.
    var alignment: Alignment = .trailing
    @ViewBuilder let chips: Chips
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: alignment) {
            if isFinishing {
                StateChip(kind: .doneToday, title: "Fait")
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.6).combined(with: .opacity))
            } else {
                chips
                    .transition(.opacity)
            }
        }
        .animation(DoneMotion.motion(DoneMotion.pop, reduced: reduceMotion), value: isFinishing)
    }
}

/// Puces qui passent à la ligne quand la place manque, de gauche à droite, centrées sur chaque ligne.
/// Une puce vide (P3, P4) ne prend ni place ni écart.
struct FlowLayout: Layout {
    var spacing: CGFloat = DoneSpace.s12
    var lineSpacing: CGFloat = DoneSpace.s4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let lines = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = lines.map(\.width).max() ?? 0
        let height = lines.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(lines.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        var placed = Set<Int>()
        for line in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in line.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (line.height - size.height) / 2), proposal: ProposedViewSize(size))
                placed.insert(index)
                x += size.width + spacing
            }
            y += line.height + lineSpacing
        }
        for index in subviews.indices where !placed.contains(index) {
            subviews[index].place(at: bounds.origin, proposal: .zero)
        }
    }

    private struct Line {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Line] {
        var lines: [Line] = []
        var line = Line()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            guard size.width > 0, size.height > 0 else { continue }
            if !line.indices.isEmpty, line.width + spacing + size.width > width {
                lines.append(line)
                line = Line()
            }
            line.width += (line.indices.isEmpty ? 0 : spacing) + size.width
            line.height = max(line.height, size.height)
            line.indices.append(index)
        }
        if !line.indices.isEmpty { lines.append(line) }
        return lines
    }
}

/// Une ligne cochée quitte sa liste en glissant vers « Fait aujourd'hui », plus bas ; avec
/// « Réduire les animations », en fondu.
func taskRowTransition(reduced: Bool) -> AnyTransition {
    .asymmetric(insertion: .opacity, removal: reduced ? .opacity : .opacity.combined(with: .offset(y: 12)))
}

/// Ce que Done a compris à la fin du titre saisi (`QuickEntry`), montré avant l'ajout : échéance,
/// priorité, étiquettes. Rien quand il n'y a rien à lire.
struct QuickEntryHint: View {
    let entry: QuickEntry

    var body: some View {
        if !entry.pieces.isEmpty {
            HStack(spacing: DoneSpace.s12) {
                Text("Compris")
                    .doneText(.caption)
                    .foregroundStyle(DoneColor.textSecondary)
                ForEach(Array(entry.pieces.enumerated()), id: \.offset) { _, piece in
                    chip(piece)
                }
            }
            .transition(.opacity)
            .help("Lu à la fin du titre, retiré du titre à l'ajout")
        }
    }

    @ViewBuilder
    private func chip(_ piece: QuickEntry.Piece) -> some View {
        switch piece {
        case .due(let date):
            InfoChip(symbol: "calendar", text: Format.chipDate(date))
        case .priority(let value):
            InfoChip(symbol: "flag", text: "P\(value)")
        case .tag(let name):
            TagChip(name: name)
        case .recurrence(let recurrence):
            InfoChip(symbol: "arrow.clockwise", text: recurrence.label)
        }
    }
}

/// Recherche dans toutes les tâches ouvertes.
struct TaskPickerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let title: String
    let onPick: (TodoTask) -> Void
    @State private var query = ""
    @State private var hovered: String?
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DoneSpace.s16) {
            Text(title)
                .doneText(.displayM)
                .foregroundStyle(DoneColor.textPrimary)
            TextField("Rechercher une tâche ou un projet", text: $query)
                .focused($searchFocused)
                .doneField(focused: searchFocused)
            ScrollView {
                LazyVStack(spacing: DoneSpace.s2) {
                    ForEach(model.pickableTasks(matching: query)) { task in
                        Button {
                            dismiss()
                            onPick(task)
                        } label: {
                            TaskRowContent(task: task)
                                .padding(.horizontal, DoneSpace.s12)
                                .frame(minHeight: 48)
                                .background(hovered == task.id ? DoneColor.surfaceHover : Color.clear, in: RoundedRectangle(cornerRadius: DoneRadius.md, style: .continuous))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .onHover { inside in hovered = inside ? task.id : (hovered == task.id ? nil : hovered) }
                    }
                }
                .padding(6)
            }
            .doneCard(radius: DoneRadius.md, flat: true)
            HStack {
                Spacer()
                Button("Annuler") { dismiss() }
                    .buttonStyle(DoneButtonStyle())
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(DoneSpace.s24)
        .frame(width: 600, height: 540)
        .background(DoneColor.bgCanvas)
        .onAppear { searchFocused = true }
    }
}

// MARK: Note de reprise

/// Champ « Où tu en es ? », enregistré au fil de la frappe dans la note de reprise de la tâche.
struct ResumeNoteField: View {
    @Environment(AppModel.self) private var model
    let taskID: String
    var placeholder = "Où tu en es ? Une ligne pour reprendre plus vite"
    var focused: FocusState<Bool>.Binding

    @State private var text = ""
    @State private var loaded = false

    var body: some View {
        TextField(placeholder, text: $text)
            .multilineTextAlignment(.leading)
            .focused(focused)
            .onSubmit { focused.wrappedValue = false }
            .doneField(focused: focused.wrappedValue)
            .onAppear {
                guard !loaded else { return }
                text = model.resumeNote(for: taskID)?.text ?? ""
                loaded = true
            }
            .onChange(of: text) {
                if loaded { model.setResumeNote(text, for: taskID) }
            }
    }
}

/// Rappel de la note de reprise, quand la tâche revient sur l'écran Focus.
struct ResumeNoteCard: View {
    let note: ResumeNote

    var body: some View {
        VStack(alignment: .leading, spacing: DoneSpace.s4) {
            Eyebrow(text: "Où tu en étais · \(Format.moment(note.writtenAt))")
            Text(note.text)
                .doneText(.body)
                .foregroundStyle(DoneColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, DoneSpace.s16)
        .padding(.vertical, DoneSpace.s12)
        .frame(maxWidth: 520, alignment: .leading)
        .doneCard(radius: DoneRadius.md)
    }
}
