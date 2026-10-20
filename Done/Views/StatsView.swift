import Charts
import SwiftData
import SwiftUI

struct StatsView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case focus = "Focus"
        case backlog = "Backlog"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .focus

    var body: some View {
        ScrollView {
            Group {
                switch tab {
                case .focus: FocusStatsView()
                case .backlog: BacklogStatsView()
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .environment(\.locale, Locale(identifier: "fr_FR"))
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Vue", selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 180)
            }
        }
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
        let reasons = Stats.interruptions(facts)

        VStack(alignment: .leading, spacing: 16) {
            PeriodHeader(title: Format.weekTitle(week), canGoForward: weekOffset < 0) { weekOffset += $0 }

            HStack(spacing: 12) {
                StatTile(title: "Temps de focus", value: Format.minutes(Stats.totalMinutes(facts)))
                StatTile(title: "Sessions", value: "\(facts.count)")
                StatTile(title: "Tâches cochées", value: "\(facts.filter { $0.outcome == .done }.count)")
                StatTile(title: "Interruptions", value: "\(reasons.reduce(0) { $0 + $1.count })")
            }

            HStack(alignment: .top, spacing: 16) {
                ChartCard(title: "Minutes de focus par jour") {
                    if facts.isEmpty {
                        EmptyChart(message: "Aucune session cette semaine. Elles apparaîtront ici dès ta première session.")
                    } else {
                        DailyFocusChart(days: days)
                    }
                }
                .frame(minWidth: 280, maxWidth: .infinity)

                VStack(spacing: 16) {
                    ChartCard(title: "Temps par projet") {
                        if projects.isEmpty {
                            EmptyChart(message: "Pas encore de données.")
                        } else {
                            let longest = projects.map(\.minutes).max() ?? 1
                            VStack(spacing: 14) {
                                ForEach(projects) { project in
                                    MeterRow(label: project.name, value: Format.minutes(project.minutes), fraction: project.minutes / max(longest, 1), color: Theme.accent)
                                }
                            }
                        }
                    }
                    ChartCard(title: "Interruptions par raison") {
                        let most = Double(reasons.map(\.count).max() ?? 0)
                        VStack(spacing: 14) {
                            ForEach(reasons) { item in
                                MeterRow(label: item.reason.label, value: "\(item.count)", fraction: most > 0 ? Double(item.count) / most : 0, color: Theme.label2)
                            }
                        }
                    }
                }
                .frame(minWidth: 240, idealWidth: 360, maxWidth: 380)
            }
        }
    }
}

private struct DailyFocusChart: View {
    let days: [Stats.DayFocus]

