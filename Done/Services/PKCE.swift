import CryptoKit
import Foundation

/// Preuve PKCE de la connexion Microsoft : un vérificateur aléatoire, gardé par Done,
/// et son empreinte SHA-256, envoyée à la page de connexion.
struct PKCE {
    let verifier: String
    let challenge: String

    static func make() -> PKCE {
        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<32).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        let verifier = MicrosoftAuth.base64URL(Data(bytes))
        let challenge = MicrosoftAuth.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        return PKCE(verifier: verifier, challenge: challenge)
    }
}
