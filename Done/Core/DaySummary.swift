import Foundation

/// Titre d'accueil de Ma journée : une salutation (`DayGreeting`), puis une phrase de faits sur ce qui
/// reste à faire. Nombres en lettres jusqu'à dix, pas de point d'exclamation, pas de « Bravo ».
enum DaySummary {
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

    /// La phrase de faits telle qu'elle suit la salutation : en minuscule après une virgule, avec une
    /// majuscule après un point ou une question (« Un café d'abord ? Trois tâches… »).
    static func sentence(_ sentence: String, after salutation: String) -> String {
        guard let last = salutation.trimmingCharacters(in: .whitespaces).last, last == "." || last == "?" else { return sentence }
        return sentence.prefix(1).uppercased() + sentence.dropFirst()
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
