import AppKit
import SwiftUI

/// Design system Done v9 (« Verre ») : couleurs en clair et en sombre.
/// Référence : docs/design-system.md et docs/design/Done-Ecrans-v9.html.
enum Theme {
    // Textes
    static let label = dynamic(0x1D1D1F, 0xEEF1F1)
    static let label2 = dynamic(0x5C6367, 0x9AA2A5)
    static let label3 = dynamic(0xA3AAAD, 0x5C6467)

    // Surfaces et verre
    static let surface = dynamic(0xFFFFFF, 0xFFFFFF, lightAlpha: 0.78, darkAlpha: 0.06)
    static let surfaceStroke = dynamic(0x000000, 0xFFFFFF, lightAlpha: 0.06, darkAlpha: 0.07)
    static let surfaceShadow = dynamic(0x003C3C, 0x000000, lightAlpha: 0.05, darkAlpha: 0)
    static let glass = dynamic(0xFFFFFF, 0x262C2E, lightAlpha: 0.52, darkAlpha: 0.48)
    static let glassButton = dynamic(0xFFFFFF, 0xFFFFFF, lightAlpha: 0.62, darkAlpha: 0.10)
    static let glassHighlight = dynamic(0xFFFFFF, 0xFFFFFF, lightAlpha: 0.85, darkAlpha: 0.14)
    static let glassHairline = dynamic(0x000000, 0x000000, lightAlpha: 0.10, darkAlpha: 0)
    static let glassShadow = dynamic(0x002828, 0x000000, lightAlpha: 0.08, darkAlpha: 0.30)
    static let fill = dynamic(0x002828, 0xFFFFFF, lightAlpha: 0.06, darkAlpha: 0.07)
    static let separator = dynamic(0x000000, 0xFFFFFF, lightAlpha: 0.08, darkAlpha: 0.09)
    static let track = dynamic(0x004646, 0xFFFFFF, lightAlpha: 0.12, darkAlpha: 0.12)

    // Accent
    /// Fond des boutons principaux.
    static let accent = dynamic(0x0A7D72, 0x148075)
    /// Anneaux, barres et pastilles de progression.
    static let ring = dynamic(0x0A7D72, 0x2BA597)
    static let accentTint = dynamic(0x0A7D72, 0x2BA597, lightAlpha: 0.12, darkAlpha: 0.18)
    static let accentText = dynamic(0x086A61, 0x73D6C9)
    static let selection = dynamic(0x0A7D72, 0x2BA597, lightAlpha: 0.14, darkAlpha: 0.22)

    // Signaux : contrainte de temps et erreurs.
    static let orangeText = dynamic(0x9A5200, 0xFFB340)
    static let orangeTint = dynamic(0xEB8909, 0xFF9F0A, lightAlpha: 0.12, darkAlpha: 0.16)
    static let redText = dynamic(0xB3261E, 0xFF8A80)
    static let redTint = dynamic(0xD1453B, 0xFF6F61, lightAlpha: 0.12, darkAlpha: 0.16)

    static func priority(_ displayPriority: Int) -> Color {
        switch displayPriority {
        case 1: p1
        case 2: p2
        case 3: p3
        default: p4
        }
    }

    private static let p1 = dynamic(0xD1453B, 0xFF6F61)
    private static let p2 = dynamic(0xEB8909, 0xFF9F0A)
    private static let p3 = dynamic(0x246FE0, 0x5B9BFF)
    private static let p4 = dynamic(0x8E8E93, 0x9A9A9F)

    static func dynamic(_ light: UInt32, _ dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let hex = isDark ? dark : light
            return NSColor(
                srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: isDark ? darkAlpha : lightAlpha
            )
        })
    }
}

// MARK: Polices

/// Plus Jakarta Sans pour les titres, DM Mono pour les chiffres et les étiquettes,
/// DM Sans pour le texte courant. Les fichiers sont dans Done/Fonts, chargés par `FontLoader`.
extension Font {
    enum TextWeight {
        case regular, medium, semibold, bold
    }

    static func display(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom(bold ? "PlusJakartaSans-Bold" : "PlusJakartaSans-SemiBold", fixedSize: size)
    }

    static func mono(_ size: CGFloat, medium: Bool = true) -> Font {
        .custom(medium ? "DMMono-Medium" : "DMMono-Regular", fixedSize: size)
    }

    static func text(_ size: CGFloat, _ weight: TextWeight = .regular) -> Font {
        let name = switch weight {
        case .regular: "DMSans-14pt"
        case .medium: "DMSans-14ptMedium"
        case .semibold: "DMSans-14ptSemiBold"
        case .bold: "DMSans-14ptBold"
        }
        return .custom(name, fixedSize: size)
    }
}

/// Chiffres du minuteur : DM Mono, interlettrage serré.
struct TimerText: View {
    let text: String
    var size: CGFloat = 80
    var color: Color = Theme.label

