import Foundation
#if canImport(Glibc)
import Glibc
#endif

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

    /// Verrou partagé avec le connecteur Claude (`Done --mcp`), qui écrit dans le même fichier.
    var lockURL: URL { folder.appendingPathComponent(".tasks.lock") }

    /// Version du fichier sur le disque. Chaque écriture atomique crée un nouveau fichier : le numéro
    /// change même si deux écritures tombent dans la même seconde.
    struct Stamp: Equatable {
        let fileNumber: UInt64?
        let modified: Date?
        let size: UInt64?
    }

    /// `nil` si le fichier n'existe pas. Change dès que le connecteur Claude a réécrit le fichier.
    func stamp() -> Stamp? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path) else { return nil }
        return Stamp(
            fileNumber: (attributes[.systemFileNumber] as? NSNumber)?.uint64Value,
            modified: attributes[.modificationDate] as? Date,
            size: (attributes[.size] as? NSNumber)?.uint64Value
        )
    }

    /// Réserve le fichier le temps de le relire, le modifier et le réécrire : Done et le connecteur
    /// Claude ne s'écrasent pas l'un l'autre. Pas d'appel imbriqué : le second attendrait le premier.
    /// Si le verrou ne peut pas être pris, `body` s'exécute quand même.
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let descriptor = open(lockURL.path, O_CREAT | O_RDWR, 0o644)
        if descriptor >= 0 { _ = flock(descriptor, LOCK_EX) }
        defer {
            if descriptor >= 0 {
                _ = flock(descriptor, LOCK_UN)
                close(descriptor)
            }
        }
        return try body()
    }

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
