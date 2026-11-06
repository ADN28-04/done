import Foundation

/// Le plan du jour échangé avec le connecteur Claude, dans le dossier de Done : `plan.json`, publié par
/// l'app à chaque changement, et `plan-request.json`, déposé par le connecteur et effacé par l'app une
/// fois appliqué. Le plan lui-même reste dans la base locale, que seul Done ouvre.
struct PlanFiles {
    let folder: URL

    static var standard: PlanFiles { PlanFiles(folder: TaskStorage.standard.folder) }

    var snapshotURL: URL { folder.appendingPathComponent("plan.json") }
    var requestURL: URL { folder.appendingPathComponent("plan-request.json") }

    func loadSnapshot() -> PlanSnapshot? {
        read(PlanSnapshot.self, at: snapshotURL)
    }

    /// N'écrit que si le plan a changé : chaque écriture réveille la surveillance du dossier.
    func publish(_ snapshot: PlanSnapshot) throws {
        guard loadSnapshot() != snapshot else { return }
        try write(snapshot, to: snapshotURL)
    }

    func loadRequest() -> PlanRequest? {
        read(PlanRequest.self, at: requestURL)
    }

    func saveRequest(_ request: PlanRequest) throws {
        try write(request, to: requestURL)
    }

    /// La demande en attente, effacée au passage (illisible, elle est effacée aussi).
    func takeRequest() -> PlanRequest? {
        guard FileManager.default.fileExists(atPath: requestURL.path) else { return nil }
        let request = loadRequest()
        try? FileManager.default.removeItem(at: requestURL)
        return request
    }

    private func read<T: Decodable>(_ type: T.Type, at url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }

    private func write<T: Encodable>(_ value: T, to url: URL) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(value).write(to: url, options: .atomic)
    }
}
