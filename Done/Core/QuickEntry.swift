import Foundation

/// Lecture de la fin d'un titre saisi, en français : « Relire la spec demain p1 #Shop » donne le
/// titre « Relire la spec », une échéance, une priorité et une étiquette ; « chaque lundi » ou
/// « tous les jours », une répétition.
///
/// Seule la fin du texte est lue, de droite à gauche, tant que les mots y sont compris : « Préparer
/// la réunion de lundi avec Zoé » garde son « lundi ». Une seule échéance et une seule priorité ;
/// un second mot de date reste dans le titre. Une seule répétition. Le titre garde toujours au moins un mot.
struct QuickEntry: Equatable {
    enum Piece: Equatable {
        case due(Date)
        case priority(Int)
        case tag(String)
        case recurrence(Recurrence)
    }

    var title: String
    /// Ce qui a été compris, dans l'ordre du texte.
    var pieces: [Piece] = []

    var due: Date? {
        for piece in pieces {
            if case .due(let date) = piece { return date }
        }
        return nil
    }

    var priority: Int? {
        for piece in pieces {
            if case .priority(let value) = piece { return value }
        }
        return nil
    }

    var recurrence: Recurrence? {
        for piece in pieces {
            if case .recurrence(let value) = piece { return value }
        }
        return nil
    }

    var tags: [String] {
        pieces.compactMap { piece in
            if case .tag(let name) = piece { return name }
            return nil
        }
    }

    static func parse(_ text: String, now: Date = .now, calendar: Calendar = .current) -> QuickEntry {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        let reader = Reader(today: calendar.startOfDay(for: now), calendar: calendar)
        var end = words.count
        var pieces: [Piece] = []
        reading: while end > 1 {
            // Les groupes les plus longs d'abord (« dans 3 jours » avant « jours ») ; un mot au moins reste.
            for length in stride(from: min(4, end - 1), through: 1, by: -1) {
                guard let piece = reader.piece(Array(words[(end - length)..<end])) else { continue }
                switch piece {
                case .due where pieces.contains(where: { if case .due = $0 { return true } else { return false } }):
                    break reading
                case .priority where pieces.contains(where: { if case .priority = $0 { return true } else { return false } }):
                    break reading
                case .recurrence where pieces.contains(where: { if case .recurrence = $0 { return true } else { return false } }):
                    break reading
                default:
                    pieces.insert(piece, at: 0)
                    end -= length
                    continue reading
                }
            }
            break
        }
        let title = words[0..<end].joined(separator: " ")
        return pieces.isEmpty ? QuickEntry(title: text.trimmingCharacters(in: .whitespacesAndNewlines)) : QuickEntry(title: title, pieces: pieces)
    }

    // MARK: Lecture des mots

    private struct Reader {
        let today: Date
        let calendar: Calendar

        func piece(_ words: [String]) -> Piece? {
            if words.count == 1, let piece = single(words[0]) { return piece }
            let keys = words.map(Self.key)
            if let recurrence = recurrence(keys) { return .recurrence(recurrence) }
            return date(keys).map(Piece.due)
        }

        /// « chaque jour », « tous les jours ouvrés », « chaque lundi », « tous les lundis »,
        /// « chaque lundi et jeudi », « toutes les deux semaines », « chaque mois ».
        private func recurrence(_ words: [String]) -> Recurrence? {
            func weekday(_ word: String) -> Int? {
                Self.weekdays[word] ?? (word.hasSuffix("s") ? Self.weekdays[String(word.dropLast())] : nil)
            }
            switch words {
            case ["chaque", "jour"], ["tous", "les", "jours"]: return .daily
            case ["chaque", "jour", "ouvre"], ["les", "jours", "ouvres"], ["tous", "les", "jours", "ouvres"]: return .weekdays
            case ["chaque", "semaine"], ["toutes", "les", "semaines"]: return .weekly([])
            case ["toutes", "les", "deux", "semaines"], ["toutes", "les", "2", "semaines"]: return .biweekly
            case ["chaque", "mois"], ["tous", "les", "mois"]: return .monthly(0)
            default: break
            }
            if words.count == 2, words[0] == "chaque", let day = weekday(words[1]) { return .weekly([day]) }
            if words.count == 3, words[0] == "tous", words[1] == "les", let day = weekday(words[2]) { return .weekly([day]) }
            if words.count == 4, words[0] == "chaque", words[2] == "et", let first = weekday(words[1]), let second = weekday(words[3]) {
                return .weekly([first, second])
            }
            return nil
        }

