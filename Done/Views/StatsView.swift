import SwiftData
import SwiftUI

struct StatsView: View {
    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                FocusStatsView(width: max(proxy.size.width - 2 * DoneSpace.s40, 0))
                    .padding(.horizontal, DoneSpace.s40)
                    .padding(.top, DoneSpace.s4)
                    .padding(.bottom, DoneSpace.s24)
            }
            .scrollIndicators(.never)
        }
        .environment(\.locale, Locale(identifier: "fr_FR"))
    }
}

// MARK: Focus

/// Les stats d'une semaine en six cartes widget, comme Ma journée : le focus de la semaine, les
/// pomodoros et la série, le focus par jour, tes meilleures heures (sur quatre semaines), le focus
/// par projet et les interruptions.
struct FocusStatsView: View {
    let width: CGFloat
    @Environment(AppModel.self) private var model
    @Query(sort: \FocusSession.startedAt) private var sessions: [FocusSession]
    @Query(sort: \DayPlan.day) private var plans: [DayPlan]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var weekOffset = 0
    /// Faux le temps de faire pousser les barres : à l'arrivée sur l'écran et à chaque semaine.
    @State private var grown = false

    private static let spacing: CGFloat = 16

    var body: some View {
        let now = Date.now
        let reference = Stats.calendar.date(byAdding: .weekOfYear, value: weekOffset, to: now) ?? now
        let week = Stats.week(containing: reference)
        let numbers = WeekNumbers(week: week, isCurrent: weekOffset == 0, now: now, sessions: sessions.map(\.fact), plans: plans) { model.absence(on: $0) != nil }

        VStack(alignment: .leading, spacing: DoneSpace.s24) {
            PeriodHeader(title: weekTitle, subtitle: Format.weekRange(week), canGoForward: weekOffset < 0) { weekOffset += $0 }
            grid(numbers)
        }
        // Les barres poussent à l'arrivée et quand on change de semaine : deux gestes de la personne.
        .task(id: weekOffset) {
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) { grown = false }
            try? await Task.sleep(for: .milliseconds(30))
            withAnimation(DoneMotion.motion(DoneMotion.arrive, reduced: reduceMotion)) { grown = true }
        }
    }

    private var weekTitle: String {
        switch weekOffset {
        case 0: "Cette semaine"
        case -1: "La semaine dernière"
        default: "Il y a \(-weekOffset) semaines"
        }
    }

    // MARK: Grille

    /// Trois colonnes (1 / 1,25 / 1) sur deux rangées, les graphiques dans la colonne large ; sous
    /// 1 150 de large, deux colonnes. Les cartes d'une rangée prennent la hauteur de la plus haute.
    @ViewBuilder
    private func grid(_ numbers: WeekNumbers) -> some View {
        let spacing = Self.spacing
        if width >= 1150 {
            let unit = (width - 2 * spacing) / 3.25
            VStack(spacing: spacing) {
                HStack(alignment: .top, spacing: spacing) {
                    totalCard(numbers).frame(width: unit)
                    dailyCard(numbers).frame(width: unit * 1.25)
                    pomodoroCard(numbers).frame(width: unit)
                }
                .fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .top, spacing: spacing) {
                    projectsCard(numbers).frame(width: unit)
                    hoursCard(numbers).frame(width: unit * 1.25)
                    interruptionsCard(numbers).frame(width: unit)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            let column = (width - spacing) / 2
            VStack(spacing: spacing) {
                HStack(alignment: .top, spacing: spacing) {
                    totalCard(numbers).frame(width: column)
                    pomodoroCard(numbers).frame(width: column)
                }
                .fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .top, spacing: spacing) {
                    dailyCard(numbers).frame(width: column)
                    hoursCard(numbers).frame(width: column)
                }
                .fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .top, spacing: spacing) {
                    projectsCard(numbers).frame(width: column)
                    interruptionsCard(numbers).frame(width: column)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Cartes

    /// Le total en grand, l'écart avec la semaine d'avant, puis sessions, tâches cochées et plans bouclés.
    private func totalCard(_ numbers: WeekNumbers) -> some View {
        WidgetCard(title: "Focus de la semaine") {
            VStack(alignment: .leading, spacing: DoneSpace.s12) {
                TimerText(text: numbers.total > 0 ? Format.minutes(numbers.total) : "0 min", color: DoneColor.stateActiveText)
                Text(numbers.comparison)
                    .doneText(.callout)
                    .foregroundStyle(DoneColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: DoneSpace.s8)
                VStack(spacing: DoneSpace.s8) {
                    StatLine(title: "Sessions", value: "\(numbers.facts.count)")
                    Hairline()
                    StatLine(title: "Tâches cochées", value: "\(numbers.checked)")
                    Hairline()
                    StatLine(title: "Plans bouclés", value: "\(numbers.finished.count)", highlighted: !numbers.finished.isEmpty)
                }
            }
        }
    }

    private func dailyCard(_ numbers: WeekNumbers) -> some View {
        WidgetCard(title: "Par jour") {
            DailyBars(days: numbers.days, best: Stats.bestDay(numbers.days), finished: numbers.finished, grown: grown)
        }
    }

    /// Les pomodoros de la semaine, la série (jours d'affilée avec au moins un pomodoro), le meilleur
    /// jour et la moyenne par jour travaillé.
    private func pomodoroCard(_ numbers: WeekNumbers) -> some View {
        WidgetCard(title: "Pomodoros et série") {
            VStack(alignment: .leading, spacing: DoneSpace.s12) {
                HStack(alignment: .firstTextBaseline, spacing: DoneSpace.s8) {
                    Text("\(numbers.pomodoros)")
                        .doneText(.numericL)
                        .foregroundStyle(DoneColor.textPrimary)
                    Text(numbers.pomodoros > 1 ? "pomodoros" : "pomodoro")
                        .doneText(.callout)
                        .foregroundStyle(DoneColor.textSecondary)
                }
                StreakDots(days: numbers.days, now: numbers.now)
                Spacer(minLength: DoneSpace.s8)
                VStack(spacing: DoneSpace.s8) {
                    StatLine(
                        title: numbers.isCurrent ? "Série en cours" : "Série en fin de semaine",
                        value: numbers.streak == 0 ? "Aucune" : plural(numbers.streak, "jour"),
                        highlighted: numbers.streak > 0
                    )
                    Hairline()
                    StatLine(title: "Meilleur jour", value: numbers.bestPomodoroDay.map { "\(Format.weekdayShort($0.day)) · \($0.pomodoros)" } ?? "Aucun")
                    Hairline()
                    StatLine(title: "Par jour travaillé", value: numbers.pomodorosPerDay)
                }
            }
        }
    }

    private func projectsCard(_ numbers: WeekNumbers) -> some View {
        WidgetCard(title: "Par projet") {
            if numbers.projects.isEmpty {
                EmptyLine(text: "Pas encore de session cette semaine.")
            } else {
                let longest = numbers.projects.map(\.minutes).max() ?? 1
                VStack(spacing: DoneSpace.s16) {
                    ForEach(numbers.projects) { project in
                        MeterRow(label: project.name, value: Format.minutes(project.minutes), fraction: project.minutes / max(longest, 1), grown: grown)
                    }
                }
            }
        }
    }

    /// Le focus par heure de la journée, sur les quatre semaines qui finissent avec celle-ci, et les
    /// deux heures d'affilée les plus concentrées.
    private func hoursCard(_ numbers: WeekNumbers) -> some View {
        WidgetCard(title: "Tes meilleures heures") {
            VStack(alignment: .leading, spacing: DoneSpace.s12) {
                VStack(alignment: .leading, spacing: DoneSpace.s2) {
                    Text(numbers.bestHours.map { "Tu te concentres le mieux de \($0.lowerBound) h à \($0.upperBound) h." } ?? "Pas encore assez de sessions pour le dire.")
                        .doneText(.callout)
                        .foregroundStyle(DoneColor.textPrimary)
                    Text(numbers.isCurrent ? "Sur les quatre dernières semaines." : "Sur les quatre semaines jusqu'au \(Format.dayAndMonth(numbers.week.end.addingTimeInterval(-1))).")
                        .doneText(.caption)
                        .foregroundStyle(DoneColor.textSecondary)
                }
                Spacer(minLength: DoneSpace.s8)
                HourBars(minutes: numbers.hours, best: numbers.bestHours, grown: grown)
            }
        }
    }

    /// Le nombre d'interruptions, la part des sessions sans interruption, puis une jauge par raison.
    private func interruptionsCard(_ numbers: WeekNumbers) -> some View {
        WidgetCard(title: "Interruptions") {
            VStack(alignment: .leading, spacing: DoneSpace.s12) {
                HStack(alignment: .firstTextBaseline, spacing: DoneSpace.s8) {
                    Text("\(numbers.interruptions)")
                        .doneText(.numericL)
                        .foregroundStyle(DoneColor.textPrimary)
                    Text(numbers.interruptions > 1 ? "interruptions" : "interruption")
                        .doneText(.callout)
                        .foregroundStyle(DoneColor.textSecondary)
                }
                if numbers.facts.isEmpty {
                    EmptyLine(text: "Pas encore de session cette semaine.")
                } else {
                    Text("\(numbers.calmSessions) \(numbers.calmSessions > 1 ? "sessions" : "session") sur \(numbers.facts.count) sans interruption.")
                        .doneText(.callout)
                        .foregroundStyle(DoneColor.textSecondary)
                    let reasons = numbers.reasons.filter { $0.count > 0 }
                    if !reasons.isEmpty {
                        let most = Double(reasons.map(\.count).max() ?? 1)
                        Spacer(minLength: DoneSpace.s8)
                        VStack(spacing: DoneSpace.s16) {
                            ForEach(reasons) { reason in
                                MeterRow(label: reason.reason.label, value: "\(reason.count)", fraction: Double(reason.count) / most, grown: grown)
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Les chiffres d'une semaine, calculés une fois pour les six cartes.
private struct WeekNumbers {
    let week: DateInterval
    let isCurrent: Bool
    let now: Date
    let facts: [SessionFact]
    let days: [Stats.DayFocus]
    let total: Double
    /// La semaine d'avant : en entier pour une semaine passée, jusqu'au même moment pour la semaine en cours.
    let previousTotal: Double
    let checked: Int
    /// Jours où le plan a été bouclé : tout ce qui était prévu a été coché.
    let finished: Set<Date>
    let pomodoros: Int
    let streak: Int
    let projects: [Stats.ProjectFocus]
    let reasons: [Stats.ReasonCount]
    let interruptions: Int
    let calmSessions: Int
    /// Minutes par heure, sur les quatre semaines qui finissent avec celle-ci.
    let hours: [Double]
    let bestHours: Range<Int>?

    init(week: DateInterval, isCurrent: Bool, now: Date, sessions all: [SessionFact], plans: [DayPlan], isDayOff: (Date) -> Bool) {
        let calendar = Stats.calendar
        self.week = week
        self.isCurrent = isCurrent
        self.now = now
        facts = all.filter { week.contains($0.startedAt) }
        days = Stats.byDay(facts, in: week)
        total = Stats.totalMinutes(facts)
        let previousStart = calendar.date(byAdding: .weekOfYear, value: -1, to: week.start) ?? week.start
        let previousEnd = isCurrent ? (calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? week.start) : week.start
        previousTotal = Stats.totalMinutes(all.filter { $0.startedAt >= previousStart && $0.startedAt < previousEnd })
        checked = facts.filter { $0.outcome == .done }.count
        finished = Set(plans
            .filter { week.contains($0.day) && DayAgenda.isPlanFinished(plan: $0.taskIDs, done: $0.doneIDs) { _ in true } }
            .map { calendar.startOfDay(for: $0.day) })
        pomodoros = days.reduce(0) { $0 + $1.pomodoros }
        streak = Stats.streak(all, through: isCurrent ? now : week.end.addingTimeInterval(-1), isDayOff: isDayOff)
        projects = Self.grouped(Stats.byProject(facts))
        reasons = Stats.interruptions(facts)
        interruptions = reasons.reduce(0) { $0 + $1.count }
        calmSessions = facts.filter(\.interruptions.isEmpty).count
        let fourWeeks = DateInterval(start: calendar.date(byAdding: .weekOfYear, value: -3, to: week.start) ?? week.start, end: week.end)
        hours = Stats.byHour(all.filter { fourWeeks.contains($0.startedAt) })
        bestHours = Stats.bestHours(hours)
    }

    /// Six projets au plus ; au-delà, le reste dans « Autres projets ».
    private static func grouped(_ projects: [Stats.ProjectFocus]) -> [Stats.ProjectFocus] {
        guard projects.count > 6 else { return projects }
        let rest = projects.dropFirst(5).reduce(0) { $0 + $1.minutes }
        return Array(projects.prefix(5)) + [Stats.ProjectFocus(name: "Autres projets", minutes: rest)]
    }

    var comparison: String {
        Stats.comparison(total: total, previous: previousTotal, isCurrent: isCurrent)
    }

    /// Le jour aux plus de pomodoros. Aucun sans pomodoro ; le premier en cas d'égalité.
    var bestPomodoroDay: Stats.DayFocus? {
        guard let most = days.map(\.pomodoros).max(), most > 0 else { return nil }
        return days.first { $0.pomodoros == most }
    }

    var pomodorosPerDay: String {
        Stats.perWorkedDay(days)
    }
}

/// Une ligne de chiffre : libellé à gauche, valeur à droite, en braise quand elle mérite d'être vue.
private struct StatLine: View {
    let title: String
    let value: String
    var highlighted = false

    var body: some View {
        HStack {
            Text(title)
                .doneText(.callout)
                .foregroundStyle(DoneColor.textSecondary)
            Spacer()
            Text(value)
                .doneText(.numericM)
                .foregroundStyle(highlighted ? DoneColor.accentText : DoneColor.textPrimary)
        }
    }
}

private struct EmptyLine: View {
    let text: String

    var body: some View {
        Text(text)
            .doneText(.callout)
            .foregroundStyle(DoneColor.textSecondary)
    }
}

/// La série de la semaine : une pastille par jour ouvré (et par jour de week-end travaillé), pleine
/// en braise quand le jour a eu au moins un pomodoro, vide sinon ; les jours à venir en pointillé.
private struct StreakDots: View {
    let days: [Stats.DayFocus]
    let now: Date

    var body: some View {
        let calendar = Stats.calendar
        let shown = days.filter { !calendar.isDateInWeekend($0.day) || $0.pomodoros > 0 }
        HStack(spacing: DoneSpace.s8) {
            ForEach(shown) { day in
                let future = day.day > now
                VStack(spacing: DoneSpace.s4) {
                    Group {
                        if day.pomodoros > 0 {
                            Circle().fill(DoneColor.accent)
                        } else {
                            Circle().strokeBorder(DoneColor.borderDefault, style: StrokeStyle(lineWidth: 1.5, dash: future ? [2, 2] : []))
                        }
                    }
                    .frame(width: 10, height: 10)
                    Text(Format.weekdayInitial(day.day))
                        .doneText(.caption)
                        .foregroundStyle(calendar.isDate(day.day, inSameDayAs: now) ? DoneColor.textPrimary : DoneColor.textSecondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(shown.filter { $0.pomodoros > 0 }.count) jours avec au moins un pomodoro")
    }
}

/// Focus par heure de la journée : une barre par heure, de 8 h à 19 h au moins (élargi aux heures
/// travaillées), les meilleures heures en plein, les autres en teinte ; l'heure sous une barre sur deux.
private struct HourBars: View {
    let minutes: [Double]
    let best: Range<Int>?
    let grown: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let barHeight: CGFloat = 120

    var body: some View {
        let worked = minutes.indices.filter { minutes[$0] > 0 }
        let first = min(worked.first ?? 8, 8)
        let last = max((worked.last ?? 18) + 1, 19)
        let hours = Array(first..<last)
        let most = max(minutes.max() ?? 0, 1)
        HStack(alignment: .bottom, spacing: DoneSpace.s4) {
            ForEach(Array(hours.enumerated()), id: \.element) { index, hour in
                let isBest = best?.contains(hour) ?? false
                VStack(spacing: DoneSpace.s6) {
                    if minutes[hour] > 0 {
                        RoundedRectangle(cornerRadius: DoneRadius.xs, style: .continuous)
                            .fill(isBest ? DoneColor.stateActive : DoneColor.stateActiveTint)
                            .frame(height: grown || reduceMotion ? max(6, Self.barHeight * minutes[hour] / most) : 0)
                            .opacity(grown || !reduceMotion ? 1 : 0)
                    } else {
                        RoundedRectangle(cornerRadius: DoneRadius.xs, style: .continuous)
                            .fill(DoneColor.pomodoroTrack)
                            .frame(height: 4)
                    }
                    Text(hour.isMultiple(of: 2) ? "\(hour) h" : " ")
                        .doneText(.caption)
                        .foregroundStyle(isBest ? DoneColor.textPrimary : DoneColor.textSecondary)
                        .lineLimit(1)
                        .fixedSize()
                }
                .frame(maxWidth: .infinity)
                .help("\(hour) h : \(Format.minutes(minutes[hour]))")
                .animation(DoneMotion.motion(DoneMotion.arrive, reduced: reduceMotion).delay(reduceMotion ? 0 : Double(index) * 0.03), value: grown)
            }
        }
        .frame(height: Self.barHeight + 24, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(best.map { "Meilleures heures : de \($0.lowerBound) h à \($0.upperBound) h" } ?? "Pas encore de focus")
    }
}

/// Barres de minutes par jour, du lundi au dimanche. Sous chaque jour, la série de ses pomodoros
/// (une pastille braise chacun, 5 au plus et le reste en nombre) ; un soleil sur la meilleure journée,
/// un petit soleil à côté du jour quand le plan du jour a été bouclé. Les barres poussent l'une après
/// l'autre ; avec « Réduire les animations », elles arrivent en fondu.
private struct DailyBars: View {
    let days: [Stats.DayFocus]
    let best: Date?
    let finished: Set<Date>
    let grown: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let longest = max(days.map(\.minutes).max() ?? 0, 60)
        let barHeight: CGFloat = 140
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                let isToday = Calendar.current.isDateInToday(day.day)
                let isBest = best.map { Stats.calendar.isDate($0, inSameDayAs: day.day) } ?? false
                VStack(spacing: DoneSpace.s8) {
                    Image(systemName: "sun.max")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DoneColor.accent)
                        .scaleEffect(isBest && grown || reduceMotion ? 1 : 0.6)
                        .opacity(isBest && grown ? 1 : 0)
                        .animation(DoneMotion.motion(DoneMotion.pop, reduced: reduceMotion).delay(reduceMotion ? 0 : DoneMotion.slow), value: grown)
                        .help("Meilleure journée de la semaine")
                        .accessibilityHidden(!isBest)
                    if day.minutes > 0 {
                        Text(Format.minutes(day.minutes))
                            .doneText(.caption)
                            .foregroundStyle(DoneColor.textSecondary)
                            .lineLimit(1)
                            .fixedSize()
                            .opacity(grown ? 1 : 0)
                        RoundedRectangle(cornerRadius: DoneRadius.xs, style: .continuous)
                            .fill(DoneColor.stateActive)
                            .frame(width: 32, height: grown || reduceMotion ? max(8, barHeight * day.minutes / longest) : 0)
                            .opacity(grown || !reduceMotion ? 1 : 0)
                    } else {
                        RoundedRectangle(cornerRadius: DoneRadius.xs, style: .continuous)
                            .fill(DoneColor.pomodoroTrack)
                            .frame(width: 32, height: 6)
                    }
                    HStack(spacing: DoneSpace.s2) {
                        Text(Format.weekdayShort(day.day))
                            .font(isToday ? .sans(12, .semibold) : .done(.caption))
                            .foregroundStyle(isToday ? DoneColor.textPrimary : DoneColor.textSecondary)
                        if finished.contains(Stats.calendar.startOfDay(for: day.day)) {
                            Image(systemName: "sun.max")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(DoneColor.accent)
                                .help("Plan du jour bouclé")
                        }
                    }
                    PomodoroDots(count: day.pomodoros)
                        .opacity(grown ? 1 : 0)
                }
                .frame(maxWidth: .infinity)
                .animation(DoneMotion.motion(DoneMotion.arrive, reduced: reduceMotion).delay(reduceMotion ? 0 : Double(index) * 0.04), value: grown)
            }
        }
        .frame(height: 230, alignment: .bottom)
    }
}

/// Pomodoros d'une journée : une pastille braise de 6 par pomodoro, 5 au plus, puis le reste en nombre.
private struct PomodoroDots: View {
    let count: Int

    var body: some View {
        HStack(spacing: DoneSpace.s2) {
            ForEach(0..<min(count, 5), id: \.self) { _ in
                Circle()
                    .fill(DoneColor.accent)
                    .frame(width: 6, height: 6)
            }
            if count > 5 {
                Text("+\(count - 5)")
                    .font(.done(.numericS))
                    .foregroundStyle(DoneColor.accentText)
            }
        }
        .frame(height: 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(plural(count, "pomodoro"))
    }
}

// MARK: Composants des stats

/// Titre de période, sous-titre et flèches.
private struct PeriodHeader: View {
    let title: String
    let subtitle: String
    let canGoForward: Bool
    let move: (Int) -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: DoneSpace.s8) {
            VStack(alignment: .leading, spacing: DoneSpace.s4) {
                Text(title)
                    .doneText(.displayL)
                    .foregroundStyle(DoneColor.textPrimary)
                Text(subtitle)
                    .doneText(.body)
                    .foregroundStyle(DoneColor.textSecondary)
            }
            Spacer()
            Button { move(-1) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(DoneIconButtonStyle())
                .help("Période précédente")
            Button { move(1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(DoneIconButtonStyle())
                .disabled(!canGoForward)
                .opacity(canGoForward ? 1 : 0.4)
                .help("Période suivante")
        }
    }
}

/// Une ligne de jauge : libellé, valeur et barre proportionnelle, qui pousse avec les barres du jour.
private struct MeterRow: View {
    let label: String
    let value: String
    let fraction: Double
    var grown = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: DoneSpace.s8) {
            HStack {
                Text(label)
                    .foregroundStyle(DoneColor.textPrimary)
                    .lineLimit(1)
                Spacer()
                Text(value)
                    .foregroundStyle(DoneColor.textSecondary)
            }
            .doneText(.body)
            ProgressBar(fraction: grown || reduceMotion ? fraction : 0, height: 8)
                .opacity(grown || !reduceMotion ? 1 : 0)
        }
        .animation(DoneMotion.motion(DoneMotion.arrive, reduced: reduceMotion), value: grown)
    }
}

/// Résumé d'une journée, partagé avec le bilan du soir.
struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: DoneSpace.s6) {
            Eyebrow(text: title)
            Text(value)
                .doneText(.numericL)
                .foregroundStyle(DoneColor.textPrimary)
        }
        .padding(DoneSpace.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .doneCard(radius: DoneRadius.lg)
    }
}

/// « 1 réunion », « 3 réunions ».
func plural(_ count: Int, _ singular: String, _ pluralForm: String? = nil) -> String {
    "\(count) \(count > 1 ? (pluralForm ?? singular + "s") : singular)"
}
