import Foundation

/// Charge un fichier joint à une tâche pour l'envoyer à Claude.
enum AttachmentLoader {
    static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "heic", "tiff"]
    static let documentExtensions: Set<String> = ["docx", "rtf"]

    enum Failure: LocalizedError, Equatable {
        case unsupported(String)
        case tooLarge(String)
        case unreadable(String)

        var errorDescription: String? {
            switch self {
            case .unsupported(let name): "« \(name) » : format non lu. Pour Excel ou PowerPoint, exporte en PDF."
            case .tooLarge(let name): "« \(name) » dépasse \(Breakdown.maxPDFBytes / 1_048_576) Mo."
            case .unreadable(let name): "« \(name) » est introuvable ou illisible. Retire-le ou joins-le à nouveau."
            }
        }
    }

    /// Vérification immédiate, au moment de joindre : format et taille.
    static func problem(with url: URL) -> Failure? {
        let name = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        let known = ContextFolder.textExtensions.contains(ext) || documentExtensions.contains(ext) || imageExtensions.contains(ext) || ext == "pdf"
        guard known else { return .unsupported(name) }
        let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        if ext == "pdf", bytes > Breakdown.maxPDFBytes { return .tooLarge(name) }
        return nil
    }

    static func load(_ url: URL) async throws -> Breakdown.Attachment {
        let name = url.lastPathComponent
        if let problem = problem(with: url) { throw problem }
        let ext = url.pathExtension.lowercased()
        if ContextFolder.textExtensions.contains(ext) {
            guard let text = (try? String(contentsOf: url, encoding: .utf8)) ?? (try? String(contentsOf: url, encoding: .isoLatin1)) else {
                throw Failure.unreadable(name)
            }
            return Breakdown.Attachment(name: name, content: .text(text))
        }
        if ext == "pdf" {
            guard let data = try? Data(contentsOf: url) else { throw Failure.unreadable(name) }
            return Breakdown.Attachment(name: name, content: .pdf(data))
        }
        if documentExtensions.contains(ext) {
            guard let text = await SystemBridge.documentText(at: url), !text.isEmpty else { throw Failure.unreadable(name) }
            return Breakdown.Attachment(name: name, content: .text(text))
        }
        guard let jpeg = await SystemBridge.preparedImage(at: url) else { throw Failure.unreadable(name) }
        return Breakdown.Attachment(name: name, content: .image(jpeg, mediaType: "image/jpeg"))
    }
}