    var body: some View {
        Text(text)
            .font(.mono(size))
            .tracking(-size * 0.04)
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

/// Étiquette en capitales, en DM Mono : « CANDIDATES », « PAR JOUR ».
struct Eyebrow: View {
    let text: String
    var color: Color = Theme.label2

    var body: some View {
        Text(text.uppercased())
            .font(.mono(11))
            .tracking(0.44)
            .foregroundStyle(color)
    }
}

// MARK: Fonds

/// Fond teinté de la fenêtre, différent selon le moment.
enum BackdropStyle: Equatable {
    /// Navigation : sarcelle léger en haut à gauche.
    case wash
    /// Minuteur en cours : halo sarcelle au centre.
    case session
    /// Fin de session : halo sarcelle plus haut.
    case finished
    /// Pause café : halo sable.
    case rest
    /// Interruption : halo gris.
    case interruption
}

struct Backdrop: View {
    let style: BackdropStyle

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            ZStack {
                base
                switch style {
                case .wash:
                    RadialGradient(colors: [glow(0x14958A, 0.24, 0x2BA597, 0.30), .clear], center: .topLeading, startRadius: 0, endRadius: width * 0.6)
                    RadialGradient(colors: [glow(0x14958A, 0.10, 0x2BA597, 0.10), .clear], center: .bottomTrailing, startRadius: 0, endRadius: width * 0.45)
                case .session:
                    RadialGradient(colors: [glow(0x14958A, 0.30, 0x2BA597, 0.30), .clear], center: UnitPoint(x: 0.5, y: 0.52), startRadius: 0, endRadius: width * 0.45)
                case .finished:
                    RadialGradient(colors: [glow(0x14958A, 0.34, 0x2BA597, 0.36), .clear], center: UnitPoint(x: 0.5, y: 0.35), startRadius: 0, endRadius: width * 0.45)
                case .rest:
                    RadialGradient(colors: [glow(0xD6A85A, 0.28, 0xD6A85A, 0.20), .clear], center: UnitPoint(x: 0.5, y: 0.45), startRadius: 0, endRadius: width * 0.45)
                case .interruption:
                    RadialGradient(colors: [glow(0x6E747C, 0.16, 0x969CA4, 0.14), .clear], center: UnitPoint(x: 0.5, y: 0.35), startRadius: 0, endRadius: width * 0.45)
                }
            }
        }
        .ignoresSafeArea()
    }

    private var base: Color {
        switch style {
        case .wash: Theme.dynamic(0xF2F5F5, 0x111515)
        case .session: Theme.dynamic(0xEBF1F0, 0x0E1313)
        case .finished: Theme.dynamic(0xEDF3F2, 0x0F1414)
        case .rest: Theme.dynamic(0xF6F4EF, 0x15140F)
        case .interruption: Theme.dynamic(0xF1F2F3, 0x131415)
        }
    }

    private func glow(_ light: UInt32, _ lightAlpha: CGFloat, _ dark: UInt32, _ darkAlpha: CGFloat) -> Color {
        Theme.dynamic(light, dark, lightAlpha: lightAlpha, darkAlpha: darkAlpha)
    }
}

// MARK: Verre et surfaces

/// Verre dessiné : flou, voile clair, liseré lumineux et ombre douce.
struct GlassBackground<S: InsettableShape>: View {
    let shape: S
    var fill: Color = Theme.glassButton
    var shadowRadius: CGFloat = 4

    var body: some View {
        shape
            .fill(.ultraThinMaterial)
            .overlay(shape.fill(fill))
            .overlay(shape.strokeBorder(Theme.glassHighlight, lineWidth: 1))
            .overlay(shape.stroke(Theme.glassHairline, lineWidth: 0.5))
            .shadow(color: Theme.glassShadow, radius: shadowRadius, y: shadowRadius / 2)
    }
}

extension View {
    /// Bouton ou pastille en verre (boutons secondaires, pastille de réunion).
    func glassBackground<S: InsettableShape>(_ shape: S, fill: Color = Theme.glassButton) -> some View {
        background { GlassBackground(shape: shape, fill: fill) }
    }

    #if compiler(>=6.2)
    /// Grand panneau en verre (barre d'onglets) : Liquid Glass sur macOS 26, verre dessiné avant.
    @ViewBuilder
    func liquidGlass<S: InsettableShape>(_ shape: S) -> some View {
        if #available(macOS 26.0, *) {
            glassEffect(.regular, in: shape)
                .shadow(color: Theme.glassShadow, radius: 15, y: 8)
        } else {
            drawnGlass(shape)
        }
    }
    #else
    /// Xcode antérieur à la version 26 : verre dessiné uniquement.
    func liquidGlass<S: InsettableShape>(_ shape: S) -> some View {
        drawnGlass(shape)
    }
    #endif

    fileprivate func drawnGlass<S: InsettableShape>(_ shape: S) -> some View {
        background { GlassBackground(shape: shape, fill: Theme.glass, shadowRadius: 15) }
    }

    /// Carte opaque à 78 % (listes, graphiques, réglages).
    func surface(radius: CGFloat = 16) -> some View {
        background(Theme.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.surfaceStroke, lineWidth: 0.5))
            .shadow(color: Theme.surfaceShadow, radius: 8, y: 4)
    }
}

