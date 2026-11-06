import Foundation

/// Le fichier de configuration de Claude, l'app de bureau, et l'emplacement de Done à y inscrire.
enum ClaudeConfigFile {
    static var url: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Claude/claude_desktop_config.json")
    }

    /// L'exécutable de Done en cours : celui que Claude lancera avec `--mcp`.
    static var executable: String {
        Bundle.main.executablePath ?? "/Applications/Done.app/Contents/MacOS/Done"
    }

    static func status() -> ClaudeSetup.Status {
        ClaudeSetup.status(of: try? Data(contentsOf: url), executable: executable)
    }

    /// Inscrit Done. L'ancien fichier est gardé à côté (`.bak`) ; un fichier illisible n'est pas touché.
    static func install() throws {
        let manager = FileManager.default
        let existing = try? Data(contentsOf: url)
        guard let merged = ClaudeSetup.adding(executable: executable, to: existing) else {
            throw CocoaError(.fileReadCorruptFile, userInfo: [NSFilePathErrorKey: url.path])
        }
        try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let existing {
            try? existing.write(to: url.appendingPathExtension("bak"), options: .atomic)
        }
        try merged.write(to: url, options: .atomic)
    }
}
