import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Observation

/// Passe le statut Teams en « Ne pas déranger » pendant les sessions de focus, via Microsoft Graph,
/// et le remet en automatique ensuite.
///
/// La connexion se fait une fois dans les Réglages, avec une application inscrite dans
/// l'annuaire Microsoft de l'entreprise (voir le README). Le jeton de renouvellement reste
/// dans le trousseau ; le jeton d'accès, valable une heure, seulement en mémoire.
@Observable
@MainActor
final class TeamsStatus {
    static let shared = TeamsStatus()

    @ObservationIgnored var session: URLSession = .shared
    @ObservationIgnored var loginBase = URL(string: "https://login.microsoftonline.com/")!
    @ObservationIgnored var graphBase = URL(string: "https://graph.microsoft.com/v1.0/")!
    /// Reçoit les messages d'erreur à afficher dans l'app.
    @ObservationIgnored var onError: (@MainActor (String) -> Void)?

    private(set) var isSignedIn = Keychain.read(Keychain.microsoftAccount) != nil
    /// État demandé par Done, pas forcément celui affiché dans Teams.
    @ObservationIgnored private(set) var isOn = false
    @ObservationIgnored private var queue: Task<Void, Never>?
    @ObservationIgnored private var accessToken: String?
    @ObservationIgnored private var accessExpiry = Date.distantPast

    private static let userIDKey = "teams.userID"

    // MARK: Sessions

    /// À appeler à chaque changement de phase : « Ne pas déranger » pendant le focus, automatique sinon.
    func update(focusing: Bool, until end: Date?) {
        let wanted = focusing && Rules.current.teamsEnabled && isSignedIn
        guard wanted != isOn else { return }
        isOn = wanted
        let duration = MicrosoftAuth.presenceDuration(until: end ?? .now, now: .now)
        enqueue { [self] in
            if wanted {
                try await setDoNotDisturb(duration: duration)
            } else {
                try await clear()
            }
        }
    }

    /// Attend la fin des appels en cours.
    func settle() async {
        await queue?.value
    }

    /// Remet le statut en automatique quand l'app se ferme, sans attendre plus de 3 secondes.
    /// Sans jeton valide, Teams rétablit seul le statut à l'expiration prévue.
    func clearBeforeExit() {
        guard isOn else { return }
        isOn = false
        guard let accessToken, accessExpiry > .now else { return }
        let request = presenceRequest("clearUserPreferredPresence", token: accessToken, body: nil)
        let done = DispatchSemaphore(value: 0)
        session.dataTask(with: request) { _, _, _ in done.signal() }.resume()
        _ = done.wait(timeout: .now() + 3)
    }

    // MARK: Connexion

    /// Ouvre la page de connexion Microsoft dans une feuille Safari, puis garde les jetons.
    func signIn() async throws {
        let rules = Rules.current
        guard !rules.teamsClientID.isEmpty else { throw TeamsError.notConfigured }
        let tenant = MicrosoftAuth.tenant(rules.teamsTenantID)
        let pkce = PKCE.make()
        let state = UUID().uuidString
        guard let url = MicrosoftAuth.authorizeURL(base: loginBase, tenant: tenant, clientID: rules.teamsClientID, challenge: pkce.challenge, state: state) else {
            throw TeamsError.notConfigured
        }
        let callback = try await SystemBridge.webSignIn(url: url, callbackScheme: MicrosoftAuth.callbackScheme)
        let code = try MicrosoftAuth.code(from: callback, expectedState: state)
        try await exchange(code: code, verifier: pkce.verifier)
    }

    /// Échange le code d'autorisation contre les jetons.
    func exchange(code: String, verifier: String) async throws {
        let rules = Rules.current
        try await requestTokens([
            ("client_id", rules.teamsClientID),
            ("grant_type", "authorization_code"),
            ("code", code),
            ("redirect_uri", MicrosoftAuth.redirectURI),
            ("code_verifier", verifier),
            ("scope", MicrosoftAuth.scopes),
        ])
    }

    func signOut() async {
        if isOn {
            isOn = false
            enqueue { [self] in try await clear() }
            await settle()
        }
        forget()
    }

