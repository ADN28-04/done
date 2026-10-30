import Foundation

/// Fichier des tâches : `tasks.json` dans le dossier de Done (Application Support), écrit en entier
/// et de façon atomique à chaque changement. Une copie par jour est gardée dans « Sauvegardes ».
struct TaskStorage {
    let folder: URL

    /// Copies quotidiennes gardées, les plus récentes.
    static let keptBackups = 30

    static var standard: TaskStorage {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return TaskStorage(folder: base.appendingPathComponent(Bundle.main.bundleIdentifier ?? "Done", isDirectory: true))
    }

    var fileURL: URL { folder.appendingPathComponent("tasks.json") }
    var backupFolder: URL { folder.appendingPathComponent("Sauvegardes", isDirectory: true) }

    /// `nil` au premier lancement, quand le fichier n'existe pas encore.
    func load() throws -> TaskStore? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        return try Self.decoder.decode(TaskStore.self, from: data)
    }

    /// Avant la première écriture du jour, l'ancien fichier part dans les sauvegardes.
    func save(_ store: TaskStore, now: Date = .now) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        if manager.fileExists(atPath: fileURL.path) {
            try backUpIfNeeded(now: now)
        }
        try Self.encoder.encode(store).write(to: fileURL, options: .atomic)
    }

    /// Met de côté un fichier illisible, pour qu'il ne soit jamais écrasé. Renvoie son nouvel emplacement.
    func setAsideUnreadable(now: Date = .now) -> URL? {
        let stamp = Format.dayKey(now) + "-" + String(Int(now.timeIntervalSince1970))
        let target = folder.appendingPathComponent("tasks-illisible-\(stamp).json")
        do {
            try FileManager.default.moveItem(at: fileURL, to: target)
            return target
        } catch {
            return nil
        }
    }

    private func backUpIfNeeded(now: Date) throws {
        let manager = FileManager.default
        let target = backupFolder.appendingPathComponent("tasks-\(Format.dayKey(now)).json")
        guard !manager.fileExists(atPath: target.path) else { return }
        try manager.createDirectory(at: backupFolder, withIntermediateDirectories: true)
        try manager.copyItem(at: fileURL, to: target)
        // Les noms contiennent la date : l'ordre alphabétique est l'ordre chronologique.
        let backups = try manager.contentsOfDirectory(atPath: backupFolder.path)
            .filter { $0.hasPrefix("tasks-") && $0.hasSuffix(".json") }
            .sorted()
        for name in backups.dropLast(Self.keptBackups) {
            try? manager.removeItem(at: backupFolder.appendingPathComponent(name))
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
