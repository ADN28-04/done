import AppKit
import SwiftData
import SwiftUI

/// Libellé de la barre de menus : une image « template » du système, qui prend la couleur de la
/// barre de menus, jamais celle de Done. Mini-anneau de 16 et temps restant en chiffres tabulaires.
/// Au repos, une fois le plan du jour bouclé, un soleil remplace le glyphe de Done.
struct MenuBarLabel: View {
    let engine: FocusEngine
    let model: AppModel

    var body: some View {
        switch engine.phase {
        case .idle:
            if model.isPlanFinished {
                Image(systemName: "sun.max")
                    .accessibilityLabel("Done, plan du jour terminé")
            } else {
                Image("DoneGlyph")
            }
        case .focusing:
            Text("\(MiniRing.image(fraction: engine.remainingFraction)) \(engine.menuBarText)")
                .monospacedDigit()
        case .awaitingOutcome:
            Text("\(MiniRing.image(fraction: 1, isTrackOnly: true)) \(engine.menuBarText)")
        case .paused, .interrupted:
            Text("\(Image(systemName: "pause.fill")) \(engine.menuBarText)")
                .monospacedDigit()
        case .onBreak:
            Text("\(Image(systemName: "cup.and.saucer.fill")) \(engine.menuBarText)")
                .monospacedDigit()
        }
    }
}

/// Mini-anneau de 16 points, rendu en image « template » : la part restante, depuis midi.
private struct MiniRing: View {
    let fraction: Double
    var isTrackOnly = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.black.opacity(isTrackOnly ? 1 : 0.3), lineWidth: 2)
            if !isTrackOnly {
                Circle()
                    .trim(from: 0, to: max(0, min(1, fraction)))
                    .stroke(Color.black, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .padding(1)
        .frame(width: 16, height: 16)
    }

    @MainActor
    static func image(fraction: Double, isTrackOnly: Bool = false) -> Image {
        let renderer = ImageRenderer(content: MiniRing(fraction: fraction, isTrackOnly: isTrackOnly))
        renderer.scale = 2
        guard let image = renderer.nsImage else { return Image("DoneGlyph") }
        image.isTemplate = true
        return Image(nsImage: image)
    }
}