        /// Un mot seul : priorité, étiquette, ou jour.
        private func single(_ word: String) -> Piece? {
            let key = Self.key(word)
            if key.count == 2, key.hasPrefix("p"), let value = Int(key.dropFirst()), (1...4).contains(value) {
                return .priority(value)
            }
            if word.hasPrefix("#"), word.count > 1 {
                let name = String(word.dropFirst()).trimmingCharacters(in: CharacterSet(charactersIn: ".,;"))
                return name.isEmpty ? nil : .tag(name)
            }
            return nil
        }

        /// Une date, en un à quatre mots.
        private func date(_ words: [String]) -> Date? {
            switch words.count {
            case 1:
                let word = words[0]
                switch word {
                case "aujourd'hui", "aujourdhui", "auj": return today
                case "demain": return adding(.day, 1)
                case "apres-demain", "apresdemain": return adding(.day, 2)
                default: break
                }
                if let weekday = Self.weekdays[word] { return next(weekday) }
                return numeric(word)
            case 2:
                if let weekday = Self.weekdays[words[0]], words[1] == "prochain" { return next(weekday) }
                if words == ["semaine", "prochaine"] { return next(2) }
                if words == ["mois", "prochain"] { return firstOfNextMonth() }
                if words[0] == "le", let day = Self.dayNumber(words[1]) { return dayOfMonth(day) }
                if let day = Self.dayNumber(words[0]), let month = Self.months[words[1]] { return dated(day, month, year: nil) }
                return nil
            case 3:
                if words[0] == "dans", let count = Self.count(words[1]) {
                    switch words[2] {
                    case "jour", "jours": return adding(.day, count)
                    case "semaine", "semaines": return adding(.day, 7 * count)
                    case "mois": return adding(.month, count)
                    default: return nil
                    }
                }
                if words == ["fin", "du", "mois"] || words == ["fin", "de", "mois"] { return endOfMonth() }
                if words[0] == "le", let day = Self.dayNumber(words[1]), let month = Self.months[words[2]] { return dated(day, month, year: nil) }
                if let day = Self.dayNumber(words[0]), let month = Self.months[words[1]], let year = Self.year(words[2]) {
                    return dated(day, month, year: year)
                }
                return nil
            case 4:
                if words[0] == "le", let day = Self.dayNumber(words[1]), let month = Self.months[words[2]], let year = Self.year(words[3]) {
                    return dated(day, month, year: year)
                }
                return nil
            default:
                return nil
            }
        }

        /// « 12/11 », « 12/11/26 » ou « 12/11/2026 ».
        private func numeric(_ word: String) -> Date? {
            let parts = word.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
            guard (2...3).contains(parts.count), let day = Int(parts[0]), let month = Int(parts[1]) else { return nil }
            var year: Int?
            if parts.count == 3 {
                guard let value = Self.year(parts[2]) else { return nil }
                year = value
            }
            return dated(day, month, year: year)
        }

        private func adding(_ component: Calendar.Component, _ value: Int) -> Date? {
            calendar.date(byAdding: component, value: value, to: today).map { calendar.startOfDay(for: $0) }
        }

        /// Le prochain jour de la semaine voulu, après aujourd'hui (dans 1 à 7 jours).
        private func next(_ weekday: Int) -> Date? {
            let current = calendar.component(.weekday, from: today)
            let delta = (weekday - current + 7) % 7
            return adding(.day, delta == 0 ? 7 : delta)
        }

