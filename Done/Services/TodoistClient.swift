import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum TodoistError: LocalizedError {
    case unauthorized
    case http(Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unauthorized: "Todoist a refusé ce token. Copie-le à nouveau depuis la page Développeur."
        case .http(let code): "Todoist a répondu avec l'erreur \(code)."
        case .invalidResponse: "Réponse inattendue de Todoist."
        }
    }
}

/// Client minimal de l'API Todoist v1, authentifié par le token personnel.
struct TodoistClient {
    let token: String
    var session: URLSession = .shared

    private static let baseURL = URL(string: "https://api.todoist.com/api/v1/")!

    func tasks() async throws -> [TodoistTask] {
        try await paginated("tasks")
    }

    func projects() async throws -> [TodoistProject] {
        try await paginated("projects")
    }

    /// Tâches cochées entre deux dates. L'API limite la fenêtre à environ trois mois.
    func completedTasks(since: Date, until: Date) async throws -> [TodoistTask] {
        try await paginated("tasks/completed/by_completion_date", query: [
            URLQueryItem(name: "since", value: TodoistDate.apiString(since)),
            URLQueryItem(name: "until", value: TodoistDate.apiString(until)),
        ])
    }

    func closeTask(id: String) async throws {
        var request = try makeRequest(path: "tasks/\(id)/close")
        request.httpMethod = "POST"
        _ = try await send(request)
    }

    private struct Page<Item: Decodable>: Decodable {
        let results: [Item]?
        let items: [Item]?
        let nextCursor: String?

        enum CodingKeys: String, CodingKey {
            case results, items
            case nextCursor = "next_cursor"
        }
    }

    private func paginated<Item: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> [Item] {
        var all: [Item] = []
        var cursor: String?
        // Garde-fou : 50 pages de 200, soit 10 000 éléments.
        for _ in 0..<50 {
            var items = query + [URLQueryItem(name: "limit", value: "200")]
            if let cursor {
                items.append(URLQueryItem(name: "cursor", value: cursor))
            }
            let data = try await send(try makeRequest(path: path, query: items))
            let page = try JSONDecoder().decode(Page<Item>.self, from: data)
            all += page.results ?? page.items ?? []
            guard let next = page.nextCursor, !next.isEmpty else { break }
            cursor = next
        }
        return all
    }

    private func makeRequest(path: String, query: [URLQueryItem] = []) throws -> URLRequest {
        guard var components = URLComponents(url: Self.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw TodoistError.invalidResponse
        }
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else { throw TodoistError.invalidResponse }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20
        return request
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw TodoistError.invalidResponse }
        switch http.statusCode {
        case 200..<300: return data
        case 401, 403: throw TodoistError.unauthorized
        default: throw TodoistError.http(http.statusCode)
        }
    }
}
