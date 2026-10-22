import Foundation

/// Dossier de contexte choisi dans les Réglages : les fichiers que Claude peut lire, et leur texte.
/// Done ne lit que ce que Claude demande, au moment du découpage.
struct ContextFolder: Sendable {
    let root: URL

    struct File: Sendable {
        let path: String
        let url: URL
        let isText: Bool
        let bytes: Int
    }

    /// Lus directement en texte.
    static let textExtensions: Set<String> = ["md", "markdown", "txt", "text", "csv", "tsv", "json", "yaml", "yml"]
    /// Texte extrait par macOS (`SystemBridge.documentText`).
    static let documentExtensions: Set<String> = ["pdf", "docx", "rtf"]
    private static let maxFiles = 2_000

    /// Fichiers lisibles, sans les fichiers et dossiers cachés, triés par chemin.
    func files() -> [File] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }
        let rootPath = root.standardizedFileURL.path
        var result: [File] = []
        for case let url as URL in enumerator {
            if result.count >= Self.maxFiles { break }
            let ext = url.pathExtension.lowercased()
            let isText = Self.textExtensions.contains(ext)
            guard isText || Self.documentExtensions.contains(ext),
                  let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else { continue }
            let fullPath = url.standardizedFileURL.path
            let path = fullPath.hasPrefix(rootPath + "/") ? String(fullPath.dropFirst(rootPath.count + 1)) : url.lastPathComponent
            result.append(File(path: path, url: url, isText: isText, bytes: values.fileSize ?? 0))
        }
        return result.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    /// Liste montrée à Claude : chemin, taille et, pour les fichiers texte, la première ligne.
    func entries(of files: [File]) -> [Breakdown.ContextEntry] {
        files.map { file in
            Breakdown.ContextEntry(path: file.path, kilobytes: file.bytes / 1024, firstLine: file.isText ? firstLine(of: file.url) : nil)
        }
    }

    /// Réponse de l'outil read_context_files : le texte des fichiers demandés qui existent.
    func read(_ requested: [String], in files: [File]) async -> String {
        let byPath = Dictionary(files.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
        let paths = Breakdown.allowedPaths(requested, available: Set(byPath.keys))
        guard !paths.isEmpty else { return "Aucun de ces fichiers n'existe dans le dossier. Utilise les chemins de la liste." }
        var excerpts: [String] = []
        for path in paths {
            if let file = byPath[path], let text = await text(of: file), !text.isEmpty {
                excerpts.append(Breakdown.fileExcerpt(path: path, text: text))
            } else {
                excerpts.append("<fichier chemin=\"\(path)\">\n[texte illisible]\n</fichier>")
            }
        }
        return excerpts.joined(separator: "\n\n")
    }

    private func text(of file: File) async -> String? {
        if file.isText {
            return (try? String(contentsOf: file.url, encoding: .utf8)) ?? (try? String(contentsOf: file.url, encoding: .isoLatin1))
        }
        return await SystemBridge.documentText(at: file.url)
    }

    /// Première ligne non vide, sans les marques de titre Markdown.
    private func firstLine(of url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let head = String(decoding: handle.readData(ofLength: 2_048), as: UTF8.self)
        let line = head
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "# \t")) }
            .first { !$0.isEmpty }
        return line.map { String($0.prefix(100)) }
    }
}
