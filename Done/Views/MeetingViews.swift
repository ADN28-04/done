import SwiftUI

/// Réunions saisies à la main, du jour et à venir. Done raccourcit les sessions avant elles
/// et prévient quelques minutes avant. Hachurées : le temps est pris.
struct MeetingsCard: View {
    @Environment(AppModel.self) private var model
    /// Nombre de réunions à venir montrées.
    var limit = 5
    @State private var showSheet = false
    @State private var hovered: String?

    var body: some View {
        let meetings = Array(model.upcomingMeetings.prefix(limit))
        VStack(alignment: .leading, spacing: DoneSpace.s8) {
            HStack {
                Eyebrow(text: "Réunions")
                Spacer()
                Button {
                    showSheet = true
                } label: {
                    Label("Ajouter", systemImage: "plus")
                }
                .buttonStyle(DoneButtonStyle(kind: .plain, compact: true))
            }
            .padding(.leading, DoneSpace.s2)
            if meetings.isEmpty {
                Text("Aucune réunion prévue. Ajoute-les pour que Done propose des sessions qui tiennent avant.")
                    .doneText(.caption)
                    .foregroundStyle(DoneColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, DoneSpace.s2)
            } else {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    VStack(spacing: DoneSpace.s6) {
                        ForEach(meetings) { meeting in
                            row(meeting, now: context.date)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showSheet) {
            MeetingSheet()
                .environment(model)
        }
    }

    private func row(_ meeting: Meeting, now: Date) -> some View {
        MeetingBlock(meeting: meeting, now: now, detail: Format.slot(meeting, now: now))
            .overlay(alignment: .trailing) {
                Button {
                    model.deleteMeeting(meeting.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(meeting.contains(now) ? DoneColor.meetingOnNow : DoneColor.textSecondary)
                .padding(.trailing, DoneSpace.s6)
                .opacity(hovered == meeting.id ? 1 : 0)
                .help("Supprimer la réunion")
            }
            .onHover { inside in
                if inside {
                    hovered = meeting.id
                } else if hovered == meeting.id {
                    hovered = nil
                }
            }
    }
}

/// Saisie d'une réunion : titre, jour, début et fin. Sert aussi à la modifier ou la supprimer
/// (depuis le calendrier), et peut partir d'un créneau choisi.
struct MeetingSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    /// La réunion modifiée, `nil` pour une nouvelle.
    private let meeting: Meeting?
    @State private var title: String
    @State private var day: Date
    @State private var start: Date
    @State private var end: Date
    @State private var openedNote: NoteRef?
    /// Répétition choisie ; lue sur la série pour une occurrence de réunion récurrente.
    @State private var recurrence: Recurrence?
    /// Fin de la répétition : « Jusqu'au » coché, et le dernier jour.
    @State private var hasEnd = false
    @State private var endDay = Date.now
    @State private var loadedSeries = false
    /// Occurrence d'une série : ce qui attend une réponse (« Cette réunion » ou « Toutes les suivantes »).
    @State private var pending: Pending?
    @FocusState private var titleFocused: Bool

    private enum Pending: Identifiable {
        case save, stop, delete
        var id: Self { self }
    }

    init(meeting: Meeting? = nil, start: Date? = nil, end: Date? = nil, title: String = "") {
        self.meeting = meeting
        let from = meeting?.start ?? start ?? MeetingSheet.nextQuarter()
        _title = State(initialValue: meeting?.title ?? title)
        _day = State(initialValue: from)
        _start = State(initialValue: from)
        _end = State(initialValue: meeting?.end ?? end ?? from.addingTimeInterval(3600))
    }

    /// La série de la réunion ouverte, `nil` pour une réunion simple ou nouvelle.
    private var series: MeetingSeries? {
        meeting.flatMap { model.meetingSeries(of: $0) }
    }

    var body: some View {
        let isValid = combine(day, end) > combine(day, start)
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: series.map(Self.seriesLabel) ?? "Réunion")
            Text(meeting == nil ? "Nouvelle réunion" : "Modifier la réunion")
                .doneText(.displayM)
                .foregroundStyle(DoneColor.textPrimary)
                .padding(.top, DoneSpace.s8)
            TextField("Titre, par exemple Point avec Zoé", text: $title)
                .focused($titleFocused)
                .doneField(focused: titleFocused)
                .padding(.top, DoneSpace.s16)
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
            HStack(alignment: .top, spacing: DoneSpace.s20) {
                labeled("Répétition") {
                    RecurrenceMenu(
                        recurrence: $recurrence,
                        due: Binding(get: { day }, set: { if let new = $0 { day = new } }),
                        help: "La réunion revient à ce rythme ; Done crée celles de cette semaine et de la suivante"
                    )
                }
                // Une répétition peut s'arrêter à une date : « jusqu'au 18 décembre ».
                if recurrence != nil {
                    labeled("Fin") {
                        HStack(spacing: DoneSpace.s8) {
                            Toggle("Jusqu'au", isOn: $hasEnd)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .fixedSize()
                            if hasEnd {
                                DatePicker("Jusqu'au", selection: $endDay, in: Calendar.current.startOfDay(for: day)..., displayedComponents: .date)
                                    .labelsHidden()
                            } else {
                                Text("Sans fin")
                                    .doneText(.callout)
                                    .foregroundStyle(DoneColor.textSecondary)
                            }
                        }
                    }
                }
            }
            .padding(.top, DoneSpace.s16)
            if !isValid {
                Text("La fin doit venir après le début.")
                    .doneText(.caption)
                    .foregroundStyle(DoneColor.stateRiskText)
                    .padding(.top, DoneSpace.s8)
            }
            Text("Done ne lance pas de session qui déborde sur une réunion, et te prévient avant (Réglages › Notifications).")
                .doneText(.caption)
                .foregroundStyle(DoneColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, DoneSpace.s12)
            HStack(spacing: DoneSpace.s8) {
                if let meeting {
                    Button("Supprimer") {
                        if series != nil {
                            pending = .delete
                        } else {
                            model.deleteMeeting(meeting.id)
                            dismiss()
                        }
                    }
                    .buttonStyle(DoneButtonStyle(kind: .plain))
                    .fixedSize()
                    Button {
                        openedNote = NoteRef(id: NoteBook.shared.ensureMeetingNote(for: meeting).id)
                    } label: {
                        Label(NoteBook.shared.meetingNote(for: meeting) == nil ? "Prendre des notes" : "Ouvrir la note", systemImage: "doc.text")
                    }
                    .buttonStyle(DoneButtonStyle(kind: .plain))
                    .fixedSize()
                    .help("Note de réunion, préremplie")
                }
                Spacer(minLength: DoneSpace.s8)
                Button("Annuler") { dismiss() }
                    .buttonStyle(DoneButtonStyle())
                    .keyboardShortcut(.cancelAction)
                    .fixedSize()
                Button(meeting == nil ? "Ajouter" : "Enregistrer", action: save)
                    .buttonStyle(DoneButtonStyle(kind: .primary))
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
                    .fixedSize()
            }
            .padding(.top, DoneSpace.s20)
        }
        .padding(DoneSpace.s24)
        .frame(width: 580)
        .background(DoneColor.bgCanvas)
        .onAppear {
            titleFocused = true
            if !loadedSeries {
                recurrence = series?.recurrence
                if let last = series?.lastDay.flatMap(Format.date(fromDayKey:)) {
                    hasEnd = true
                    endDay = last
                } else {
                    endDay = Calendar.current.date(byAdding: .month, value: 3, to: day) ?? day
                }
                loadedSeries = true
            }
        }
        .sheet(item: $openedNote) { ref in
            NoteSheet(noteID: ref.id)
                .environment(model)
        }
        .confirmationDialog(dialogTitle, isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }), presenting: pending) { choice in
            switch choice {
            case .save:
                // Une autre répétition vaut pour toute la suite de la série.
                if recurrence == series?.recurrence && untilKey == series?.lastDay {
                    Button("Cette réunion seulement") { saveOccurrence() }
                }
                Button("Toutes les suivantes") { saveFollowing() }
            case .stop:
                Button("Ne plus répéter") { stopRepeating() }
            case .delete:
                Button("Cette réunion seulement", role: .destructive) { deleteOccurrence() }
                Button("Celle-ci et toutes les suivantes", role: .destructive) { deleteFollowing() }
            }
            Button("Annuler", role: .cancel) { pending = nil }
        } message: { choice in
            switch choice {
            case .save: Text("Cette réunion revient régulièrement.")
            case .stop: Text("Cette réunion reste, avec tes changements ; les suivantes de la série sont retirées.")
            case .delete: Text("Cette réunion revient régulièrement.")
            }
        }
    }

