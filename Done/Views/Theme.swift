import AppKit
import SwiftUI

/// Couleurs du design system Done, en clair et en sombre.
enum Theme {
    static let background = dynamic(0xECECEC, 0x1E1E1E)
    static let surface = dynamic(0xFFFFFF, 0x2C2C2E)
    static let field = dynamic(0xFFFFFF, 0x1E1E1E)
    static let label = dynamic(0x1D1D1F, 0xEDEDEF)
    static let label2 = dynamic(0x6E6E73, 0x98989D)
    static let label3 = dynamic(0xAEAEB2, 0x636366)
    /// Fond des boutons secondaires et des lignes survolées.
    static let fill = dynamic(0xE3E3E6, 0x3A3A3C)
    static let track = dynamic(0xDADADE, 0x333335)
    static let separator = dynamic(0xE2E2E5, 0x38383A)
    static let accent = dynamic(0x0A7D72, 0x2BA597)
    static let accentTint = dynamic(0xDAEEEB, 0x163A35)
    static let accentText = dynamic(0x086A61, 0x6FD3C6)
    static let orangeText = dynamic(0x9A5200, 0xFFB340)
    static let orangeTint = dynamic(0xFDF0DF, 0x3A2A12)
    static let redText = dynamic(0xB3261E, 0xFF8A80)
    static let redTint = dynamic(0xFBE7E5, 0x3B1F1D)
    /// Contour des cartes en sombre, où l'ombre ne se voit plus.
    static let cardBorder = dynamic(0xFFFFFF, 0xFFFFFF, lightAlpha: 0, darkAlpha: 0.05)

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

    private static func dynamic(_ light: UInt32, _ dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> Color {
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

// MARK: Typographie

extension Font {
    /// Chiffres du minuteur : SF Pro Rounded, chasse fixe.
    static func timer(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded).monospacedDigit()
    }

    static let caption11 = Font.system(size: 11, weight: .semibold)
}

/// Petite légende en capitales : « TÂCHE 2 SUR 3 · FICHES PRODUIT ».
struct Eyebrow: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption11)
            .tracking(0.66)
            .foregroundStyle(Theme.label2)
    }
}

// MARK: Boutons

/// Bouton en pilule du design system : principal (accent), secondaire (gris) ou discret.
struct PillButtonStyle: ButtonStyle {
    enum Kind {
        case primary, secondary, plain
    }

    var kind: Kind = .secondary
    var fullWidth = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: kind == .primary ? .semibold : .regular))
            .lineLimit(1)
            .foregroundStyle(kind == .primary ? Color.white : Theme.label)
            .padding(.horizontal, 16)
            .frame(height: 32)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(background, in: Capsule())
            .contentShape(Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.45)
    }

    private var background: Color {
        switch kind {
        case .primary: Theme.accent
        case .secondary: Theme.fill
        case .plain: .clear
        }
    }
}

/// Texte d'un bouton avec son raccourci clavier en discret : « Démarrer ↩ ».
struct ShortcutLabel: View {
    let title: String
    let hint: String

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
            Text(hint)
                .font(.system(size: 11, weight: .regular))
                .opacity(0.6)
        }
    }
}

/// Bouton rond de la barre d'outils et des navigations de période.
struct RoundIconButtonStyle: ButtonStyle {
    var size: CGFloat = 28

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.label)
            .frame(width: size, height: size)
            .background(Theme.surface, in: Circle())
            .overlay(Circle().strokeBorder(Theme.separator, lineWidth: 0.5))
            .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: Surfaces

extension View {
    /// Carte principale : fond blanc, coins de 20 pt, ombre douce.
    func cardStyle(padding: CGFloat = 32, radius: CGFloat = 20) -> some View {
        self
            .padding(padding)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.cardBorder, lineWidth: 1))
            .shadow(color: .black.opacity(0.06), radius: 1.5, y: 1)
            .shadow(color: .black.opacity(0.05), radius: 12, y: 8)
    }

    /// Panneau secondaire (listes, graphiques) : coins de 12 pt, sans ombre.
    func panelStyle(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.cardBorder, lineWidth: 1))
    }
}

/// Trait de séparation du design system.
struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(Theme.separator)
            .frame(height: 1)
    }
}

// MARK: Logo et anneaux

/// La marque Done : un anneau de minuteur presque refermé.
struct DoneMark: View {
    var color: Color = Theme.accent
    var lineWidth: CGFloat = 2

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.35), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: 0.875)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
    }
}

/// Icône de l'app : carré arrondi dégradé et anneau blanc.
struct DoneAppIcon: View {
    var size: CGFloat = 84

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
        .shadow(color: .black.opacity(0.18), radius: 3, y: 3)
    }
}

/// Anneau de progression : la part restante, partant du haut.
struct ProgressRing: View {
    let fraction: Double
    var color: Color = Theme.accent
    var lineWidth: CGFloat = 12

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