        private func firstOfNextMonth() -> Date? {
            guard let next = calendar.date(byAdding: .month, value: 1, to: today) else { return nil }
            return calendar.date(from: calendar.dateComponents([.year, .month], from: next))
        }

        private func endOfMonth() -> Date? {
            guard let first = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
                  let next = calendar.date(byAdding: .month, value: 1, to: first) else { return nil }
            return calendar.date(byAdding: .day, value: -1, to: next)
        }

        /// « le 12 » : le 12 de ce mois, ou du mois suivant s'il est passé.
        private func dayOfMonth(_ day: Int) -> Date? {
            let components = calendar.dateComponents([.year, .month], from: today)
            guard let year = components.year, let month = components.month else { return nil }
            if let date = valid(day, month, year), date >= today { return date }
            let nextMonth = month == 12 ? 1 : month + 1
            return valid(day, nextMonth, month == 12 ? year + 1 : year)
        }

        /// Une date sans année tombe cette année, ou l'an prochain si elle est déjà passée.
        private func dated(_ day: Int, _ month: Int, year: Int?) -> Date? {
            if let year { return valid(day, month, year) }
            let current = calendar.component(.year, from: today)
            if let date = valid(day, month, current), date >= today { return date }
            return valid(day, month, current + 1)
        }

        /// La date, seulement si elle existe (pas de 31 avril).
        private func valid(_ day: Int, _ month: Int, _ year: Int) -> Date? {
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
            let check = calendar.dateComponents([.year, .month, .day], from: date)
            guard check.year == year, check.month == month, check.day == day else { return nil }
            return calendar.startOfDay(for: date)
        }

        /// Sans casse ni accents, apostrophe droite, sans point final (« nov. »).
        static func key(_ word: String) -> String {
            var key = word.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_FR"))
                .replacingOccurrences(of: "’", with: "'")
            while key.hasSuffix(".") || key.hasSuffix(",") { key.removeLast() }
            return key
        }

        static func dayNumber(_ word: String) -> Int? {
            if word == "1er" { return 1 }
            guard let value = Int(word), (1...31).contains(value) else { return nil }
            return value
        }

        static func year(_ word: String) -> Int? {
            guard let value = Int(word) else { return nil }
            if word.count == 2 { return 2000 + value }
            return word.count == 4 ? value : nil
        }

        static func count(_ word: String) -> Int? {
            if let value = Int(word), value > 0, value < 1000 { return value }
            let words = ["un": 1, "une": 1, "deux": 2, "trois": 3, "quatre": 4, "cinq": 5, "six": 6, "sept": 7, "huit": 8, "neuf": 9, "dix": 10]
            return words[word]
        }

        /// Jours de la semaine, numérotés comme `Calendar` : 1 pour dimanche.
        static let weekdays = ["dimanche": 1, "lundi": 2, "mardi": 3, "mercredi": 4, "jeudi": 5, "vendredi": 6, "samedi": 7]

        static let months: [String: Int] = [
            "janvier": 1, "janv": 1, "jan": 1,
            "fevrier": 2, "fevr": 2, "fev": 2,
            "mars": 3,
            "avril": 4, "avr": 4,
            "mai": 5,
            "juin": 6,
            "juillet": 7, "juil": 7,
            "aout": 8,
            "septembre": 9, "sept": 9,
            "octobre": 10, "oct": 10,
            "novembre": 11, "nov": 11,
            "decembre": 12, "dec": 12,
        ]
    }
}

extension TaskDraft {
    /// Le brouillon avec ce que la fin du titre indique : le titre sans ces mots, l'échéance et la
    /// priorité lues (elles l'emportent sur celles déjà choisies), les étiquettes lues en plus.
    func applying(_ entry: QuickEntry) -> TaskDraft {
        guard !entry.pieces.isEmpty else { return self }
        var draft = self
        draft.title = entry.title
        if let due = entry.due { draft.due = due }
        if let priority = entry.priority { draft.priority = priority }
        if let recurrence = entry.recurrence { draft.recurrence = recurrence }
        for tag in entry.tags where !draft.tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
            draft.tags.append(tag)
        }
        return draft
    }
}