/// Panneau ouvert au clic sur l'icône (maquette validée : `docs/design/mymind/maquettes/panneau-barre-de-menus.html`).
/// 320 de large, sur la toile et deux halos discrets. La date ; la capture en pilule ; une carte qui dit
/// quoi faire maintenant (prochaine action ou bloc en cours, session, pause, fin de pomodoro) ; la
/// journée en une ligne ; Ouvrir Done et Quitter.
struct MenuBarView: View {
    @Environment(AppModel.self) private var model
    @Environment(FocusEngine.self) private var engine
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \FocusSession.startedAt) private var sessions: [FocusSession]
    @State private var title = ""
    @State private var projectID: String?
    /// Liste de la dernière tâche ajoutée, pour la confirmation. Effacée dès qu'on retape.
    @State private var addedTo: String?
    @FocusState private var captureFocused: Bool

    var body: some View {
        // Toutes les 30 s, pour la proposition et la prochaine réunion ; le minuteur suit le moteur.
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    dateLine(now)
                    capture
                    card(now: now)
                    today(now: now)
                }
                .padding(.horizontal, DoneSpace.s16)
                .padding(.top, 14)
                .padding(.bottom, DoneSpace.s12)
                Hairline()
                footer
            }
        }
        .frame(width: 320)
        .foregroundStyle(DoneColor.textPrimary)
        .background(PanelCanvas())
        .onAppear { captureFocused = true }
        .onDisappear { addedTo = nil }
    }

    // MARK: Date et capture

    private func dateLine(_ now: Date) -> some View {
        let day = Format.longDay(now)
        let capitalized = String(day.prefix(1)).uppercased() + String(day.dropFirst())
        let week = Calendar(identifier: .iso8601).component(.weekOfYear, from: now)
        return HStack(spacing: DoneSpace.s6) {
            Image(systemName: "sun.max")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DoneColor.accent)
            Text("\(capitalized) · semaine \(week)")
                .font(.sans(12, .semibold))
                .foregroundStyle(DoneColor.textSecondary)
        }
    }

    /// Une pilule de 40, comme la barre de saisie de Ma journée. Entrée ajoute dans la liste choisie, et
    /// le champ reste prêt pour la suivante.
    private var capture: some View {
        let isEmpty = title.trimmingCharacters(in: .whitespaces).isEmpty
        return VStack(alignment: .leading, spacing: DoneSpace.s8) {
            HStack(spacing: DoneSpace.s8) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DoneColor.textSecondary)
                TextField("Ce que tu as à faire", text: $title)
                    .textFieldStyle(.plain)
                    .font(.done(.body))
                    .focused($captureFocused)
                    .onSubmit(add)
                Button(action: add) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(SendButtonStyle())
                .disabled(isEmpty)
                .help("Ajouter (Entrée)")
            }
            .padding(.leading, 14)
            .padding(.trailing, DoneSpace.s6)
            .frame(height: 40)
            .background(DoneColor.surfaceDefault, in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(captureFocused ? DoneColor.focusRing : DoneColor.borderSubtle, lineWidth: captureFocused ? 2 : 1)
            )
            .shadow(color: DoneColor.shadowCard, radius: 15, y: 10)
            .shadow(color: DoneColor.shadowCardNear, radius: 1, y: 1)
            QuickEntryHint(entry: QuickEntry.parse(title))
                .padding(.leading, 14)
            HStack(spacing: DoneSpace.s8) {
                if let addedTo {
                    StateChip(kind: .doneToday, title: "Ajoutée dans \(addedTo)")
                        .lineLimit(1)
                } else {
                    Menu {
                        Button("Inbox") { projectID = nil }
                        ForEach(model.projects) { project in
                            Button(model.projectName(project.id)) { projectID = project.id }
                        }
                    } label: {
                        Text("Dans : \(model.projectName(projectID))")
                            .font(.done(.callout))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                Spacer(minLength: 0)
                // Ouvre la saisie complète, avec le titre et la liste déjà choisis.
                Button("Détails…") {
                    QuickCapturePanel.shared.show(prefill: TaskDraft(title: title, projectID: projectID))
                    title = ""
                }
                .buttonStyle(DoneButtonStyle(kind: .plain, compact: true))
                .help("Saisir la priorité, le type, l'échéance, les notes et les étapes")
            }
            .padding(.leading, 14)
        }
        .onChange(of: title) {
            if !title.isEmpty { addedTo = nil }
        }
    }

    private func add() {
        let draft = TaskDraft(title: title, projectID: projectID).applying(QuickEntry.parse(title))
        guard let task = model.addTask(draft) else { return }
        title = ""
        addedTo = model.listName(for: task)
    }

    // MARK: Carte

    @ViewBuilder
    private func card(now: Date) -> some View {
        switch engine.phase {
        case .idle:
            idleCard(now: now)
        case .focusing, .paused, .interrupted:
            sessionCard
        case .onBreak:
            breakCard(now: now)
        case .awaitingOutcome:
            outcomeCard(now: now)
        }
    }

    /// Au repos : la prochaine action (ou la tâche du bloc en cours), « Lancer le focus » et la prochaine
    /// réunion ; sinon ce qui manque (plan, temps) et où le régler.
    @ViewBuilder
    private func idleCard(now: Date) -> some View {
        let proposal = WorkBlockPlan.propose(store: model.store, index: model.index, plan: model.planIDs, meetings: model.meetingsToday, rules: model.rules, now: now)
        let suggestion = proposal.suggestion
        if let absence = model.absence(on: now) {
            PanelCard {
                Eyebrow(text: "Jour de congé")
                Text(absence.title)
                    .doneText(.displayM)
                Text("Done ne propose rien aujourd'hui.")
                    .doneText(.caption)
                    .foregroundStyle(DoneColor.textSecondary)
            }
        } else {
            switch suggestion.status {
            case .ready:
                if let action = suggestion.action, let root = suggestion.planTask {
                    readyCard(action: action, root: root, proposal: proposal, now: now)
                }
            case .planEmpty where model.isPlanFinished:
                PanelCard {
                    HStack(spacing: DoneSpace.s12) {
                        Image(systemName: "sun.max")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(DoneColor.accent)
                        VStack(alignment: .leading, spacing: DoneSpace.s2) {
                            Text("Plan du jour terminé")
                                .doneText(.displayM)
                            Text("Tout ce qui était prévu est fait.")
                                .doneText(.caption)
                                .foregroundStyle(DoneColor.textSecondary)
                        }
                    }
                    Button("Ajouter une tâche au plan", action: openPlan)
                        .buttonStyle(DoneButtonStyle(fullWidth: true))
                }
            case .planEmpty:
                PanelCard {
                    Eyebrow(text: "Prochaine action")
                    message("Pas encore de plan", "Choisis les tâches du jour dans Done.")
                    Button("Choisir le plan", action: openPlan)
                        .buttonStyle(DoneButtonStyle(kind: .primary, fullWidth: true))
                }
            case .allBlocked:
                PanelCard {
                    Eyebrow(text: "Prochaine action")
                    message("Tout le plan attend", "Les tâches du plan sont bloquées ou prévues plus tard.")
                    Button("Ouvrir le plan", action: openPlan)
                        .buttonStyle(DoneButtonStyle(fullWidth: true))
                }
            case .noTimeBeforeMeeting:
                PanelCard {
                    Eyebrow(text: "Prochaine action")
                    message(
                        "Pas le temps avant la réunion",
                        suggestion.minutesBeforeMeeting.map { "\(Format.minutes(Double($0))) d'ici là : trop court pour un pomodoro." }
                            ?? "Trop court pour un pomodoro."
                    )
                    meetingLine(now: now)
                }
            }
        }
    }

    private func readyCard(action: TodoTask, root: TodoTask, proposal: WorkBlockPlan.Proposal, now: Date) -> some View {
        let suggestion = proposal.suggestion
        let pause = engine.needsBreak(before: root, now: now) ? engine.breakDue?.remainingMinutes(now: now) : nil
        return PanelCard {
            HStack(spacing: DoneSpace.s8) {
                if let blockEnd = proposal.blockEnd {
                    Eyebrow(text: "Bloc de travail")
                    PanelChip(text: "jusqu'à \(Format.time(blockEnd))", tone: .info)
                } else {
                    Eyebrow(text: "Prochaine action")
                    PanelChip(text: suggestion.position > 0 ? "Tâche \(suggestion.position) sur \(suggestion.planCount)" : "Hors plan", tone: .accent)
                }
            }
            VStack(alignment: .leading, spacing: DoneSpace.s2) {
                Text(action.title)
                    .doneText(.displayM)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                Text(model.actionContext(action, root: root))
                    .doneText(.caption)
                    .foregroundStyle(DoneColor.textSecondary)
                    .lineLimit(1)
            }
            HStack(spacing: DoneSpace.s12) {
                InfoChip(symbol: "clock", text: Format.minutes(Double(suggestion.minutes)))
                PriorityChip(priority: action.priority)
            }
            if let pause {
                Text("Tu changes de tâche : \(pause) min de pause d'abord.")
                    .doneText(.caption)
                    .foregroundStyle(DoneColor.stateActiveText)
                Button("Démarrer la pause · \(pause) min") { engine.start(suggestion, now: .now) }
                    .buttonStyle(DoneButtonStyle(kind: .primary, fullWidth: true))
            } else {
                // La session démarre ici ; Done reste en arrière-plan.
                Button("Lancer le focus") { engine.start(suggestion, now: .now) }
                    .buttonStyle(DoneButtonStyle(kind: .primary, fullWidth: true))
            }
            meetingLine(now: now)
        }
    }

    /// La réunion en cours, ou la prochaine si elle commence dans l'heure.
    @ViewBuilder
    private func meetingLine(now: Date) -> some View {
        let meetings = model.meetingsToday
        if let ongoing = meetings.first(where: { $0.contains(now) }) {
            meetingRow("« \(ongoing.title) » jusqu'à \(Format.time(ongoing.end))")
        } else if let next = meetings.first(where: { $0.start > now && $0.start.timeIntervalSince(now) <= 3600 }) {
            meetingRow("« \(next.title) » à \(Format.time(next.start)), dans \(Format.minutes(next.start.timeIntervalSince(now) / 60))")
        }
    }

    private func meetingRow(_ text: String) -> some View {
        HStack(spacing: DoneSpace.s8) {
            Hatching()
                .frame(width: 12, height: 12)
                .background(DoneColor.meetingBg, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).strokeBorder(DoneColor.borderDefault, lineWidth: 1))
            Text(text)
                .doneText(.caption)
                .foregroundStyle(DoneColor.textSecondary)
                .lineLimit(1)
        }
    }

    /// En session : le minuteur de l'écran de session en petit, Pause (ou Reprendre) et C'est fait.
    @ViewBuilder
    private var sessionCard: some View {
        if let current = engine.current {
            let focusing = engine.phase == .focusing
            PanelCard {
                Eyebrow(text: focusing ? sessionContext(current) : statusCaption)
                Text(current.action.title)
                    .font(.sans(14, .semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                FocusTimer(
                    remaining: engine.remaining,
                    total: current.planned,
                    tone: focusing ? .focus : .paused,
                    caption: focusing ? "sur \(Int((current.planned / 60).rounded())) min" : "En pause",
                    metrics: .panel
                )
                HStack(spacing: DoneSpace.s8) {
                    if focusing {
                        Button("Pause") { engine.pause() }
                            .buttonStyle(DoneButtonStyle(fullWidth: true))
                    } else {
                        Button("Reprendre") { engine.resume() }
                            .buttonStyle(DoneButtonStyle(kind: .primary, fullWidth: true))
                    }
                    // Fini avant la sonnerie : la suite se choisit dans Done.
                    Button("C'est fait") {
                        engine.finishEarly()
                        engine.markDone()
                    }
                    .buttonStyle(DoneButtonStyle(fullWidth: true))
                }
            }
        }
    }

    private func sessionContext(_ current: FocusEngine.Current) -> String {
        guard current.action.id != current.root.id else { return current.projectName }
        return "\(current.projectName) · \(current.root.title)"
    }

    private var statusCaption: String {
        if case .interrupted(let reason) = engine.phase {
            return "Interrompu · \(reason.label)"
        }
        return "En pause"
    }

    /// Pause : fond cobalt pâle, le minuteur en cobalt, ce qui vient ensuite, et « Passer la pause »
    /// quand elle n'est pas obligatoire.
    private func breakCard(now: Date) -> some View {
        PanelCard(fill: DoneColor.pomodoroBreakBg) {
            Eyebrow(text: engine.breakIsMandatory ? "Pause avant la tâche suivante" : "Pause")
            FocusTimer(
                remaining: engine.breakRemaining,
                total: engine.breakDuration,
                tone: .onBreak,
                caption: "de pause, sur \(Int((engine.breakDuration / 60).rounded())) min",
                metrics: .panel
            )
            if let next = nextUp(now: now) {
                Text("Ensuite : \(next)")
                    .doneText(.caption)
                    .foregroundStyle(DoneColor.textSecondary)
                    .lineLimit(2)
            }
            if !engine.breakIsMandatory {
                Button("Passer la pause") { engine.skipBreak() }
                    .buttonStyle(DoneButtonStyle(fullWidth: true))
            }
        }
    }

    private func nextUp(now: Date) -> String? {
        let suggestion = WorkBlockPlan.propose(store: model.store, index: model.index, plan: model.planIDs, meetings: model.meetingsToday, rules: model.rules, now: now).suggestion
        guard suggestion.status == .ready, let action = suggestion.action else { return nil }
        guard let root = suggestion.planTask, root.id != action.id else { return "« \(action.title) »" }
        return "« \(action.title) » · \(root.title)"
    }

    /// Fin de pomodoro : cocher, encore 5 min ou la pause, ici ; « Bloqué… » et « Arrêter là » restent
    /// dans Done. Une étape cochée avant la fin renvoie à Done pour la suite.
    @ViewBuilder
    private func outcomeCard(now: Date) -> some View {
        if let current = engine.current {
            PanelCard {
                if let checked = engine.checkedAction {
                    outcomeHeader("Étape cochée", "« \(checked.title) » est cochée.")
                    Button("Ouvrir Done pour la suite", action: openDone)
                        .buttonStyle(DoneButtonStyle(kind: .primary, fullWidth: true))
                } else {
                    let pomodoros = Stats.pomodoros(sessions.map(\.fact), on: now)
                    outcomeHeader("Pomodoro terminé", "\(Format.minutes(engine.stepElapsed / 60)) · \(current.action.title)")
                    if pomodoros > 0 {
                        PomodoroSeries(count: pomodoros)
                    }
                    Button("Cocher la tâche") { engine.markDone() }
                        .buttonStyle(DoneButtonStyle(kind: .primary, fullWidth: true))
                    HStack(spacing: DoneSpace.s8) {
                        if engine.canExtend {
                            Button("Encore \(Rules.extensionStepMinutes) min") { engine.extend() }
                                .buttonStyle(DoneButtonStyle(fullWidth: true))
                        }
                        Button("Pause") { engine.takeBreakAfterSession() }
                            .buttonStyle(DoneButtonStyle(fullWidth: true))
                    }
                }
            }
        }
    }

    /// L'anneau refermé de 40, avec la coche, puis le titre et sa ligne.
    private func outcomeHeader(_ title: String, _ subtitle: String) -> some View {
        HStack(spacing: DoneSpace.s12) {
            ZStack {
                ProgressRing(fraction: 1, color: DoneColor.pomodoroFocus, lineWidth: 4)
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DoneColor.textPrimary)
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: DoneSpace.s2) {
                Text(title)
                    .doneText(.displayM)
                Text(subtitle)
                    .doneText(.caption)
                    .foregroundStyle(DoneColor.textSecondary)
                    .lineLimit(2)
            }
        }
    }

    private func message(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: DoneSpace.s2) {
            Text(title)
                .doneText(.displayM)
            Text(detail)
                .doneText(.caption)
                .foregroundStyle(DoneColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Aujourd'hui et pied

    /// Pomodoros du jour, focus du jour et avancée du plan ; la barre passe en braise une fois le plan bouclé.
    private func today(now: Date) -> some View {
        let pomodoros = Stats.pomodoros(sessions.map(\.fact), on: now)
        let focus = DayTimeline.focusMinutes(on: now, in: sessions)
        let done = (model.todayPlan?.doneIDs ?? []).compactMap { model.store[$0] }.filter { !$0.isOpen }.count
        let open = model.planIDs.compactMap { model.store[$0] }.filter(\.isOpen).count
        let total = done + open
        return VStack(alignment: .leading, spacing: DoneSpace.s8) {
            HStack(spacing: DoneSpace.s8) {
                Eyebrow(text: "Aujourd'hui")
                Spacer(minLength: DoneSpace.s4)
                if pomodoros > 0 {
                    HStack(spacing: 3) {
                        ForEach(0..<min(pomodoros, 5), id: \.self) { _ in
                            Circle()
                                .fill(DoneColor.accent)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(plural(pomodoros, "pomodoro"))
                }
                Text("\(focus > 0 ? Format.minutes(focus) : "0 min") de focus")
                Text(total == 0 ? "Pas de plan" : "Plan \(done) sur \(total)")
            }
            .font(.sans(12, .semibold).monospacedDigit())
            .foregroundStyle(DoneColor.textSecondary)
            .lineLimit(1)
            ProgressBar(
                fraction: total == 0 ? 0 : Double(done) / Double(total),
                color: total > 0 && done == total ? DoneColor.accent : DoneColor.actionPrimary
            )
        }
        .padding(.horizontal, DoneSpace.s2)
    }

    private var footer: some View {
        HStack {
            Button(action: openDone) {
                HStack(spacing: DoneSpace.s6) {
                    Text("Ouvrir Done")
                    Text("⌘O")
                        .foregroundStyle(DoneColor.textDisabled)
                }
            }
            .buttonStyle(DoneButtonStyle(kind: .plain, compact: true))
            .keyboardShortcut("o")
            Spacer()
            Button { SystemBridge.quit() } label: {
                HStack(spacing: DoneSpace.s6) {
                    Text("Quitter")
                    Text("⌘Q")
                        .foregroundStyle(DoneColor.textDisabled)
                }
            }
            .buttonStyle(DoneButtonStyle(kind: .plain, compact: true))
            .keyboardShortcut("q")
        }
        .padding(.horizontal, DoneSpace.s8)
        .padding(.vertical, DoneSpace.s6)
    }

    // MARK: Ouvrir Done

    private func openDone() {
        openWindow(id: "main")
        SystemBridge.bringToFront()
    }

    /// Ouvre Done sur Ma journée, avec le Plan du jour.
    private func openPlan() {
        model.requestPlan()
        openDone()
    }
}

/// Carte du panneau : comme une carte widget, en plus serré (rayon md, marges 16 × 14).
private struct PanelCard<Content: View>: View {
    var fill: Color = DoneColor.surfaceDefault
    @ViewBuilder let content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DoneRadius.md, style: .continuous)
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(.horizontal, DoneSpace.s16)
        .padding(.top, 14)
        .padding(.bottom, DoneSpace.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fill, in: shape)
        .overlay(shape.strokeBorder(DoneColor.borderSubtle, lineWidth: 1))
        .shadow(color: DoneColor.shadowCard, radius: 15, y: 10)
        .shadow(color: DoneColor.shadowCardNear, radius: 1, y: 1)
    }
}

/// Puce de 22 à côté de l'en-tête : la position dans le plan (braise) ou la fin du bloc (cobalt).
private struct PanelChip: View {
    enum Tone {
        case accent, info
    }

    let text: String
    let tone: Tone

    var body: some View {
        HStack(spacing: 5) {
            if tone == .accent {
                Circle()
                    .fill(DoneColor.accent)
                    .frame(width: 5, height: 5)
            }
            Text(text)
        }
        .font(.sans(12, .semibold))
        .foregroundStyle(tone == .accent ? DoneColor.accentText : DoneColor.stateActiveText)
        .padding(.horizontal, DoneSpace.s8)
        .frame(height: 22)
        .background(tone == .accent ? DoneColor.accentTint : DoneColor.stateActiveTint, in: Capsule(style: .continuous))
        .fixedSize()
    }
}

/// La série du jour : une pastille braise par pomodoro (8 au plus), une vide pour le prochain, et le rang.
private struct PomodoroSeries: View {
    let count: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<min(count, 8), id: \.self) { _ in
                Circle()
                    .fill(DoneColor.accent)
                    .frame(width: 8, height: 8)
            }
            if count < 8 {
                Circle()
                    .strokeBorder(DoneColor.borderDefault, lineWidth: 1.5)
                    .frame(width: 8, height: 8)
            }
            Text("\(Format.ordinal(count)) pomodoro aujourd'hui")
                .font(.sans(12, .semibold))
                .foregroundStyle(DoneColor.accentText)
                .padding(.leading, DoneSpace.s4)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Bouton d'envoi de la capture : rond de 28, actionPrimary.
private struct SendButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? DoneColor.actionOnPrimary : DoneColor.textDisabled)
            .frame(width: 28, height: 28)
            .background(
                isEnabled ? (configuration.isPressed ? DoneColor.actionPrimaryPressed : DoneColor.actionPrimary) : DoneColor.actionDisabled,
                in: Circle()
            )
            .contentShape(Circle())
            .donePress(configuration.isPressed, scale: 0.94)
    }
}

/// Fond du panneau : la toile, avec les deux halos de la fenêtre en plus petit et plus discrets.
private struct PanelCanvas: View {
    var body: some View {
        ZStack {
            DoneColor.bgCanvas
            RadialGradient(
                colors: [DoneColor.haloWarm.opacity(0.75), DoneColor.haloWarm.opacity(0)],
                center: UnitPoint(x: 1.03, y: -0.04),
                startRadius: 0,
                endRadius: 130
            )
            RadialGradient(
                colors: [DoneColor.haloPink.opacity(0.7), DoneColor.haloPink.opacity(0)],
                center: UnitPoint(x: -0.03, y: 1.06),
                startRadius: 0,
                endRadius: 140
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
