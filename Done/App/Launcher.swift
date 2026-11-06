import Foundation

/// Point d'entrée de l'exécutable. `Done --mcp` lance le connecteur Claude, sans fenêtre ni icône
/// dans le Dock ; sinon, l'app.
@main
enum Launcher {
    @MainActor
    static func main() {
        if CommandLine.arguments.contains("--mcp") {
            ConnectorProcess.run()
        }
        DoneApp.main()
    }
}