// MARK: Boutons

/// Boutons en pilule : principal (accent), verre (secondaire) ou discret (texte seul).
struct PillButtonStyle: ButtonStyle {
    enum Kind {
        case primary, glass, plain
    }

    enum Size {
        /// 40 pt, actions principales des écrans.
        case regular
        /// 32 pt, barres et panneaux.
        case small
        /// 28 pt, lignes de réglages.
        case mini
    }

    var kind: Kind = .glass
    var size: Size = .regular
    var fullWidth = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.text(fontSize, weight))
            .lineLimit(1)
            .foregroundStyle(foreground)
            .padding(.horizontal, horizontalPadding)
            .frame(height: height)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background {
                switch kind {
                case .primary: Capsule().fill(Theme.accent)
                case .glass: GlassBackground(shape: Capsule())
                case .plain: Color.clear
                }
            }
            .contentShape(Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.45)
    }

    private var height: CGFloat {
        switch size {
        case .regular: 40
        case .small: 32
        case .mini: 28
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .regular: 22
        case .small: 16
        case .mini: 12
        }
    }

    private var fontSize: CGFloat { size == .regular ? 14 : 13 }

    private var weight: Font.TextWeight {
        switch kind {
        case .primary: .semibold
        case .glass: .medium
        case .plain: .regular
        }
    }

    private var foreground: Color {
        switch kind {
        case .primary: .white
        case .glass: Theme.label
        case .plain: Theme.label2
        }
    }
}

/// Bouton rond en verre : rafraîchir, période précédente ou suivante.
struct RoundGlassButtonStyle: ButtonStyle {
    var size: CGFloat = 32

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.label)
            .frame(width: size, height: size)
            .glassBackground(Circle())
            .contentShape(Circle())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Stepper « − | + » en verre des réglages.
struct GlassStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step = 1

    var body: some View {
        HStack(spacing: 0) {
            button("−") { value = max(range.lowerBound, value - step) }
                .disabled(value <= range.lowerBound)
            Rectangle().fill(Theme.separator).frame(width: 1, height: 26)
            button("+") { value = min(range.upperBound, value + step) }
                .disabled(value >= range.upperBound)
        }
        .glassBackground(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func button(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(symbol)
                .font(.text(15))
                .foregroundStyle(Theme.label2)
                .frame(width: 28, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Choix exclusif en verre, segment choisi en accent : onglets des stats, Actif ou En attente.
struct GlassSegmented<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, title: String)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let isOn = selection == option.value
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selection = option.value }
                } label: {
                    Text(option.title)
                        .font(.text(13, isOn ? .semibold : .regular))
                        .foregroundStyle(isOn ? Color.white : Theme.label2)
                        .lineLimit(1)
                        .padding(.horizontal, 18)
                        .frame(height: 26)
                        .background(isOn ? Theme.accent : Color.clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .glassBackground(Capsule())
        .fixedSize()
    }
}

/// Pastille à cocher (projets suivis).
struct Chip: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.text(12, isOn ? .semibold : .regular))
                .foregroundStyle(isOn ? Theme.accentText : Theme.label2)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(isOn ? Theme.accentTint : Theme.fill, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Trait de séparation.
struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(Theme.separator)
            .frame(height: 1)
    }
}

// MARK: Logo et anneaux

/// Icône de l'app : carré arrondi dégradé et anneau blanc.
struct DoneAppIcon: View {
    var size: CGFloat = 90

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2245, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0x16 / 255, green: 0x98 / 255, blue: 0x8C / 255),
                             Color(red: 0x0A / 255, green: 0x7D / 255, blue: 0x72 / 255)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.28), lineWidth: size * 0.092)
                Circle()
                    .trim(from: 0, to: 0.917)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: size * 0.092, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: size * 0.607, height: size * 0.607)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.18), radius: 4, y: 3)
    }
}

/// Anneau de progression : la part restante, partant du haut.
struct ProgressRing: View {
    let fraction: Double
    var color: Color = Theme.ring
    var lineWidth: CGFloat = 14

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, fraction)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: fraction)
        }
        .padding(lineWidth / 2)
    }
}

/// Barre de progression horizontale.
struct ProgressBar: View {
    let fraction: Double
    var color: Color = Theme.ring
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * max(0, min(1, fraction)))
            }
        }
        .frame(height: height)
    }
}

/// Encadré de message : contrainte de temps (orange) ou erreur (rouge).
struct NoticeBox: View {
    enum Tone {
        case warning, error
    }

    let text: String
    var tone: Tone = .warning

    var body: some View {
        Text(text)
            .font(.text(13))
            .foregroundStyle(tone == .warning ? Theme.orangeText : Theme.redText)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(tone == .warning ? Theme.orangeTint : Theme.redTint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
