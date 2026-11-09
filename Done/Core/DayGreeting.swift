import Foundation

/// La salutation de Ma journée, à la manière de Claude : une courte formule qui dépend de la situation,
/// du jour et du moment, avec ou sans prénom, suivie d'une virgule, d'un point ou d'une question.
/// La situation passe avant le jour, le jour avant le moment. La formule reste la même tout un moment
/// de la journée, et jamais celle du jour précédent. Pas de point d'exclamation, pas de « Bravo ».
enum DayGreeting {
    /// Une formule : son texte, où va le prénom, et sa fin.
    struct Phrase: Equatable {
        enum Name: Equatable {
            /// Sans prénom : « Un café d'abord ? ».
            case none
            /// Après une espace : « Salut Adnan, ».
            case afterSpace
            /// Après une virgule : « Il se fait tard, Adnan. ».
            case afterComma
        }

        enum Ending: String, Equatable {
            case comma = ","
            case period = "."
            /// Espace insécable devant le point d'interrogation, à la française.
            case question = "\u{00A0}?"
        }

        let text: String
        var name: Name = .none
        var ending: Ending

        init(_ text: String, name: Name = .none, _ ending: Ending) {
            self.text = text
            self.name = name
            self.ending = ending
        }

        /// La formule écrite, avec le prénom s'il y en a un.
        func rendered(name first: String?) -> String {
            let trimmed = first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmed.isEmpty else { return text + ending.rawValue }
            switch name {
            case .none: return text + ending.rawValue
            case .afterSpace: return "\(text) \(trimmed)" + ending.rawValue
            case .afterComma: return "\(text), \(trimmed)" + ending.rawValue
            }
        }
    }

    /// Ce que Done sait de la journée et des ouvertures précédentes.
    struct Context: Equatable {
        /// Ouverture précédente de Done, avant celle-ci.
        var lastOpen: Date?
        /// Aujourd'hui est un jour d'absence.
        var absence = false
        /// Le jour ouvré précédent était un jour d'absence.
        var backFromLeave = false
        /// Réunions du jour.
        var meetings = 0
        /// Le plan du jour est bouclé.
        var planFinished = false
    }

    /// Moment de la journée.
    enum Moment: Int, CaseIterable {
        /// De 5 h à 7 h 30.
        case early
        /// De 7 h 30 à midi.
        case morning
        /// De midi à 14 h.
        case lunch
        /// De 14 h à 17 h.
        case afternoon
        /// De 17 h à 19 h.
        case endOfDay
        /// De 19 h à 22 h.
        case evening
        /// De 22 h à 5 h.
        case night

        init(hour: Int, minute: Int) {
            let minutes = hour * 60 + minute
            switch minutes {
            case 300..<450: self = .early
            case 450..<720: self = .morning
            case 720..<840: self = .lunch
            case 840..<1020: self = .afternoon
            case 1020..<1140: self = .endOfDay
            case 1140..<1320: self = .evening
            default: self = .night
            }
        }

        var phrases: [Phrase] {
            switch self {
            case .early: [Phrase("Debout avant tout le monde", .question), Phrase("Lève-tôt aujourd'hui", .period)]
            case .morning: [Phrase("Salut", name: .afterSpace, .comma), Phrase("Un café d'abord", .question), Phrase("On commence par quoi", .question)]
            case .lunch: [Phrase("Bon appétit", name: .afterSpace, .comma), Phrase("Pause déjeuner", .question)]
            case .afternoon: [Phrase("Bon après-midi", name: .afterSpace, .comma), Phrase("On reprend", .question), Phrase("Deuxième mi-temps", .period)]
            case .endOfDay: [Phrase("Dernière ligne droite", .period), Phrase("Bonne fin de journée", name: .afterSpace, .comma), Phrase("On boucle", .question)]
            case .evening: [Phrase("Bonsoir", name: .afterSpace, .comma), Phrase("Encore là", .question), Phrase("Heures sup", .question)]
            case .night: [Phrase("Encore debout", .question), Phrase("Il se fait tard", name: .afterComma, .period)]
            }
        }
    }

    // Formules de situation.
    static let dayOff = Phrase("Profite de ta journée", name: .afterComma, .period)
    static let welcomeBack = [Phrase("Content de te revoir", name: .afterComma, .period), Phrase("Te revoilà", .period)]
    static let again = Phrase("Rebonjour", name: .afterSpace, .comma)
    static let planDone = Phrase("Journée bien remplie", .period)
    static let busyDay = Phrase("Grosse journée", name: .afterComma, .period)
    static let calmDay = Phrase("Journée au calme", .period)

