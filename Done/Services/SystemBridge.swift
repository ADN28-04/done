import AppKit
import AuthenticationServices

/// Appels AppKit utilisés par la logique, regroupés ici.
@MainActor
enum SystemBridge {
    private static var activity: NSObjectProtocol?
    /// La session de connexion doit rester en mémoire jusqu'à son retour.
    private static var webSession: ASWebAuthenticationSession?

    /// Fait rebondir l'icône du Dock quand une session se termine.
    static func requestAttention() {
        NSApp.requestUserAttention(.informationalRequest)
    }

    static func bringToFront() {
        NSApp.activate()
    }

    static func quit() {
        NSApp.terminate(nil)
    }

    /// Empêche App Nap de ralentir le minuteur quand Done est en arrière-plan.
    static func keepTimerAccurate(_ enabled: Bool) {
        if enabled, activity == nil {
            activity = ProcessInfo.processInfo.beginActivity(
                options: .userInitiatedAllowingIdleSystemSleep,
                reason: "Session de focus en cours"
            )
        } else if !enabled, let current = activity {
            ProcessInfo.processInfo.endActivity(current)
            activity = nil
        }
    }

    static func onTerminate(_ action: @escaping @MainActor () -> Void) {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { action() }
        }
    }

    /// Ouvre une page de connexion dans une feuille Safari et renvoie l'URL de retour.
    /// Lève `CancellationError` si l'utilisateur ferme la feuille.
    static func webSignIn(url: URL, callbackScheme: String) async throws -> URL {
        defer { webSession = nil }
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callback, error in
                if let callback {
                    continuation.resume(returning: callback)
                } else if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    continuation.resume(throwing: CancellationError())
                } else {
                    continuation.resume(throwing: error ?? CancellationError())
                }
            }
            session.presentationContextProvider = WebSignInAnchor.shared
            // Garde la session Microsoft de Safari : pas besoin de retaper son mot de passe.
            session.prefersEphemeralWebBrowserSession = false
            MainActor.assumeIsolated {
                webSession = session
                if !session.start() {
                    continuation.resume(throwing: CancellationError())
                }
            }
        }
    }

    static func openShortcutsApp() {
        if let url = URL(string: "shortcuts://") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// Fenêtre au-dessus de laquelle s'ouvre la feuille de connexion.
private final class WebSignInAnchor: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebSignInAnchor()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) ?? ASPresentationAnchor()
        }
    }
}
