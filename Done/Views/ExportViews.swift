import SwiftUI
import UniformTypeIdentifiers

/// Fichier d'export des tâches (`TaskExport`), enregistré par le panneau du système depuis
/// Réglages › Données.
struct ExportDocument: FileDocument {
    static let markdown = UTType(filenameExtension: "md", conformingTo: .plainText) ?? .plainText
    static var readableContentTypes: [UTType] { [markdown, .commaSeparatedText, .plainText] }

    let kind: TaskExport.Kind
    let text: String

    init(kind: TaskExport.Kind, text: String) {
        self.kind = kind
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        kind = configuration.contentType.conforms(to: .commaSeparatedText) ? .csv : .markdown
        text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self)
    }

    var contentType: UTType {
        switch kind {
        case .markdown: Self.markdown
        case .csv: .commaSeparatedText
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
