import SwiftData
import SwiftUI

struct StatsView: View {
    var body: some View {
        ScrollView {
            FocusStatsView()
                .padding(.leading, 32)
                .padding(.trailing, 40)
                .padding(.top, 4)
                .padding(.bottom, 24)
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
            .padding(.top, 24)

            HStack(alignment: .top, spacing: 20) {
                StatsCard(title: "Par jour") {
                    DailyBars(days: days)
                }
                .frame(minWidth: 360, maxWidth: .infinity)

                StatsCard(title: "Par projet") {
                    if projects.isEmpty {
                        Text("Pas encore de session cette semaine.")
                            .font(.text(13))
                            .foregroundStyle(Theme.label2)
                    } else {
                        let longest = projects.map(\.minutes).max() ?? 1
                        VStack(spacing: 18) {
                            ForEach(projects) { project in
                                MeterRow(label: project.name, value: Format.minutes(project.minutes), fraction: project.minutes / max(longest, 1))
                            }
                        }
                    }
                }
                .frame(width: 340)
            }
            .padding(.top, 24)
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
                VStack(spacing: 8) {
                    if day.minutes > 0 {
                        Text(Format.minutes(day.minutes))
                            .font(.text(12))
                            .foregroundStyle(Theme.label2)
                            .lineLimit(1)
                            .fixedSize()
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.ring)
                            .frame(width: 44, height: max(12, 210 * day.minutes / longest))
                    } else {
                        Capsule()
                            .fill(Theme.track)
                            .frame(width: 44, height: 6)
                    }
                    Text(Format.weekdayShort(day.day))
                        .font(.text(12, isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? Theme.label : Theme.label2)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 270, alignment: .bottom)
    }
}

// MARK: Composants des stats

/// Titre de période, sous-titre et flèches en verre.
private struct PeriodHeader: View {
    let title: String
    let subtitle: String
    let canGoForward: Bool
    let move: (Int) -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.display(30, bold: true))
                    .tracking(-0.45)
                Text(subtitle)
                    .font(.text(15))
                    .foregroundStyle(Theme.label2)
            }
            Spacer()
            Button { move(-1) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(RoundGlassButtonStyle())
                .help("Période précédente")
            Button { move(1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(RoundGlassButtonStyle())
                .disabled(!canGoForward)
                .opacity(canGoForward ? 1 : 0.4)
                .help("Période suivante")
        }
    }
}

/// Grand chiffre en DM Mono, suivi de sa légende.
private struct HeroNumber: View {
    let value: String
    let caption: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            TimerText(text: value, size: 64, color: Theme.accentText)
            Text(caption)
                .font(.text(15))
                .foregroundStyle(Theme.label2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Carte des stats : étiquette en DM Mono, valeur optionnelle à droite.
private struct StatsCard<Content: View>: View {
    let title: String
    var value: String?
    var valueColor: Color = Theme.label
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow(text: title)
                Spacer()
                if let value {
                    Text(value)
                        .font(.mono(17))
                        .foregroundStyle(valueColor)
                }
            }
            content
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .surface(radius: 20)
    }
}

/// Une ligne de jauge : libellé, valeur et barre proportionnelle.
private struct MeterRow: View {
    let label: String
    let value: String
    let fraction: Double

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(label)
                    .lineLimit(1)
                Spacer()
                Text(value)
                    .foregroundStyle(Theme.label2)
            }
            .font(.text(14))
            ProgressBar(fraction: fraction, height: 10)
        }
    }
}

/// Résumé d'une journée, partagé avec le bilan du soir.
struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: title)
            Text(value)
                .font(.mono(26))
                .tracking(-0.8)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surface(radius: 16)
    }
}

private func plural(_ count: Int, _ singular: String, _ pluralForm: String? = nil) -> String {
    "\(count) \(count > 1 ? (pluralForm ?? singular + "s") : singular)"
}
