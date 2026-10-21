import Charts
import SwiftData
import SwiftUI

struct StatsView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case focus = "Focus"
        case backlog = "Backlog"
        var id: String { rawValue }
    }

    /// Choisi dans la barre du haut (`StatsTabPicker`).
    let tab: Tab

    var body: some View {
        ScrollView {
            Group {
                switch tab {
                case .focus: FocusStatsView()
                case .backlog: BacklogStatsView()
                }
            }
            .padding(.leading, 32)
            .padding(.trailing, 40)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.never)
        .environment(\.locale, Locale(identifier: "fr_FR"))
    }
}

/// Choix Focus / Backlog, en verre, au centre de la barre du haut.
struct StatsTabPicker: View {
    @Binding var selection: StatsView.Tab

    var body: some View {
        GlassSegmented(selection: $selection, options: StatsView.Tab.allCases.map { (value: $0, title: $0.rawValue) })
    }
}

// MARK: Onglet Focus

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

// MARK: Onglet Backlog

struct BacklogStatsView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \BacklogSnapshot.day) private var snapshots: [BacklogSnapshot]
    @State private var windowOffset = 0

    var body: some View {
        let rules = model.rules
        let numbers = Stats.backlog(model.index, rules: rules)
        let closed = Stats.closedPerWeek(model.completed, rules: rules, weeks: 8)
        let window = Stats.dayWindow(offset: windowOffset)
        let points = snapshots.filter { window.contains($0.day) }
        let overTarget = numbers.activeCount > rules.maxActive

        VStack(alignment: .leading, spacing: 0) {
            PeriodHeader(title: "Backlog", subtitle: windowTitle(window), canGoForward: windowOffset < 0) { windowOffset += $0 }

            HeroNumber(
                value: "\(numbers.openTopLevel)",
                caption: "chantiers ouverts · âge moyen \(Int(numbers.averageAgeDays.rounded())) j · \(closed.last?.count ?? 0) fermés cette semaine"
            )
            .padding(.top, 24)
            Text("\(numbers.activeCount) chantiers actifs pour \(rules.maxActive) visés")
                .font(.text(13, .medium))
                .foregroundStyle(overTarget ? Theme.orangeText : Theme.accentText)
                .padding(.top, 8)

            Grid(horizontalSpacing: 20, verticalSpacing: 20) {
                GridRow {
                    TrendCard(title: "Chantiers ouverts", value: "\(numbers.openTopLevel)", window: window, points: points.map { TrendPoint(day: $0.day, value: Double($0.openTopLevel)) })
                    TrendCard(title: "Âge moyen", value: "\(Int(numbers.averageAgeDays.rounded())) j", window: window, points: points.map { TrendPoint(day: $0.day, value: $0.averageAgeDays) })
                }
                GridRow {
                    TrendCard(
                        title: "Chantiers actifs",
                        value: "\(numbers.activeCount)",
                        valueColor: overTarget ? Theme.orangeText : Theme.label,
                        window: window,
                        points: points.map { TrendPoint(day: $0.day, value: Double($0.activeCount)) },
                        target: Double(rules.maxActive)
                    )
                    StatsCard(title: "Fermés par semaine", value: "\(closed.last?.count ?? 0)") {
                        WeeklyBars(weeks: closed)
                    }
                }
            }
            .padding(.top, 24)
        }
        .task { await model.loadCompleted() }
    }

    private func windowTitle(_ window: DateInterval) -> String {
        guard windowOffset < 0 else { return "14 derniers jours" }
        let last = window.end.addingTimeInterval(-1)
        return "Du \(Format.shortDate(window.start)) au \(Format.shortDate(last))"
    }
}

private struct TrendPoint: Identifiable {
    let day: Date
    let value: Double
    var id: Date { day }
}

/// Courbe jour après jour, avec la date de début et de fin en dessous.
private struct TrendCard: View {
    let title: String
    let value: String
    var valueColor: Color = Theme.label
    let window: DateInterval
    let points: [TrendPoint]
    var target: Double?

    var body: some View {
        StatsCard(title: title, value: value, valueColor: valueColor) {
            VStack(spacing: 8) {
                if points.count < 2 {
                    Text("La courbe se remplit au fil des jours : une photo du backlog est prise à chaque synchro.")
                        .font(.text(12))
                        .foregroundStyle(Theme.label2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: 110)
                } else {
                    Chart {
                        ForEach(points) { point in
                            LineMark(x: .value("Jour", point.day, unit: .day), y: .value("Valeur", point.value))
                                .foregroundStyle(Theme.ring)
                                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        }
                        if let target {
                            RuleMark(y: .value("Cible", target))
                                .foregroundStyle(Theme.label2)
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        }
                    }
                    .chartXScale(domain: window.start...window.end)
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                            AxisGridLine().foregroundStyle(Theme.separator)
                        }
                    }
                    .frame(height: 110)
                }
                HStack {
                    Text(Format.shortDate(window.start))
                    Spacer()
                    if let target {
                        Text("- - cible \(Int(target))")
                        Spacer()
                    }
                    Text(Format.shortDate(window.end.addingTimeInterval(-1)))
                }
                .font(.mono(10, medium: false))
                .foregroundStyle(Theme.label2)
            }
        }
    }
}

/// Chantiers fermés par semaine, la semaine en cours en accent plein.
private struct WeeklyBars: View {
    let weeks: [Stats.WeekCount]

    var body: some View {
        let most = max(weeks.map(\.count).max() ?? 0, 1)
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(weeks) { week in
                let isCurrent = week.weekStart == weeks.last?.weekStart
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isCurrent ? Theme.ring : Theme.ring.opacity(0.45))
                        .frame(height: week.count > 0 ? max(8, 100 * Double(week.count) / Double(most)) : 4)
                    Text(Format.weekNumber(week.weekStart))
                        .font(.mono(10, medium: isCurrent))
                        .foregroundStyle(isCurrent ? Theme.label : Theme.label2)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 128, alignment: .bottom)
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
