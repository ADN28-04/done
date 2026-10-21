import Foundation

/// Connexion Microsoft (Entra ID) pour le statut Teams : URL, formats et réponses, sans réseau.
/// Flux « code d'autorisation » avec PKCE, celui des apps de bureau sans secret.
enum MicrosoftAuth {
    /// `openid` donne le jeton d'identité (identifiant de l'utilisateur),
    /// `offline_access` le jeton de renouvellement.
    static let scopes = "openid profile offline_access https://graph.microsoft.com/Presence.ReadWrite"
    static let callbackScheme = "done"
    static let redirectURI = "done://auth"

    /// Annuaire saisi dans les réglages, ou « organizations » (comptes professionnels).
    static func tenant(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "organizations" : trimmed
    }

    /// Page de connexion Microsoft.
    static func authorizeURL(base: URL, tenant: String, clientID: String, challenge: String, state: String) -> URL? {
        var components = URLComponents(url: base.appendingPathComponent("\(tenant)/oauth2/v2.0/authorize"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_mode", value: "query"),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
        ]
        return components?.url
    }

    /// Code d'autorisation lu dans l'URL de retour, après vérification de `state`.
    static func code(from callback: URL, expectedState: String) throws -> String {
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        if let error = value("error") {
            throw TeamsError.signIn(shortDescription(value("error_description") ?? error))
        }
        guard value("state") == expectedState, let code = value("code"), !code.isEmpty else {
            throw TeamsError.signIn("réponse de connexion inattendue")
        }
        return code
    }

    /// Corps `application/x-www-form-urlencoded`, encodé strictement.
    static func formBody(_ fields: [(String, String)]) -> Data {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        let pairs = fields.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")"
        }
        return Data(pairs.joined(separator: "&").utf8)
    }

    /// Base64 sans remplissage, avec `-` et `_` : format des jetons et de PKCE.
    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Identifiant de l'utilisateur (`oid`) lu dans le jeton d'identité.
    static func objectID(fromIDToken token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = parts[1].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload += "=" }
        guard let data = Data(base64Encoded: payload),
              let claims = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return claims["oid"] as? String
    }

    /// Durée du statut « Ne pas déranger » : jusqu'à la fin prévue de la session, plus 5 minutes
    /// de marge. Si Done est quitté sans pouvoir rétablir le statut, Teams le fait seul ensuite.
    static func presenceDuration(until end: Date, now: Date) -> String {
        let minutes = Int((end.timeIntervalSince(now) / 60).rounded(.up)) + 5
        return "PT\(max(5, minutes))M"
    }

    /// Les messages d'erreur Microsoft finissent par des identifiants techniques : on les coupe.
    static func shortDescription(_ message: String) -> String {
        let firstLine = message.components(separatedBy: CharacterSet.newlines).first ?? message
        let withoutTrace = firstLine.components(separatedBy: " Trace ID").first ?? firstLine
        return withoutTrace.trimmingCharacters(in: .whitespaces)
    }

    struct TokenResponse: Decodable {
        let accessToken: String
        let refreshToken: String?
        let expiresIn: Int
        let idToken: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
            case idToken = "id_token"
        }
    }

    struct ErrorResponse: Decodable {
        let error: String
        let errorDescription: String?

        enum CodingKeys: String, CodingKey {
            case error
            case errorDescription = "error_description"
        }
    }
}

enum TeamsError: LocalizedError, Equatable {
    case notConfigured
    case signedOut
    case signIn(String)
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "renseigne l'ID d'application dans Réglages › Statut Teams."
        case .signedOut:
            "la connexion Microsoft a expiré. Reconnecte-toi dans Réglages › Statut Teams."
        case .signIn(let detail):
            "connexion refusée (\(detail))."
        case .http(403):
            "Microsoft refuse le changement de statut (403). La permission Presence.ReadWrite manque peut-être."
        case .http(let code):
            "Microsoft a répondu avec l'erreur \(code)."
        }
    }
}
