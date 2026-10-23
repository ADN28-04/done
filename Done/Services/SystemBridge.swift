import AppKit
import PDFKit

/// Appels AppKit utilisés par la logique, regroupés ici.
@MainActor
enum SystemBridge {
    private static var activity: NSObjectProtocol?

    /// Fait rebondir l'icône du Dock quand une session se termine, jusqu'au retour dans Done.
    static func requestAttention() {
        NSApp.requestUserAttention(.criticalRequest)
    }

    /// Son système de macOS (« Glass », « Hero »…), joué par Done lui-même.
    static func playSound(_ name: String) {
        NSSound(named: NSSound.Name(name))?.play()
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

    /// Ouvre les réglages de notifications de Done dans Réglages Système.
    static func openNotificationSettings() {
        let id = Bundle.main.bundleIdentifier ?? ""
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Fenêtre de choix d'un dossier. `nil` si l'utilisateur annule.
    static func chooseFolder(prompt: String) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = prompt
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Fenêtre de choix de fichiers. Vide si l'utilisateur annule.
    static func chooseFiles(prompt: String) -> [URL] {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.prompt = prompt
        return panel.runModal() == .OK ? panel.urls : []
    }

    /// Image prête pour Claude : 2000 px au plus sur le grand côté, en JPEG sur fond blanc.
    /// Une capture d'écran Retina pèse ainsi quelques centaines de Ko au lieu de plusieurs Mo.
    static func preparedImage(at url: URL) -> Data? {
        guard let source = NSImage(contentsOf: url),
              let tiff = source.tiffRepresentation,
              let original = NSBitmapImageRep(data: tiff),
              original.pixelsWide > 0, original.pixelsHigh > 0 else { return nil }
        let scale = min(1, 2_000 / Double(max(original.pixelsWide, original.pixelsHigh)))
        let width = max(1, Int(Double(original.pixelsWide) * scale))
        let height = max(1, Int(Double(original.pixelsHigh) * scale))
        guard let resized = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: resized) else { return nil }
        let rect = NSRect(x: 0, y: 0, width: width, height: height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        NSColor.white.setFill()
        rect.fill()
        _ = original.draw(in: rect)
        NSGraphicsContext.restoreGraphicsState()
        return resized.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
    }

    /// Texte d'un PDF, d'un document Word ou RTF, extrait par macOS (sur le fil principal, comme AppKit le demande).
    static func documentText(at url: URL) -> String? {
        switch url.pathExtension.lowercased() {
        case "pdf":
            return PDFDocument(url: url)?.string
        case "docx":
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [.documentType: NSAttributedString.DocumentType.officeOpenXML]
            return try? NSAttributedString(url: url, options: options, documentAttributes: nil).string
        case "rtf":
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [.documentType: NSAttributedString.DocumentType.rtf]
            return try? NSAttributedString(url: url, options: options, documentAttributes: nil).string
        default:
            return nil
        }
    }

    static func openShortcutsApp() {
        if let url = URL(string: "shortcuts://") {
            NSWorkspace.shared.open(url)
        }
    }
}