    var body: some View {
        let top = max(60, ((days.map(\.minutes).max() ?? 0) / 60).rounded(.up) * 60)
        Chart(days) { day in
            BarMark(
                x: .value("Jour", day.day, unit: .day),
                y: .value("Minutes", day.minutes),
                width: .ratio(0.45)
            )
            .foregroundStyle(Theme.accent)
            .cornerRadius(4)
            .annotation(position: .top, spacing: 4) {
                if day.minutes > 0 {
                    Text(Format.minutes(day.minutes))
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(Theme.label2)
                }
            }
        }
        .chartYScale(domain: 0...top)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .stride(by: 60)) { value in
                AxisGridLine().foregroundStyle(Theme.separator)
                AxisValueLabel {
                    if let minutes = value.as(Double.self) {
                        Text(Format.hours(minutes))
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(Theme.label2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: days.map(\.day)) { value in
                AxisValueLabel(centered: true) {
                    if let date = value.as(Date.self) {
                        Text(Format.weekdayInitial(date))
                            .font(.system(size: 11, weight: Calendar.current.isDateInToday(date) ? .bold : .regular))
                            .foregroundStyle(Calendar.current.isDateInToday(date) ? Theme.label : Theme.label2)
                    }
                }
            }
        }
        .frame(height: 260)
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

        VStack(alignment: .leading, spacing: 16) {
            PeriodHeader(title: windowTitle(window), canGoForward: windowOffset < 0) { windowOffset += $0 }

            HStack(spacing: 12) {
                StatTile(title: "Chantiers ouverts", value: "\(numbers.openTopLevel)")
                StatTile(title: "Âge moyen", value: "\(Int(numbers.averageAgeDays.rounded())) j")
                StatTile(
                    title: "Chantiers actifs",
                    value: "\(numbers.activeCount)",
                    suffix: " / \(rules.maxActive)",
                    detail: overTarget ? "Cible dépassée" : nil,
                    tint: overTarget ? Theme.orangeText : Theme.label
                )
                StatTile(title: "Fermés cette semaine", value: "\(closed.last?.count ?? 0)")
            }

            Grid(horizontalSpacing: 16, verticalSpacing: 16) {
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
                    ChartCard(title: "Chantiers fermés par semaine", value: "\(closed.last?.count ?? 0)") {
                        ClosedPerWeekChart(weeks: closed)
                    }
                }
            }
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
        ChartCard(title: title, value: value, valueColor: valueColor) {
            VStack(spacing: 6) {
                if points.count < 2 {
                    EmptyChart(message: "La courbe se remplit au fil des jours : une photo du backlog est prise à chaque synchro.")
                        .frame(height: 110)
                } else {
                    Chart {
                        ForEach(points) { point in
                            LineMark(x: .value("Jour", point.day, unit: .day), y: .value("Valeur", point.value))
                                .foregroundStyle(Theme.accent)
                                .lineStyle(StrokeStyle(lineWidth: 1.5, lineJoin: .round))
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
                .font(.system(size: 10))
                .foregroundStyle(Theme.label2)
            }
        }
    }
}

private struct ClosedPerWeekChart: View {
    let weeks: [Stats.WeekCount]

    var body: some View {
        let current = weeks.last.map { Format.weekNumber($0.weekStart) }
        Chart(weeks) { week in
            BarMark(x: .value("Semaine", Format.weekNumber(week.weekStart)), y: .value("Fermés", week.count), width: .ratio(0.8))
                .foregroundStyle(week.weekStart == weeks.last?.weekStart ? Theme.accent : Theme.accent.opacity(0.5))
                .cornerRadius(3)
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let label = value.as(String.self) {
                        Text(label)
                            .font(.system(size: 10, weight: label == current ? .bold : .regular))
                            .foregroundStyle(label == current ? Theme.label : Theme.label2)
                    }
                }
            }
        }
        .frame(height: 128)
    }
}

// MARK: Composants des stats

private struct PeriodHeader: View {
    let title: String
    let canGoForward: Bool
    let move: (Int) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button { move(-1) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(RoundIconButtonStyle())
                .help("Période précédente")
            Button { move(1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(RoundIconButtonStyle())
                .disabled(!canGoForward)
                .opacity(canGoForward ? 1 : 0.4)
                .help("Période suivante")
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.label)
                .padding(.leading, 8)
        }
    }
}

struct StatTile: View {
    let title: String
    let value: String
    var suffix: String?
    var detail: String?
    var tint: Color = Theme.label

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Theme.label2)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(value)
                    .font(.system(size: 26, weight: .semibold).monospacedDigit())
                    .foregroundStyle(tint)
                if let suffix {
                    Text(suffix)
                        .font(.system(size: 17, weight: .medium).monospacedDigit())
                        .foregroundStyle(Theme.label2)
                }
            }
            if let detail {
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(tint)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .topLeading)
        .panelStyle()
    }
}

private struct ChartCard<Content: View>: View {
    let title: String
    var value: String?
    var valueColor: Color = Theme.label
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.label)
                Spacer()
                if let value {
                    Text(value)
                        .font(.system(size: 15, weight: .semibold).monospacedDigit())
                        .foregroundStyle(valueColor)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .panelStyle()
    }
}

/// Une ligne de jauge : libellé, valeur et barre proportionnelle.
private struct MeterRow: View {
    let label: String
    let value: String
    let fraction: Double
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .foregroundStyle(Theme.label)
                    .lineLimit(1)
                Spacer()
                Text(value)
                    .monospacedDigit()
                    .foregroundStyle(Theme.label2)
            }
            .font(.system(size: 13))
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.track)
                    Capsule().fill(color).frame(width: proxy.size.width * max(0, min(1, fraction)))
                }
            }
            .frame(height: 6)
        }
    }
}

private struct EmptyChart: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 12))
            .foregroundStyle(Theme.label2)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 80)
    }
}
