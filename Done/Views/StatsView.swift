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
        VStack(alignment: .leading, spacing: 16) {
            Picker("Vue", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 240)

            switch tab {
            case .focus: FocusStatsView()
            case .backlog: BacklogStatsView()
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

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
        let interruptionCount = reasons.reduce(0) { $0 + $1.count }

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Button { weekOffset -= 1 } label: { Image(systemName: "chevron.left") }
                    Text(weekTitle(week))
                        .font(.headline)
                        .frame(minWidth: 220)
                    Button { weekOffset += 1 } label: { Image(systemName: "chevron.right") }
                        .disabled(weekOffset >= 0)
                }

                HStack(spacing: 12) {
                    StatTile(title: "Temps de focus", value: Format.minutes(Stats.totalMinutes(facts)))
                    StatTile(title: "Sessions", value: "\(facts.count)")
                    StatTile(title: "Tâches cochées", value: "\(facts.filter { $0.outcome == .done }.count)")
                    StatTile(title: "Interruptions", value: "\(interruptionCount)")
                }

                if facts.isEmpty {
                    ContentUnavailableView(
                        "Aucune session cette semaine",
                        systemImage: "timer",
                        description: Text("Les sessions lancées depuis l'écran Focus apparaîtront ici.")
                    )
                } else {
                    Card(title: "Minutes de focus par jour") {
                        Chart(days) { day in
                            BarMark(
                                x: .value("Jour", day.day, unit: .day),
                                y: .value("Minutes", day.minutes)
                            )
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day)) { _ in
                                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                            }
                        }
                        .frame(height: 180)
                    }

                    Card(title: "Temps par projet") {
                        Chart(projects) { project in
                            BarMark(
                                x: .value("Minutes", project.minutes),
                                y: .value("Projet", project.name)
                            )
                        }
                        .frame(height: max(80, CGFloat(projects.count) * 32))
                    }

                    Card(title: "Interruptions par raison") {
                        HStack(spacing: 24) {
                            ForEach(reasons) { item in
                                Label("\(item.reason.label) : \(item.count)", systemImage: item.reason.symbol)
                            }
                        }
                    }
                }
            }
        }
    }

    private func weekTitle(_ week: DateInterval) -> String {
        let end = week.end.addingTimeInterval(-1)
        return "Semaine du \(Format.day(week.start)) au \(Format.day(end))"
    }
}

struct BacklogStatsView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \BacklogSnapshot.day) private var snapshots: [BacklogSnapshot]

    var body: some View {
        let rules = model.rules
        let numbers = Stats.backlog(model.index, rules: rules)
        let closed = Stats.closedPerWeek(model.completed, rules: rules, weeks: 8)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(scopeDescription(rules))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    StatTile(title: "Chantiers ouverts", value: "\(numbers.openTopLevel)", detail: "\(numbers.openTasks) tâches avec les sous-tâches")
                    StatTile(title: "Âge moyen", value: "\(Int(numbers.averageAgeDays.rounded())) j", detail: "Le plus ancien : \(Int(numbers.oldestAgeDays.rounded())) j")
                    StatTile(
                        title: "Chantiers actifs",
                        value: "\(numbers.activeCount)",
                        detail: "Cible : \(rules.maxActive) maximum",
                        tint: numbers.activeCount > rules.maxActive ? .orange : .green
                    )
                    StatTile(title: "Fermés cette semaine", value: "\(closed.last?.count ?? 0)")
                }

                Card(title: "Chantiers ouverts, jour après jour") {
                    Chart(snapshots) { snapshot in
                        LineMark(x: .value("Jour", snapshot.day, unit: .day), y: .value("Chantiers", snapshot.openTopLevel))
                        PointMark(x: .value("Jour", snapshot.day, unit: .day), y: .value("Chantiers", snapshot.openTopLevel))
                    }
                    .frame(height: 160)
                }

                Card(title: "Âge moyen des chantiers (jours)") {
                    Chart(snapshots) { snapshot in
                        LineMark(x: .value("Jour", snapshot.day, unit: .day), y: .value("Jours", snapshot.averageAgeDays))
                        PointMark(x: .value("Jour", snapshot.day, unit: .day), y: .value("Jours", snapshot.averageAgeDays))
                    }
                    .frame(height: 160)
                }

                Card(title: "Chantiers actifs en parallèle") {
                    Chart {
                        ForEach(snapshots) { snapshot in
                            LineMark(x: .value("Jour", snapshot.day, unit: .day), y: .value("Actifs", snapshot.activeCount))
                            PointMark(x: .value("Jour", snapshot.day, unit: .day), y: .value("Actifs", snapshot.activeCount))
                        }
                        RuleMark(y: .value("Cible", rules.maxActive))
                            .foregroundStyle(.green)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                    .frame(height: 160)
                }

                Card(title: "Chantiers fermés par semaine (Todoist)") {
                    Chart(closed) { week in
                        BarMark(x: .value("Semaine", week.weekStart, unit: .weekOfYear), y: .value("Fermés", week.count))
                    }
                    .frame(height: 160)
                }

                Text("Une photo du backlog est prise à chaque synchro, une par jour. Les courbes se remplissent au fil des jours.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task { await model.loadCompleted() }
    }

    private func scopeDescription(_ rules: Rules) -> String {
        let scope = rules.backlogScope
        guard !scope.isEmpty else { return "Périmètre : tous les projets, hors réunions." }
        let names = model.projects.filter { scope.contains($0.id) }.map(\.name)
        return "Périmètre : \(names.joined(separator: ", "))."
    }
}