    /// Passe en « Ne pas déranger » trois secondes, puis rétablit le statut.
    /// Renvoie un message d'erreur, ou `nil` si tout a marché.
    func test() async -> String? {
        guard !isOn else { return "Termine la session en cours avant de tester." }
        do {
            try await setDoNotDisturb(duration: "PT5M")
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            try await clear()
            return nil
        } catch {
            return "Teams : \(error.localizedDescription)"
        }
    }

    // MARK: Interne

    // Les appels partent l'un après l'autre, dans l'ordre demandé.
    private func enqueue(_ work: @escaping @MainActor () async throws -> Void) {
        let previous = queue
        queue = Task {
            await previous?.value
            do {
                try await work()
            } catch {
                self.onError?("Teams : \(error.localizedDescription)")
            }
        }
    }

    private func setDoNotDisturb(duration: String) async throws {
        try await postPresence("setUserPreferredPresence", body: [
            "availability": "DoNotDisturb",
            "activity": "DoNotDisturb",
            "expirationDuration": duration,
        ])
    }

    private func clear() async throws {
        try await postPresence("clearUserPreferredPresence", body: nil)
    }

    private func postPresence(_ action: String, body: [String: String]?, retry: Bool = true) async throws {
        let token = try await validToken()
        let (_, response) = try await session.data(for: presenceRequest(action, token: token, body: body))
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401, retry {
            // Jeton révoqué avant son expiration : on en redemande un, une fois.
            accessToken = nil
            try await postPresence(action, body: body, retry: false)
            return
        }
        guard (200..<300).contains(status) else { throw TeamsError.http(status) }
    }

    private func presenceRequest(_ action: String, token: String, body: [String: String]?) -> URLRequest {
        let user = UserDefaults.standard.string(forKey: Self.userIDKey).map { "users/\($0)" } ?? "me"
        var request = URLRequest(url: graphBase.appendingPathComponent("\(user)/presence/\(action)"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        return request
    }

    private func validToken() async throws -> String {
        if let accessToken, accessExpiry > Date.now.addingTimeInterval(60) { return accessToken }
        guard let refreshToken = Keychain.read(Keychain.microsoftAccount) else { throw TeamsError.signedOut }
        try await requestTokens([
            ("client_id", Rules.current.teamsClientID),
            ("grant_type", "refresh_token"),
            ("refresh_token", refreshToken),
            ("scope", MicrosoftAuth.scopes),
        ])
        guard let accessToken else { throw TeamsError.signedOut }
        return accessToken
    }

    private func requestTokens(_ fields: [(String, String)]) async throws {
        let tenant = MicrosoftAuth.tenant(Rules.current.teamsTenantID)
        var request = URLRequest(url: loginBase.appendingPathComponent("\(tenant)/oauth2/v2.0/token"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = MicrosoftAuth.formBody(fields)
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200, let tokens = try? JSONDecoder().decode(MicrosoftAuth.TokenResponse.self, from: data) else {
            let failure = try? JSONDecoder().decode(MicrosoftAuth.ErrorResponse.self, from: data)
            if failure?.error == "invalid_grant", fields.contains(where: { $0 == ("grant_type", "refresh_token") }) {
                forget()
                throw TeamsError.signedOut
            }
            throw TeamsError.signIn(failure.map { MicrosoftAuth.shortDescription($0.errorDescription ?? $0.error) } ?? "erreur \(status)")
        }
        accessToken = tokens.accessToken
        accessExpiry = Date.now.addingTimeInterval(TimeInterval(tokens.expiresIn))
        if let refreshToken = tokens.refreshToken {
            Keychain.save(refreshToken, account: Keychain.microsoftAccount)
        }
        if let userID = tokens.idToken.flatMap(MicrosoftAuth.objectID(fromIDToken:)) {
            UserDefaults.standard.set(userID, forKey: Self.userIDKey)
        }
        isSignedIn = true
    }

    private func forget() {
        Keychain.delete(Keychain.microsoftAccount)
        UserDefaults.standard.removeObject(forKey: Self.userIDKey)
        accessToken = nil
        accessExpiry = .distantPast
        isOn = false
        isSignedIn = false
    }
}
