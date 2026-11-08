import SwiftUI

/// Aperçu d'une note : titres, paragraphes, listes, cases à cocher (cliquables), citations, code et
/// filets. [[Titre]] devient un lien vers la note du même titre.
struct MarkdownView: View {
    let text: String
    /// Indice de ligne de la case cliquée.
    var onToggle: (Int) -> Void = { _ in }
    /// Titre d'un lien [[Titre]] cliqué.
    var onOpenLink: (String) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: DoneSpace.s8) {
            ForEach(Array(MarkdownBlocks.parse(text).enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tint(DoneColor.stateActiveText)
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == Self.scheme else { return .systemAction }
            let encoded = String(url.absoluteString.dropFirst(Self.scheme.count + 1))
            onOpenLink(encoded.removingPercentEncoding ?? encoded)
            return .handled
        })
    }

    @ViewBuilder
    private func view(for block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(Self.inline(text))
                .doneText(level == 1 ? .displayM : (level == 2 ? .title : .bodyStrong))
                .foregroundStyle(DoneColor.textPrimary)
                .padding(.top, level == 1 ? DoneSpace.s8 : DoneSpace.s4)
        case .paragraph(let text):
            Text(Self.inline(text))
                .doneText(.body)
                .foregroundStyle(DoneColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        case .bullet(let indent, let text):
            HStack(alignment: .firstTextBaseline, spacing: DoneSpace.s8) {
                Text(indent == 0 ? "•" : "◦")
                    .foregroundStyle(DoneColor.textSecondary)
                Text(Self.inline(text))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .doneText(.body)
            .foregroundStyle(DoneColor.textPrimary)
            .padding(.leading, CGFloat(indent) * 18)
        case .numbered(let number, let indent, let text):
            HStack(alignment: .firstTextBaseline, spacing: DoneSpace.s8) {
                Text("\(number).")
                    .font(.done(.numericM))
                    .foregroundStyle(DoneColor.textSecondary)
                Text(Self.inline(text))
                    .doneText(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(DoneColor.textPrimary)
            .padding(.leading, CGFloat(indent) * 18)
        case .task(let checked, let indent, let text, let line):
            HStack(alignment: .firstTextBaseline, spacing: DoneSpace.s8) {
                TaskCheckbox(isDone: checked) { onToggle(line) }
                    // Case de 18 centrée sur la hauteur des capitales du texte.
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 4 }
                Text(Self.inline(text))
                    .doneText(.body)
                    .strikethrough(checked, color: DoneColor.stateOnDone)
                    .foregroundStyle(checked ? DoneColor.textSecondary : DoneColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, CGFloat(indent) * 18)
        case .quote(let text):
            HStack(spacing: DoneSpace.s12) {
                Rectangle()
                    .fill(DoneColor.borderDefault)
                    .frame(width: 3)
                Text(Self.inline(text))
                    .doneText(.body)
                    .foregroundStyle(DoneColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .fixedSize(horizontal: false, vertical: true)
        case .code(let code):
            Text(code)
                .font(.sans(13))
                .foregroundStyle(DoneColor.textPrimary)
                .textSelection(.enabled)
                .padding(DoneSpace.s12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DoneColor.bgSunken, in: RoundedRectangle(cornerRadius: DoneRadius.sm, style: .continuous))
        case .rule:
            Hairline()
                .padding(.vertical, DoneSpace.s4)
        }
    }

    private static let scheme = "done-note"

    /// Mise en forme en ligne (gras, italique, code, liens) ; [[Titre]] devient un lien vers la note.
    static func inline(_ text: String) -> AttributedString {
        var converted = ""
        var rest = text[...]
        while let open = rest.range(of: "[["), let close = rest.range(of: "]]", range: open.upperBound..<rest.endIndex) {
            converted += rest[..<open.lowerBound]
            let title = rest[open.upperBound..<close.lowerBound]
            let encoded = title.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
            converted += "[\(title)](\(scheme):\(encoded))"
            rest = rest[close.upperBound...]
        }
        converted += rest
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: converted, options: options)) ?? AttributedString(text)
    }
}
