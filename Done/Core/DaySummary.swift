import Foundation

/// Titre d'accueil de Ma journée : une salutation qui suit le moment de la journée, puis une phrase de
/// faits sur ce qui reste à faire. Nombres en lettres jusqu'à dix, pas de point d'exclamation, pas de
/// « Bravo ». La formule de salut change d'un jour à l'autre, mais reste la même toute une demi-journée.
enum DaySummary {
    /// Moment de la journée, d'après l'heure.
    enum Moment: Equatable {
        /// De 5 h à midi.
        case morning
        /// De midi à 18 h.
        case afternoon
        /// De 18 h à 22 h.
        case evening
        /// De 22 h à 5 h.
        case night

        init(hour: Int) {
            switch hour {
            case 5..<12: self = .morning
            case 12..<18: self = .afternoon
            case 18..<22: self = .evening
            default: self = .night
            }
        }

        /// Les formules possibles : la première est la plus simple. Chacune se lit devant un prénom
        /// (« Bon matin Adnan, ») comme seule (« Bon matin, »).
        var phrases: [String] {
            switch self {
            case .morning: ["Bonjour", "Bon matin", "Belle matinée", "Joli matin"]
            case .afternoon: ["Bon après-midi", "Rebonjour", "Bel après-midi"]
            case .evening: ["Bonsoir", "Belle soirée", "Bonne fin de journée"]
            case .night: ["Bonsoir", "Belle nuit"]
            }
        }
    }

    /// Ce que dit la phrase : les faits de la journée.
    struct Facts: Equatable {
        /// Jour d'absence : son libellé (« Congé »).
        var absence: String?
        /// Tâches du plan encore ouvertes.
        var openTasks = 0
        /// Un plan a été fait pour aujourd'hui.
        var hasPlan = false
        /// Le plan est bouclé : au moins une tâche cochée, aucune ouverte.
        var planFinished = false
        /// Réunions qui ne sont pas encore finies.
        var meetingsLeft = 0
        /// Aucune réunion après midi, et on est le matin ou à midi.
        var afternoonFree = false
    }

    /// Le prénom de la salutation : celui des réglages, sinon le premier mot du nom complet du compte
    /// macOS, sinon rien.
    static func firstName(setting: String, fullName: String) -> String? {
        let chosen = setting.trimmingCharacters(in: .whitespacesAndNewlines)
        if !chosen.isEmpty { return chosen }
        return fullName.split(whereSeparator: \.isWhitespace).first.map(String.init)
    }

    /// « Bonjour Adnan, », ou « Bonjour, » sans prénom. La formule dépend du moment et du jour.
    static func salutation(at date: Date, name: String?, calendar: Calendar = .current) -> String {
        let moment = Moment(hour: calendar.component(.hour, from: date))
        let phrases = moment.phrases
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        let phrase = phrases[day % phrases.count]
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? phrase + "," : "\(phrase) \(trimmed),"
    }

    /// La phrase de faits, en minuscule après la salutation, avec son point final.
    static func sentence(_ facts: Facts, at date: Date = .now, calendar: Calendar = .current) -> String {
        if facts.absence != nil {
            return "jour de congé. Rien de prévu."
        }
        let meetings = facts.meetingsLeft
        if facts.planFinished {
            let variants = meetings == 0
                ? ["le plan est terminé.", "le plan est terminé, la suite de la journée est libre."]
                : ["le plan est terminé, il reste \(count(meetings, "réunion", "réunions")).", "le plan est terminé, plus que \(count(meetings, "réunion", "réunions")) au programme."]
            let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
            return variants[day % variants.count]
        }
        let tasks = facts.openTasks
        if tasks == 0 && meetings == 0 {
            return facts.hasPlan ? "rien d'ouvert dans le plan pour l'instant." : "rien de prévu pour l'instant."
        }
        if tasks == 0 {
            return facts.hasPlan
                ? "\(count(meetings, "réunion", "réunions")) aujourd'hui."
                : "\(count(meetings, "réunion", "réunions")) aujourd'hui, et pas encore de plan."
        }
        if tasks == 1 && meetings == 0 {
            return facts.afternoonFree ? "plus qu'une tâche, et l'après-midi est libre." : "plus qu'une tâche aujourd'hui."
        }
        if meetings == 0 {
            return facts.afternoonFree
                ? "\(count(tasks, "tâche", "tâches")) aujourd'hui, et l'après-midi est libre."
                : "\(count(tasks, "tâche", "tâches")) aujourd'hui, sans réunion."
        }
        return "\(count(tasks, "tâche", "tâches")) et \(count(meetings, "réunion", "réunions")) aujourd'hui."
    }

    /// « une tâche », « trois réunions », « 12 tâches » : en lettres jusqu'à dix, au féminin.
    static func count(_ number: Int, _ singular: String, _ plural: String) -> String {
        "\(spelled(number)) \(number > 1 ? plural : singular)"
    }

    /// Nombre en lettres jusqu'à dix (au féminin : « une »), en chiffres au-delà.
    static func spelled(_ number: Int) -> String {
        let words = ["zéro", "une", "deux", "trois", "quatre", "cinq", "six", "sept", "huit", "neuf", "dix"]
        return words.indices.contains(number) ? words[number] : "\(number)"
    }
}
