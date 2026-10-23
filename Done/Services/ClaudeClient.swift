import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum ClaudeError: LocalizedError, Equatable {
    case missingKey
    case unauthorized
    case rateLimited
    case overloaded
    case refused
    case truncated
    case badResponse
    case api(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingKey: "aucune clé API. Ajoute-la dans Réglages › Claude."
        case .unauthorized: "la clé API est refusée. Vérifie-la dans Réglages › Claude."
        case .rateLimited: "limite de l'API atteinte. Réessaie dans une minute."
        case .overloaded: "Claude est surchargé. Réessaie dans un instant."
        case .refused: "Claude a refusé de répondre pour cette tâche."
        case .truncated: "la réponse a été coupée avant la fin. Réessaie."
        case .badResponse: "la réponse n'a pas le format attendu. Réessaie."
        case .api(let status, let message): message.isEmpty ? "l'API a répondu avec l'erreur \(status)." : "l'API a répondu avec l'erreur \(status) (\(message))."
        }
    }

    static func from(status: Int, body: [String: Any]?) -> ClaudeError {
        let message = (body?["error"] as? [String: Any])?["message"] as? String ?? ""
        switch status {
        case 401: return .unauthorized
        case 429: return .rateLimited
        case 500...599: return .overloaded
        default: return .api(status, message)
        }
    }
}

/// Appels de l'API Claude (Messages) en HTTP direct : il n'existe pas de SDK Swift officiel.
struct ClaudeClient {
    let apiKey: String
    var model: ClaudeModel = .opus
    var session: URLSession = .shared
    var baseURL = URL(string: "https://api.anthropic.com/v1/")!

    static let apiVersion = "2026-10-21"
    static let fallbackBeta = "server-side-fallback-2026-07-01"

    /// Renvoie à Claude le texte des fichiers demandés par l'outil read_context_files.
    typealias FileReader = @Sendable ([String]) async -> String

    /// Vérifie la clé avec un appel gratuit (liste des modèles).
    func checkKey() async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("models"))
        setHeaders(&request, beta: false)
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw ClaudeError.from(status: status, body: (try? JSONSerialization.jsonObject(with: data)) as? [String: Any])
        }
    }

    /// Demande le découpage complet d'une tâche. Claude peut d'abord lire des fichiers du dossier de contexte.
    /// `userContent` : blocs du premier message (pièces jointes, puis la tâche).
    func suggestPlan(system: String, userContent: [[String: Any]], offersFiles: Bool, readFiles: FileReader) async throws -> Breakdown.Plan {
        var messages: [[String: Any]] = [["role": "user", "content": userContent]]
        for round in 1...Breakdown.maxRounds {
            // Au dernier tour, plus de lecture : Claude doit répondre avec ce qu'il a.
            let response = try await send(system: system, messages: messages, offersFiles: offersFiles, lastRound: round == Breakdown.maxRounds)
            let content = response["content"] as? [[String: Any]] ?? []
            switch response["stop_reason"] as? String {
            case "tool_use":
                var results: [[String: Any]] = []
                for call in content where call["type"] as? String == "tool_use" {
                    let id = call["id"] as? String ?? ""
                    if call["name"] as? String == "read_context_files" {
                        let paths = (call["input"] as? [String: Any])?["paths"] as? [String] ?? []
                        results.append(["type": "tool_result", "tool_use_id": id, "content": await readFiles(paths)])
                    } else {
                        results.append(["type": "tool_result", "tool_use_id": id, "content": "Outil inconnu.", "is_error": true])
                    }
                }
                // Le contenu de Claude repart tel quel, blocs de réflexion compris.
                messages.append(["role": "assistant", "content": content])
                messages.append(["role": "user", "content": results])
            case "end_turn", "stop_sequence":
                let text = content
                    .filter { $0["type"] as? String == "text" }
                    .compactMap { $0["text"] as? String }
                    .joined()
                guard let plan = Breakdown.parse(text) else { throw ClaudeError.badResponse }
                return plan
            case "refusal":
                throw ClaudeError.refused
            case "max_tokens":
                throw ClaudeError.truncated
            default:
                throw ClaudeError.badResponse
            }
        }
        throw ClaudeError.badResponse
    }

    private func send(system: String, messages: [[String: Any]], offersFiles: Bool, lastRound: Bool) async throws -> [String: Any] {
        var body: [String: Any] = [
            "model": model.rawValue,
            "max_tokens": 16_000,
            "system": system,
            "messages": messages,
            "output_config": [
                "effort": "medium",
                "format": ["type": "json_schema", "schema": Breakdown.outputSchema],
            ],
            // Les allers-retours d'un même découpage relisent la même consigne : cache automatique.
            "cache_control": ["type": "ephemeral"],
        ]
        if offersFiles {
            body["tools"] = [Breakdown.readFilesTool]
            if lastRound { body["tool_choice"] = ["type": "none"] }
        }
        if model.supportsFallbacks {
            body["fallbacks"] = "default"
        }
        var request = URLRequest(url: baseURL.appendingPathComponent("messages"))
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        setHeaders(&request, beta: model.supportsFallbacks)
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        // Clés triées : la même demande donne les mêmes octets, ce qui garde le cache valide.
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard status == 200, let json else { throw ClaudeError.from(status: status, body: json) }
        return json
    }

    private func setHeaders(_ request: inout URLRequest, beta: Bool) {
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        if beta {
            request.setValue(Self.fallbackBeta, forHTTPHeaderField: "anthropic-beta")
        }
    }
}
