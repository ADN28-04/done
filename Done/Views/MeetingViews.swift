import SwiftUI

/// Réunions saisies à la main, du jour et à venir. Done raccourcit les sessions avant elles
/// et prévient quelques minutes avant.
struct MeetingsCard: View {
    @Environment(AppModel.self) private var model
    @State private var showSheet = false
    @State private var hovered: String?

    var body: some View {
        let meetings = Array(model.upcomingMeetings.prefix(5))
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Eyebrow(text: "Réunions")
                Spacer()
                Button {
                    showSheet = true
                } label: {
                    Label("Ajouter", systemImage: "plus")
                }
                .buttonStyle(PillButtonStyle(kind: .plain, size: .mini))
            }
            .padding(.leading, 2)
            if meetings.isEmpty {
                Text("Aucune réunion prévue. Ajoute-les pour que Done propose des sessions qui tiennent avant.")
                    .font(.text(12))
                    .foregroundStyle(Theme.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 2)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(meetings.enumerated()), id: \.element.id) { offset, meeting in
                        if offset > 0 {
                            Hairline().padding(.horizontal, 12)
                        }
                        row(meeting)
                    }
                }
                .padding(4)
                .surface(radius: 16)
            }
        }
        .sheet(isPresented: $showSheet) {
            MeetingSheet()
                .environment(model)
        }
    }

    private func row(_ meeting: Meeting) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(meeting.title)
                    .font(.text(14))
                    .lineLimit(1)
                Text(Format.slot(meeting))
                    .font(.mono(11, medium: false))
                    .foregroundStyle(Theme.label2)
            }
            Spacer(minLength: 0)
            Button {
                model.deleteMeeting(meeting.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.label2)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(hovered == meeting.id ? 1 : 0)
            .help("Supprimer la réunion")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
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
                .font(.display(24))
                .padding(.top, 10)
            TextField("Titre, par exemple Point avec Zoé", text: $title)
                .textFieldStyle(.plain)
                .font(.text(14))
                .focused($titleFocused)
                .padding(.horizontal, 14)
                .frame(height: 40)
                .surface(radius: 12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.ring.opacity(titleFocused ? 0.45 : 0), lineWidth: 2)
                )
                .padding(.top, 18)
            HStack(alignment: .top, spacing: 20) {
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
            .padding(.top, 16)
            if !isValid {
                Text("La fin doit venir après le début.")
                    .font(.text(12))
                    .foregroundStyle(Theme.orangeText)
                    .padding(.top, 8)
            }
            Text("Done ne lance pas de session qui déborde sur une réunion, et te prévient avant (Réglages › Notifications).")
                .font(.text(12))
                .foregroundStyle(Theme.label2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
            HStack(spacing: 10) {
                Spacer()
                Button("Annuler") { dismiss() }
                    .buttonStyle(PillButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("Ajouter") {
                    model.addMeeting(title: title, start: combine(day, start), end: combine(day, end))
                    dismiss()
                }
                .buttonStyle(PillButtonStyle(kind: .primary))
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding(.top, 22)
        }
        .padding(28)
        .frame(width: 480)
        .background(Backdrop(style: .wash))
        .onAppear { titleFocused = true }
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
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
