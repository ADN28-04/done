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
    @State private var weekOffset = 0

    var body: some View {
        let reference = Stats.calendar.date(byAdding: .weekOfYear, value: weekOffset, to: .now) ?? .now
        let week = Stats.week(containing: reference)
        let facts = sessions.filter { week.contains($0.startedAt) }.map(\.fact)
        let days = Stats.byDay(facts, in: week)
        let projects = Stats.byProject(facts)
        let interruptions = Stats.interruptions(facts).reduce(0) { $0 + $1.count }
        let checked = facts.filter { $0.outcome == .done }.count

        VStack(alignment: .leading, spacing: 0) {
            PeriodHeader(title: weekTitle, subtitle: Format.weekRange(week), canGoForward: weekOffset < 0) { weekOffset += $0 }

            HeroNumber(
                value: Format.minutes(Stats.totalMinutes(facts)),
                caption: "de focus · \(plural(facts.count, "session")) · \(plural(checked, "tâche cochée", "tâches cochées")) · \(plural(interruptions, "interruption"))"
            )
            .padding(.top, DoneSpace.s24)

            HStack(alignment: .top, spacing: DoneSpace.s20) {
                StatsCard(title: "Par jour") {
                    DailyBars(days: days)
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
                                MeterRow(label: project.name, value: Format.minutes(project.minutes), fraction: project.minutes / max(longest, 1))
                            }
                        }
                    }
                }
                .frame(width: 340)
            }
            .padding(.top, DoneSpace.s24)
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

/// Barres de minutes par jour, du lundi au dimanche.
private struct DailyBars: View {
    let days: [Stats.DayFocus]

    var body: some View {
        let longest = max(days.map(\.minutes).max() ?? 0, 60)
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(days) { day in
                let isToday = Calendar.current.isDateInToday(day.day)
                VStack(spacing: DoneSpace.s8) {
                    if day.minutes > 0 {
                        Text(Format.minutes(day.minutes))
                            .doneText(.caption)
                            .foregroundStyle(DoneColor.textSecondary)
                            .lineLimit(1)
                            .fixedSize()
                        RoundedRectangle(cornerRadius: DoneRadius.xs, style: .continuous)
                            .fill(DoneColor.stateActive)
                            .frame(width: 40, height: max(8, 210 * day.minutes / longest))
                    } else {
                        RoundedRectangle(cornerRadius: DoneRadius.xs, style: .continuous)
                            .fill(DoneColor.pomodoroTrack)
                            .frame(width: 40, height: 6)
                    }
                    Text(Format.weekdayShort(day.day))
                        .font(isToday ? .sans(12, .semibold) : .done(.caption))
                        .foregroundStyle(isToday ? DoneColor.textPrimary : DoneColor.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 270, alignment: .bottom)
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

/// Une ligne de jauge : libellé, valeur et barre proportionnelle.
private struct MeterRow: View {
    let label: String
    let value: String
    let fraction: Double

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
            ProgressBar(fraction: fraction, height: 8)
        }
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
