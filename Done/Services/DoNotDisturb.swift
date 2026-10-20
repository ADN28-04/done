import Foundation

/// Active « Ne pas déranger » pendant les sessions de focus et le coupe ensuite.
///
/// macOS n'offre pas d'API publique pour piloter les modes de concentration.
/// Done lance donc deux raccourcis de l'app Raccourcis, créés une fois par
/// l'utilisateur, avec la commande `shortcuts run`.
@MainActor
final class DoNotDisturb {
    static let shared = DoNotDisturb()

    struct RunResult {
        let status: Int32
        let output: String
        let error: String

        var succeeded: Bool { status == 0 }
    }

    var executable = URL(fileURLWithPath: "/usr/bin/shortcuts")
    /// Reçoit les messages d'erreur à afficher dans l'app.
    var onError: (@MainActor (String) -> Void)?
    /// État demandé par Done, pas forcément l'état réel du Mac.
    private(set) var isOn = false
    private var queue: Task<Void, Never>?

    /// À appeler à chaque changement de phase : activé pendant le focus, coupé sinon.
    func update(focusing: Bool) {
        let rules = Rules.current
        let wanted = focusing && rules.dndEnabled
        guard wanted != isOn else { return }
        isOn = wanted
        enqueue(wanted ? rules.dndOnShortcut : rules.dndOffShortcut)
    }

    /// Attend la fin des raccourcis en cours, par exemple avant d'envoyer une notification.
    func settle() async {
        await queue?.value
    }

    /// Coupe « Ne pas déranger » de façon synchrone quand l'app se ferme.
    func turnOffBeforeExit() {
        guard isOn else { return }
        isOn = false
        let process = Self.makeProcess(executable, ["run", Rules.current.dndOffShortcut])
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }

    /// Raccourcis introuvables dans l'app Raccourcis. Vide si tout est en place.
    func missingShortcuts() async -> Result<[String], DoNotDisturbError> {
        let rules = Rules.current
        let result = await Self.run(executable, ["list"])
        guard result.succeeded else {
            return .failure(DoNotDisturbError(message: Self.describe(result, command: "shortcuts list")))
        }
        let names = Set(result.output.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) })
        return .success([rules.dndOnShortcut, rules.dndOffShortcut].filter { !names.contains($0) })
    }

    /// Active puis coupe « Ne pas déranger », pour vérifier que les raccourcis marchent.
    /// Renvoie un message d'erreur, ou `nil` si tout s'est bien passé.
    func test() async -> String? {
        let rules = Rules.current
        let on = await Self.run(executable, ["run", rules.dndOnShortcut])
        guard on.succeeded else { return Self.describe(on, command: rules.dndOnShortcut) }
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        let off = await Self.run(executable, ["run", rules.dndOffShortcut])
        return off.succeeded ? nil : Self.describe(off, command: rules.dndOffShortcut)
    }

    // Les raccourcis s'exécutent l'un après l'autre, dans l'ordre demandé.
    private func enqueue(_ name: String) {
        let previous = queue
        let executable = executable
        queue = Task {
            await previous?.value
            let result = await Self.run(executable, ["run", name])
            if !result.succeeded {
                self.onError?(Self.describe(result, command: name))
            }
        }
    }

    nonisolated static func run(_ executable: URL, _ arguments: [String]) async -> RunResult {
        let process = makeProcess(executable, arguments)
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        do {
            try process.run()
        } catch {
            return RunResult(status: -1, output: "", error: error.localizedDescription)
        }
        let out = output.fileHandleForReading.readDataToEndOfFile()
        let err = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return RunResult(
            status: process.terminationStatus,
            output: String(decoding: out, as: UTF8.self),
            error: String(decoding: err, as: UTF8.self)
        )
    }

    nonisolated private static func makeProcess(_ executable: URL, _ arguments: [String]) -> Process {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        return process
    }

    nonisolated private static func describe(_ result: RunResult, command: String) -> String {
        let detail = result.error.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = "Ne pas déranger : « \(command) » n'a pas fonctionné"
        return detail.isEmpty ? base + "." : base + " (\(detail))."
    }
}

struct DoNotDisturbError: Error {
    let message: String
}