    /// Le dernier jour choisi pour la répétition, ou nil sans fin.
    private var until: Date? {
        recurrence != nil && hasEnd ? Calendar.current.startOfDay(for: endDay) : nil
    }

    private var untilKey: String? { until.map(Format.dayKey) }

    /// « Réunion · Chaque lundi », « Réunion · Chaque lundi, jusqu'au 18 déc. ».
    private static func seriesLabel(_ series: MeetingSeries) -> String {
        guard let rule = series.recurrence else { return "Réunion" }
        guard let last = series.lastDay.flatMap(Format.date(fromDayKey:)) else { return "Réunion · \(rule.label)" }
        return "Réunion · \(rule.label), jusqu'au \(Format.shortDate(last))"
    }

    private var dialogTitle: String {
        switch pending {
        case .save: "Modifier cette réunion ou toute la suite ?"
        case .stop: "Ne plus répéter cette réunion ?"
        case .delete: "Supprimer cette réunion ou toute la suite ?"
        case nil: ""
        }
    }

    /// La réunion telle que la fiche la décrit.
    private var edited: Meeting? {
        meeting.map { Meeting(id: $0.id, title: title, start: combine(day, start), end: combine(day, end), seriesID: $0.seriesID) }
    }

    private func save() {
        let from = combine(day, start)
        let to = combine(day, end)
        guard let meeting else {
            if let recurrence {
                model.addMeetingSeries(title: title, start: from, end: to, recurrence: recurrence, until: until)
            } else {
                model.addMeeting(title: title, start: from, end: to)
            }
            dismiss()
            return
        }
        guard let series else {
            model.updateMeeting(Meeting(id: meeting.id, title: title, start: from, end: to))
            if let recurrence { model.makeRecurring(meeting.id, recurrence: recurrence, until: until) }
            dismiss()
            return
        }
        if recurrence == nil {
            pending = .stop
            return
        }
        let unchanged = title.trimmingCharacters(in: .whitespacesAndNewlines) == meeting.title
            && from == meeting.start && to == meeting.end && recurrence == series.recurrence && untilKey == series.lastDay
        if unchanged {
            dismiss()
        } else {
            pending = .save
        }
    }

    private func saveOccurrence() {
        if let edited { model.updateMeeting(edited) }
        dismiss()
    }

    private func saveFollowing() {
        if let meeting, let recurrence {
            model.updateMeetingSeries(from: meeting, title: title, start: combine(day, start), end: combine(day, end), recurrence: recurrence, until: until)
        }
        dismiss()
    }

    private func stopRepeating() {
        if let edited { model.endMeetingSeries(at: edited) }
        dismiss()
    }

    private func deleteOccurrence() {
        if let meeting { model.deleteMeeting(meeting.id) }
        dismiss()
    }

    private func deleteFollowing() {
        if let meeting { model.deleteMeetingSeries(from: meeting) }
        dismiss()
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

    /// Prochain quart d'heure plein après `date`.
    static func nextQuarter(after date: Date = .now) -> Date {
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: date)
        let rounded = calendar.date(byAdding: .minute, value: 15 - minute % 15, to: date) ?? date
        return calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: rounded)) ?? rounded
    }
}