    /// Formules du jour : lundi matin, vendredi, samedi, dimanche (de 5 h à 19 h).
    static func dayPhrases(weekday: Int, moment: Moment) -> [Phrase] {
        guard moment != .night, moment != .evening else { return [] }
        switch weekday {
        case 2 where moment == .early || moment == .morning:
            return [Phrase("Nouvelle semaine", name: .afterComma, .period), Phrase("Bon lundi", .comma)]
        case 6:
            return [Phrase("Bon vendredi", name: .afterSpace, .comma), Phrase("Dernier jour de la semaine", .period)]
        case 7:
            return [Phrase("Bon week-end", name: .afterSpace, .comma), Phrase("Même le samedi", .question)]
        case 1:
            return [Phrase("Bon week-end", name: .afterSpace, .comma), Phrase("Un dimanche studieux", .question)]
        default:
            return []
        }
    }

    /// La formule du moment. `previous` : la dernière salutation affichée un jour précédent, à ne pas
    /// répéter.
    static func phrase(at date: Date, context: Context, previous: String?, name: String?, calendar: Calendar = .current) -> Phrase {
        let parts = calendar.dateComponents([.hour, .minute, .weekday], from: date)
        let moment = Moment(hour: parts.hour ?? 9, minute: parts.minute ?? 0)
        let weekday = parts.weekday ?? 2
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        let seed = day * Moment.allCases.count + moment.rawValue

        /// Une formule de la liste, stable pour ce moment ; jamais celle du jour précédent.
        func pick(_ phrases: [Phrase]) -> Phrase? {
            let usable = phrases.filter { $0.rendered(name: name) != previous }
            guard !usable.isEmpty else { return nil }
            return usable[seed % usable.count]
        }

        // La situation d'abord.
        var tiers: [[Phrase]] = []
        if context.absence { tiers.append([dayOff]) }
        if context.backFromLeave || missedWorkdays(since: context.lastOpen, until: date, calendar: calendar) >= 2 {
            tiers.append(welcomeBack)
        }
        if let lastOpen = context.lastOpen, calendar.isDate(lastOpen, inSameDayAs: date), lastOpen < date {
            tiers.append([again])
        }
        if context.planFinished { tiers.append([planDone]) }
        // Puis le jour.
        tiers.append(dayPhrases(weekday: weekday, moment: moment))
        // Puis le moment, avec, un matin de semaine, ce que disent les réunions du jour.
        var pool = moment.phrases
        if (2...6).contains(weekday), moment.rawValue <= Moment.lunch.rawValue {
            if context.meetings >= 4 { pool.append(busyDay) }
            if context.meetings == 0 { pool.append(calmDay) }
        }
        tiers.append(pool)

        for tier in tiers {
            if let phrase = pick(tier) { return phrase }
        }
        return moment.phrases[0]
    }

    /// La salutation écrite : « Salut Adnan, », « Un café d'abord ? ».
    static func salutation(at date: Date, context: Context = Context(), previous: String? = nil, name: String?, calendar: Calendar = .current) -> String {
        phrase(at: date, context: context, previous: previous, name: name, calendar: calendar).rendered(name: name)
    }

    /// Jours ouvrés entiers sans ouvrir Done, entre la dernière ouverture et aujourd'hui (exclus) : un
    /// lundi après un vendredi n'en compte aucun.
    static func missedWorkdays(since lastOpen: Date?, until date: Date, calendar: Calendar = .current) -> Int {
        guard let lastOpen else { return 0 }
        var day = calendar.startOfDay(for: lastOpen)
        let today = calendar.startOfDay(for: date)
        var count = 0
        var steps = 0
        while steps < 400, let next = calendar.date(byAdding: .day, value: 1, to: day), next < today {
            day = next
            if (2...6).contains(calendar.component(.weekday, from: day)) { count += 1 }
            steps += 1
        }
        return count
    }

    /// Mémoire de la dernière salutation, pour ne pas répéter celle de la veille.
    struct Memory: Equatable {
        /// Jour (clé) de la dernière salutation affichée.
        var day: String?
        /// Dernière salutation affichée ce jour-là.
        var last: String?
        /// Dernière salutation affichée le jour d'avant : celle à ne pas répéter aujourd'hui.
        var previous: String?

        /// La salutation à ne pas répéter aujourd'hui.
        func avoid(today: String) -> String? {
            day == today ? previous : last
        }

        /// La mémoire après avoir affiché `text` le jour `today`.
        func recording(_ text: String, today: String) -> Memory {
            day == today
                ? Memory(day: today, last: text, previous: previous)
                : Memory(day: today, last: text, previous: last)
        }
    }
}
