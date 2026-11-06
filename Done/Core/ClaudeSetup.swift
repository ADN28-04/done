import Foundation

/// Inscription de Done comme connecteur dans Claude sur ce Mac : l'app de bureau lit
/// `claude_desktop_config.json`, Claude Code s'inscrit par une commande.
enum ClaudeSetup {
    /// Nom du connecteur dans Claude.
    static let serverName = "done"
    static let arguments = ["--mcp"]

    enum Status: Equatable {
        /// Pas de configuration, ou Done n'y figure pas.
        case missing
        case installed
        /// Done y figure, mais avec un autre emplacement de l'app.
        case outdated
        /// Le fichier n'est pas du JSON lisible : Done n'y touche pas.
        case unreadable
    }

    static func status(of config: Data?, executable: String) -> Status {
        guard let config else { return .missing }
        guard let root = try? JSONDecoder().decode(JSONValue.self, from: config), root.object != nil else { return .unreadable }
        guard let entry = root["mcpServers"]?[serverName] else { return .missing }
        let sameCommand = entry["command"]?.string == executable
        let sameArguments = entry["args"]?.array?.compactMap(\.string) == arguments
        return sameCommand && sameArguments ? .installed : .outdated
    }

    /// La configuration avec Done inscrit ; les autres connecteurs et réglages sont gardés.
    /// `nil` si l'existant n'est pas un objet JSON lisible.
    static func adding(executable: String, to config: Data?) -> Data? {
        var root: [String: JSONValue] = [:]
        if let config, !config.isEmpty {
            guard let object = (try? JSONDecoder().decode(JSONValue.self, from: config))?.object else { return nil }
            root = object
        }
        var servers = root["mcpServers"]?.object ?? [:]
        servers[serverName] = .object([
            "command": .string(executable),
            "args": .array(arguments.map { .string($0) }),
        ])
        root["mcpServers"] = .object(servers)
        return Data((JSONValue.object(root).pretty + "\n").utf8)
    }

    /// La commande qui inscrit Done dans Claude Code, pour tous les dossiers.
    static func claudeCodeCommand(executable: String) -> String {
        let quoted = "'" + executable.replacingOccurrences(of: "'", with: "'\\''") + "'"
        return "claude mcp add --scope user \(serverName) -- \(quoted) \(arguments.joined(separator: " "))"
    }
}
