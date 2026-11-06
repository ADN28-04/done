import Foundation
#if canImport(Glibc)
import Glibc
#endif

/// Le connecteur Claude branché sur les fichiers de Done : tasks.json (relu et réécrit sous verrou à
/// chaque modification), le dossier Notes et les fichiers d'échange du plan du jour. Done, s'il est
/// ouvert, voit ces changements et les reprend.
struct ConnectorFiles: ConnectorWorkspace {
    let tasks: TaskStorage
    let notes: NoteStorage
    let plan: PlanFiles
    var defaults: UserDefaults = .standard

    static var standard: ConnectorFiles {
        ConnectorFiles(tasks: .standard, notes: .standard, plan: .standard)
    }

    func loadTasks() throws -> TaskStore {
        do {
            return try tasks.load() ?? TaskStore()
        } catch {
            throw ToolFailure("Le fichier des tâches est illisible (\(error.localizedDescription)). Rien n'y sera écrit : ouvre Done, qui le met de côté.")
        }
    }

    func updateTasks<T>(_ change: (inout TaskStore) throws -> T) throws -> T {
        try tasks.withLock {
            var store = try loadTasks()
            let before = store
            let result = try change(&store)
            if store != before { try tasks.save(store) }
            return result
        }
    }

    /// Comme dans Done : deux fichiers avec le même identifiant, le premier par nom l'emporte.
    func loadNotes() -> [Note] {
        var seen = Set<String>()
        return notes.loadAll()
            .sorted { $0.fileName < $1.fileName }
            .filter { seen.insert($0.note.id).inserted }
            .map(\.note)
    }

    func writeNote(_ note: Note) throws {
        let entries = notes.loadAll().sorted { $0.fileName < $1.fileName }
        let current = entries.first { $0.note.id == note.id }?.fileName
        let taken = Set(entries.filter { $0.note.id != note.id }.map(\.fileName))
        _ = try notes.save(note, currentFile: current, taken: taken)
    }

    func planSnapshot() -> PlanSnapshot? {
        plan.loadSnapshot()
    }

    func planRequest() -> PlanRequest? {
        plan.loadRequest()
    }

    func requestPlan(_ request: PlanRequest) throws {
        try plan.saveRequest(request)
    }

    func resumeNote(for taskID: String) -> String? {
        let saved = defaults.data(forKey: ResumeNotes.defaultsKey).flatMap { try? JSONDecoder().decode(ResumeNotes.self, from: $0) }
        return saved?[taskID]?.text
    }
}

/// Le mode connecteur : `Done --mcp`, lancé par Claude (l'app de bureau ou Claude Code). Lit un message
/// JSON-RPC par ligne sur l'entrée standard et répond sur la sortie standard, jusqu'à ce que Claude
/// ferme la connexion. Pas de fenêtre ni d'icône dans le Dock.
enum ConnectorProcess {
    static func run(workspace: any ConnectorWorkspace = ConnectorFiles.standard) -> Never {
        // Claude parti, une écriture échoue au lieu d'arrêter le programme net.
        signal(SIGPIPE, SIG_IGN)
        let server = ConnectorTools(workspace: workspace).server
        log("Done : connecteur Claude prêt (\(server.tools.count) outils).")
        while let line = readLine(strippingNewline: true) {
            guard let reply = server.respond(to: line) else { continue }
            do {
                try FileHandle.standardOutput.write(contentsOf: Data((reply + "\n").utf8))
            } catch {
                break
            }
        }
        exit(0)
    }

    /// Les messages pour l'humain vont sur la sortie d'erreur : la sortie standard est réservée au protocole.
    static func log(_ message: String) {
        try? FileHandle.standardError.write(contentsOf: Data((message + "\n").utf8))
    }
}
