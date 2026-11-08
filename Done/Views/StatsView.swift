import SwiftData
import SwiftUI

struct StatsView: View {
    var body: some View {
        ScrollView {
            FocusStatsView()
                .padding(.horizontal, DoneSpace.s40)
                .padding(.top, DoneSpace.s4)
                .padding(.bottom, DoneSpace.s24)
        }
        .scrollIndicators(.never)
        .environment(\.locale, Locale(identifier: "fr_FR"))
    }
}

// MARK: Focus

struct FocusStatsView: View {
    @Query(sort: \FocusSession.startedAt) private var sessions: [FocusSession]
    @Query(sort: \DayPlan.day) private var plans: [DayPlan]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var weekOffset = 0
    /// Faux le temps de faire pousser les barres : à l'arrivée sur l'écran et à chaque semaine.
    @State private var grown = false

    var body: some View {
        let reference = Stats.calendar.date(byAdding: .weekOfYear, value: weekOffset, to: .now) ?? .now
        let week = Stats.week(containing: reference)
        let facts = sessions.filter { week.contains($0.startedAt) }.map(\.fact)
        let days = Stats.byDay(facts, in: week)
        let projects = Stats.byProject(facts)
        let interruptions = Stats.interruptions(facts).reduce(0) { $0 + $1.count }
        let checked = facts.filter { $0.outcome == .done }.count
        let pomodoros = days.reduce(0) { $0 + $1.pomodoros }
        // Plan bouclé : tout ce qui était prévu ce jour-là a été coché.
        let finished = Set(plans
            .filter { week.contains($0.day) && DayAgenda.isPlanFinished(plan: $0.taskIDs, done: $0.doneIDs) { _ in true } }
            .map { Stats.calendar.startOfDay(for: $0.day) })

        VStack(alignment: .leading, spacing: 0) {
            PeriodHeader(title: weekTitle, subtitle: Format.weekRange(week), canGoForward: weekOffset < 0) { weekOffset += $0 }

            HeroNumber(
                value: Format.minutes(Stats.totalMinutes(facts)),
                caption: "de focus · \(plural(pomodoros, "pomodoro")) · \(plural(checked, "tâche cochée", "tâches cochées")) · \(plural(interruptions, "interruption"))"
            )
            .padding(.top, DoneSpace.s24)

            HStack(alignment: .top, spacing: DoneSpace.s20) {
                StatsCard(
                    title: "Par jour",
                    value: finished.isEmpty ? nil : plural(finished.count, "plan bouclé", "plans bouclés"),
                    valueColor: DoneColor.accentText
                ) {
                    DailyBars(days: days, best: Stats.bestDay(days), finished: finished, grown: grown)
                }
                .frame(minWidth: 360, maxWidth: .infinity)

                StatsCard(title: "Par projet") {
                    if projects.isEmpty {
                        Text("Pas encore de session cette semaine.")
                            .doneText(.callout)
                            .foregroundStyle(DoneColor.textSecondary)
                    } else {
                        let longest = projects.map(\.minutes).max() ?? 1
                        VStack(spacing: DoneSpace.s16) {
                            ForEach(projects) { project in
                                MeterRow(label: project.name, value: Format.minutes(project.minutes), fraction: project.minutes / max(longest, 1), grown: grown)
                            }
                        }
                    }
                }
                .frame(width: 340)
            }
            .padding(.top, DoneSpace.s24)
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
                            .frame(width: 40, height: grown || reduceMotion ? max(8, 210 * day.minutes / longest) : 0)
                            .opacity(grown || !reduceMotion ? 1 : 0)
                    } else {
                        RoundedRectangle(cornerRadius: DoneRadius.xs, style: .continuous)
                            .fill(DoneColor.pomodoroTrack)
                            .frame(width: 40, height: 6)
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
        .frame(height: 300, alignment: .bottom)
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

/// Grand chiffre (numeric.xl), suivi de sa légende.
private struct HeroNumber: View {
    let value: String
    let caption: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DoneSpace.s12) {
            TimerText(text: value, color: DoneColor.stateActiveText)
            Text(caption)
                .doneText(.body)
                .foregroundStyle(DoneColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Carte des stats : étiquette en capitales, valeur optionnelle à droite.
private struct StatsCard<Content: View>: View {
    let title: String
    var value: String?
    var valueColor: Color = DoneColor.textPrimary
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DoneSpace.s16) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow(text: title)
                Spacer()
                if let value {
                    Text(value)
                        .doneText(.numericM)
                        .foregroundStyle(valueColor)
                }
            }
            content
        }
        .padding(DoneSpace.s20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .doneCard(radius: DoneRadius.lg)
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
