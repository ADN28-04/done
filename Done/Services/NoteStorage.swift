import Foundation

/// Les notes sur le disque : un fichier Markdown par note, dans le dossier « Notes » à côté de
/// tasks.json. Le nom du fichier suit le titre ; une note supprimée part à la corbeille.
struct NoteStorage {
    let folder: URL

    static var standard: NoteStorage {
        NoteStorage(folder: TaskStorage.standard.folder.appendingPathComponent("Notes", isDirectory: true))
    }

    struct Entry {
        let note: Note
        let fileName: String
    }

    /// Toutes les notes du dossier. Un fichier illisible est ignoré, jamais modifié.
    func loadAll() -> [Entry] {
        let manager = FileManager.default
        guard let names = try? manager.contentsOfDirectory(atPath: folder.path) else { return [] }
        return names.filter { $0.hasSuffix(".md") }.compactMap { name in
            let url = folder.appendingPathComponent(name)
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            let modified = (try? manager.attributesOfItem(atPath: url.path)[.modificationDate] as? Date) ?? .now
            let stem = String(name.dropLast(3))
            let note = NoteFormat.parse(text, fallbackID: "fichier-" + stem, fallbackTitle: stem, modified: modified)
            return Entry(note: note, fileName: name)
        }
    }

    /// Écrit la note et renvoie son nom de fichier : « Titre.md », ou « Titre 2.md » si le nom est pris.
    /// Si le titre a changé, le fichier est renommé.
    func save(_ note: Note, currentFile: String?, taken: Set<String>) throws -> String {
        let manager = FileManager.default
        try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        let stem = NoteFormat.fileStem(for: note.title)
        var name: String
        if let currentFile, Self.file(currentFile, matches: stem) {
            name = currentFile
        } else {
            // Le disque du Mac ne distingue pas les majuscules : « Note.md » et « note.md » sont un même fichier.
            let takenNames = Set(taken.map { $0.lowercased() })
            name = "\(stem).md"
            var counter = 2
            while takenNames.contains(name.lowercased()) || (name != currentFile && manager.fileExists(atPath: folder.appendingPathComponent(name).path)) {
                name = "\(stem) \(counter).md"
                counter += 1
            }
        }
        try Data(NoteFormat.serialize(note).utf8).write(to: folder.appendingPathComponent(name), options: .atomic)
        if let currentFile, currentFile != name {
            try? manager.removeItem(at: folder.appendingPathComponent(currentFile))
        }
        return name
    }

    func trash(_ fileName: String) throws {
        let url = folder.appendingPathComponent(fileName)
        #if os(macOS)
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        #else
        try FileManager.default.removeItem(at: url)
        #endif
    }

    /// « Titre.md » ou « Titre 3.md » pour le titre « Titre ».
    static func file(_ name: String, matches stem: String) -> Bool {
        guard name.hasSuffix(".md") else { return false }
        let base = name.dropLast(3)
        if base == stem { return true }
        guard base.hasPrefix(stem + " ") else { return false }
        return Int(base.dropFirst(stem.count + 1)) != nil
    }
}
