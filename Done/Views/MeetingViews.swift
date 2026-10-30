import SwiftUI

/// Réunions saisies à la main, du jour et à venir. Done raccourcit les sessions avant elles
/// et prévient quelques minutes avant. Hachurées : le temps est pris.
struct MeetingsCard: View {
    @Environment(AppModel.self) private var model
    @State private var showSheet = false
    @State private var hovered: String?

    var body: some View {
        let meetings = Array(model.upcomingMeetings.prefix(5))
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

/// Saisie d'une réunion : titre, jour, début et fin.
struct MeetingSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var day = Date.now
    @State private var start = MeetingSheet.nextQuarter()
    @State private var end = MeetingSheet.nextQuarter().addingTimeInterval(3600)
    @FocusState private var titleFocused: Bool

    var body: some View {
        let isValid = combine(day, end) > combine(day, start)
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Réunion")
            Text("Nouvelle réunion")
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
                Spacer()
                Button("Annuler") { dismiss() }
                    .buttonStyle(DoneButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("Ajouter") {
                    model.addMeeting(title: title, start: combine(day, start), end: combine(day, end))
                    dismiss()
                }
                .buttonStyle(DoneButtonStyle(kind: .primary))
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding(.top, DoneSpace.s20)
        }
        .padding(DoneSpace.s24)
        .frame(width: 480)
        .background(DoneColor.bgCanvas)
        .onAppear { titleFocused = true }
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
