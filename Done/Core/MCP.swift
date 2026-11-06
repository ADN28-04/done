import Foundation

/// Un outil proposé à Claude : son nom, ce qu'il fait et le schéma de ses arguments.
struct MCPTool {
    let name: String
    let title: String
    let description: String
    /// Schéma JSON des arguments.
    let schema: JSONValue
    /// Lecture seule : rien ne change dans Done.
    let readOnly: Bool

    var listing: JSONValue {
        [
            "name": .string(name),
            "title": .string(title),
            "description": .string(description),
            "inputSchema": schema,
            "annotations": [
                "title": .string(title),
                "readOnlyHint": .bool(readOnly),
                // Le connecteur ne supprime jamais rien.
                "destructiveHint": false,
                "idempotentHint": .bool(readOnly),
                "openWorldHint": false,
            ],
        ]
    }
}

/// Appel refusé : le message est rendu à Claude, qui peut corriger son appel.
struct ToolFailure: Error, Equatable {
    let message: String

    init(_ message: String) {
        self.message = message
    }
}

/// Serveur MCP (Model Context Protocol) : JSON-RPC 2.0, un message par ligne sur l'entrée et la sortie
/// standard. Pur : il reçoit une ligne et rend la réponse ; lire et écrire les flux se fait ailleurs.
struct MCPServer {
    /// Versions du protocole comprises, la plus récente d'abord.
    static let protocolVersions = ["2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05"]

    let name: String
    let version: String
    /// Mode d'emploi donné à Claude à la connexion.
    let instructions: String
    let tools: [MCPTool]
    /// Exécute un outil. Une `ToolFailure` devient une réponse en erreur, lisible par Claude.
    let call: (String, [String: JSONValue]) throws -> JSONValue

    /// La réponse à une ligne reçue, ou `nil` quand il n'y a rien à répondre (notification).
    func respond(to line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let message = try? JSONValue.parse(trimmed) else {
            return Self.error(id: .null, code: -32700, message: "Message JSON illisible").compact
        }
        if case .array(let batch) = message {
            guard !batch.isEmpty else { return Self.error(id: .null, code: -32600, message: "Lot vide").compact }
            let replies = batch.compactMap { respond(to: $0) }
            return replies.isEmpty ? nil : JSONValue.array(replies).compact
        }
        return respond(to: message)?.compact
    }

    func respond(to message: JSONValue) -> JSONValue? {
        guard let method = message["method"]?.string else {
            // Une réponse du client : Done ne lui envoie jamais de requête, il n'y a rien à faire.
            if message["result"] != nil || message["error"] != nil { return nil }
            return Self.error(id: message["id"] ?? .null, code: -32600, message: "Requête invalide")
        }
        // Sans identifiant, c'est une notification (« notifications/initialized »…) : pas de réponse.
        guard let id = message["id"] else { return nil }
        let params = message["params"]?.object ?? [:]
        switch method {
        case "initialize":
            return Self.result(id: id, initialize(params))
        case "ping":
            return Self.result(id: id, [:])
        case "tools/list":
            return Self.result(id: id, ["tools": .array(tools.map(\.listing))])
        case "tools/call":
            return callTool(id: id, params)
        // Done ne propose ni ressources ni prompts, mais certains clients les demandent quand même.
        case "resources/list":
            return Self.result(id: id, ["resources": []])
        case "resources/templates/list":
            return Self.result(id: id, ["resourceTemplates": []])
        case "prompts/list":
            return Self.result(id: id, ["prompts": []])
        default:
            return Self.error(id: id, code: -32601, message: "Méthode inconnue : \(method)")
        }
    }

    private func initialize(_ params: [String: JSONValue]) -> JSONValue {
        let requested = params["protocolVersion"]?.string ?? ""
        let agreed = Self.protocolVersions.contains(requested) ? requested : Self.protocolVersions[0]
        return [
            "protocolVersion": .string(agreed),
            "capabilities": ["tools": ["listChanged": false]],
            "serverInfo": ["name": .string(name), "title": "Done", "version": .string(version)],
            "instructions": .string(instructions),
        ]
    }

    private func callTool(id: JSONValue, _ params: [String: JSONValue]) -> JSONValue {
        let name = params["name"]?.string ?? ""
        guard tools.contains(where: { $0.name == name }) else {
            return Self.error(id: id, code: -32602, message: "Outil inconnu : \(name)")
        }
        let arguments = params["arguments"]?.object ?? [:]
        do {
            let value = try call(name, arguments)
            return Self.result(id: id, Self.content(value.string ?? value.pretty, isError: false))
        } catch let failure as ToolFailure {
            return Self.result(id: id, Self.content(failure.message, isError: true))
        } catch {
            return Self.result(id: id, Self.content("Erreur : \(error.localizedDescription)", isError: true))
        }
    }

    private static func content(_ text: String, isError: Bool) -> JSONValue {
        ["content": [["type": "text", "text": .string(text)]], "isError": .bool(isError)]
    }

    static func result(id: JSONValue, _ result: JSONValue) -> JSONValue {
        ["jsonrpc": "2.0", "id": id, "result": result]
    }

    static func error(id: JSONValue, code: Int, message: String) -> JSONValue {
        ["jsonrpc": "2.0", "id": id, "error": ["code": .int(code), "message": .string(message)]]
    }
}
