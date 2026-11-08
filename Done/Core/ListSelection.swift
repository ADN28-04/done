import Foundation

/// Sélection au clavier dans une liste de tâches : ↑ et ↓ passent d'une ligne à l'autre, et quand
/// la ligne choisie quitte la liste (cochée, déplacée), la sélection reste à la même hauteur.
enum ListSelection {
    /// La ligne d'à côté ; sans sélection, la première (↓) ou la dernière (↑). Reste au bord.
    static func step(_ selected: String?, by offset: Int, in ids: [String]) -> String? {
        guard !ids.isEmpty else { return nil }
        guard let selected, let index = ids.firstIndex(of: selected) else {
            return offset < 0 ? ids.last : ids.first
        }
        return ids[min(max(index + offset, 0), ids.count - 1)]
    }

    /// La sélection après un changement de la liste : la même ligne si elle y est encore, sinon celle
    /// qui a pris sa place.
    static func keep(_ selected: String?, old: [String], new: [String]) -> String? {
        guard let selected else { return nil }
        if new.contains(selected) { return selected }
        guard !new.isEmpty else { return nil }
        let index = old.firstIndex(of: selected) ?? 0
        return new[min(index, new.count - 1)]
    }
}
