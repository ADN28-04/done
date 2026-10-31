import AppKit
import SwiftUI

// MARK: Couleurs

/// Design system Done v4 : couleurs nommées par rôle, en clair et en sombre.
/// Référence : docs/design-system.md et docs/design/Done-Design-System-v4.html.
/// Le code ne référence jamais une couleur de marque (Pierre, Encre, Indigo…) directement.
enum DoneColor {
    // Fonds et surfaces
    static let bgCanvas = dynamic(0xF5F3EF, 0x1A1917)
    static let bgSunken = dynamic(0xEEEBE5, 0x161513)
    static let surfaceDefault = dynamic(0xFBFAF7, 0x22201D)
    static let surfaceHover = dynamic(0xF1EEE8, 0x2A2825)
    static let surfaceSelected = dynamic(0xE6E8F4, 0x2A2E4A)

    // Bordures
    static let borderSubtle = dynamic(0xE1DCD3, 0x35322D)
    static let borderDefault = dynamic(0xCFC8BC, 0x45413B)
    static let borderControl = dynamic(0x8D857A, 0x8A8379)

    // Textes
    static let textPrimary = dynamic(0x26231F, 0xE8E4DD)
    static let textSecondary = dynamic(0x6B645A, 0xA39C91)
    static let textDisabled = dynamic(0xB2ABA0, 0x5E5951)

    // Actions
    static let actionPrimary = dynamic(0x4553A0, 0x5A68C0)
    static let actionPrimaryHover = dynamic(0x3A4690, 0x5260B8)
    static let actionPrimaryPressed = dynamic(0x313B7C, 0x4A57A8)
    static let actionOnPrimary = dynamic(0xFFFFFF, 0xFFFFFF)
    static let actionDisabled = dynamic(0xE9E5DE, 0x2B2925)
    static let focusRing = dynamic(0x4553A0, 0xAAB4F2)

    // États
    static let stateActive = dynamic(0x4F5CB0, 0x5A68C0)
    static let stateOnActive = dynamic(0xFFFFFF, 0xFFFFFF)
    static let stateActiveText = dynamic(0x3A4690, 0xAAB4F2)
    static let stateActiveTint = dynamic(0xE6E8F4, 0x262A42)
    static let stateBlocked = dynamic(0xE9E5DE, 0x2B2925)
    static let stateOnBlocked = dynamic(0x26231F, 0xE8E4DD)
    static let stateWaiting = dynamic(0x8D857A, 0x8A8379)
    static let stateRisk = dynamic(0xC2463F, 0xE06A63)
    static let stateRiskTint = dynamic(0xF6E3E1, 0x3A2321)
    static let stateRiskText = dynamic(0xA3332E, 0xF0A29D)
    static let stateDone = dynamic(0xEEEBE5, 0x1F1E1B)
    static let stateOnDone = dynamic(0x6B645A, 0xA39C91)

    // Réunions
    static let meetingBg = dynamic(0xEFECE6, 0x24221F)
    static let meetingHatch = dynamic(0x4553A0, 0xAAB4F2, lightAlpha: 0.14, darkAlpha: 0.14)
    static let meetingNow = dynamic(0x4553A0, 0x5A68C0)
    static let meetingOnNow = dynamic(0xFFFFFF, 0xFFFFFF)

    // Pomodoro
    static let pomodoroFocus = dynamic(0x4553A0, 0x8F9BE8)
    static let pomodoroBreak = dynamic(0x6F7BC2, 0xAAB4F2)
    static let pomodoroBreakBg = dynamic(0xECEEF7, 0x1F2133)
    static let pomodoroTrack = dynamic(0xE6E2DA, 0x35322D)
    static let pomodoroPaused = dynamic(0xB2ABA0, 0x5E5951)

    // Ombres : discrètes en clair, en sombre les contours font le travail.
    static let shadowCard = dynamic(0x26231F, 0x000000, lightAlpha: 0.06, darkAlpha: 0.35)
    static let shadowRaised = dynamic(0x26231F, 0x000000, lightAlpha: 0.10, darkAlpha: 0.45)
    static let shadowRaisedNear = dynamic(0x26231F, 0x000000, lightAlpha: 0.06, darkAlpha: 0.30)

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

// MARK: Mesures

/// Espacements : grille de 4, avec 2 et 6 pour les détails.
enum DoneSpace {
    static let s2: CGFloat = 2
    static let s4: CGFloat = 4
    static let s6: CGFloat = 6
    static let s8: CGFloat = 8
    static let s12: CGFloat = 12
    static let s16: CGFloat = 16
    static let s20: CGFloat = 20
    static let s24: CGFloat = 24
    static let s32: CGFloat = 32
    static let s40: CGFloat = 40
    static let s48: CGFloat = 48
    static let s64: CGFloat = 64
}

/// Rayons : petits et nets, Done est un outil de précision.
enum DoneRadius {
    /// Puces d'état, de durée, de date.
    static let xs: CGFloat = 3
    /// Boutons, champs, réunions, navigation.
    static let sm: CGFloat = 6
    /// Lignes de tâche, cartes.
    static let md: CGFloat = 10
    /// Panneaux, feuilles.
    static let lg: CGFloat = 14
}

// MARK: Typographie

/// Échelle typographique : Instrument Sans pour les titres et le texte, IBM Plex Mono pour les heures,
/// les durées et le minuteur (chiffres de même largeur). Fichiers dans Done/Fonts, chargés par `FontLoader`.
enum DoneTextStyle {
    /// 44/48, titre d'écran majeur (l'action proposée).
    case displayXL
    /// 32/36, titre d'écran.
    case displayL
    /// 22/28, titre de section, de feuille.
    case displayM
    /// 17/24, titre de panneau.
    case title
    /// 14/20, texte courant.
    case body
    /// 14/20 Medium, titre de tâche.
    case bodyStrong
    /// 13/18, texte d'appoint.
    case callout
    /// 12/16, métadonnées.
    case caption
    /// 11/14 SemiBold, capitales espacées.
    case label
    /// 56/60, minuteur.
    case numericXL
    /// 28/32, totaux.
    case numericL
    /// 14/20, heures et durées en ligne.
    case numericM
    /// 12/16, puces de durée et de date.
    case numericS

    var size: CGFloat {
        switch self {
        case .displayXL: 44
        case .displayL: 32
        case .displayM: 22
        case .title: 17
        case .body, .bodyStrong, .numericM: 14
        case .callout: 13
        case .caption, .numericS: 12
        case .label: 11
        case .numericXL: 56
        case .numericL: 28
        }
    }

    var lineHeight: CGFloat {
        switch self {
        case .displayXL: 48
        case .displayL: 36
        case .displayM: 28
        case .title: 24
        case .body, .bodyStrong, .numericM: 20
        case .callout: 18
        case .caption, .numericS: 16
        case .label: 14
        case .numericXL: 60
        case .numericL: 32
        }
    }

    /// Interlettrage, en em.
    var tracking: CGFloat {
        switch self {
        case .displayXL: -0.025
        case .displayL, .numericXL: -0.02
        case .displayM, .numericL: -0.01
        case .label: 0.06
        default: 0
        }
    }

    var fontName: String {
        switch self {
        case .displayXL, .displayL, .displayM, .title, .label: "InstrumentSans-SemiBold"
        case .bodyStrong: "InstrumentSans-Medium"
        case .body, .callout, .caption: "InstrumentSans-Regular"
        case .numericL: "IBMPlexMono-SemiBold"
        case .numericXL, .numericM, .numericS: "IBMPlexMono-Medium"
        }
    }

    var font: Font { .custom(fontName, fixedSize: size) }
}

extension Font {
    enum TextWeight {
        case regular, medium, semibold
    }

    enum MonoWeight {
        case medium, semibold
    }

    static func done(_ style: DoneTextStyle) -> Font { style.font }

    /// Instrument Sans hors échelle : boutons, navigation active.
    static func sans(_ size: CGFloat, _ weight: TextWeight = .regular) -> Font {
        let name = switch weight {
        case .regular: "InstrumentSans-Regular"
        case .medium: "InstrumentSans-Medium"
        case .semibold: "InstrumentSans-SemiBold"
        }
        return .custom(name, fixedSize: size)
    }

    /// IBM Plex Mono hors échelle : chiffres isolés (numéros du plan).
    static func mono(_ size: CGFloat, _ weight: MonoWeight = .medium) -> Font {
        .custom(weight == .medium ? "IBMPlexMono-Medium" : "IBMPlexMono-SemiBold", fixedSize: size)
    }
}

extension View {
    /// Style de texte du design system : police, interlignage, interlettrage et capitales.
    func doneText(_ style: DoneTextStyle) -> some View {
        font(style.font)
            .tracking(style.size * style.tracking)
            .lineSpacing(max(0, style.lineHeight - style.size * 1.3))
            .textCase(style == .label ? Text.Case.uppercase : nil)
    }
}

/// Chiffres du minuteur : numeric.xl par défaut.
struct TimerText: View {
    let text: String
    var style: DoneTextStyle = .numericXL
    var color: Color = DoneColor.textPrimary

    var body: some View {
        Text(text)
            .doneText(style)
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

/// Étiquette en capitales (style label) : « CANDIDATES », « ENSUITE ».
struct Eyebrow: View {
    let text: String
    var color: Color = DoneColor.textSecondary

    var body: some View {
        Text(text)
            .doneText(.label)
            .foregroundStyle(color)
    }
}

// MARK: Surfaces

extension View {
    /// Carte : surface, liseré border.subtle et ombre shadow.card.
    func doneCard(radius: CGFloat = DoneRadius.md) -> some View {
        background(DoneColor.surfaceDefault, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(DoneColor.borderSubtle, lineWidth: 1))
            .shadow(color: DoneColor.shadowCard, radius: 1, y: 1)
    }

    /// Carte surélevée (shadow.raised) : carte de fin de pomodoro, carte survolée.
    func doneRaised(radius: CGFloat = DoneRadius.lg) -> some View {
        background(DoneColor.surfaceDefault, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(DoneColor.borderSubtle, lineWidth: 1))
            .shadow(color: DoneColor.shadowRaised, radius: 14, y: 12)
            .shadow(color: DoneColor.shadowRaisedNear, radius: 3, y: 2)
    }

    /// Champ de saisie : hauteur 32, rayon 6, contour border.control, contour Indigo de 2 au focus.
    func doneField(focused: Bool, height: CGFloat? = 32) -> some View {
        textFieldStyle(.plain)
            .font(.done(.body))
            .foregroundStyle(DoneColor.textPrimary)
            .padding(.horizontal, DoneSpace.s8)
            .frame(height: height)
            .background(DoneColor.surfaceDefault, in: RoundedRectangle(cornerRadius: DoneRadius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DoneRadius.sm, style: .continuous)
                    .strokeBorder(focused ? DoneColor.focusRing : DoneColor.borderControl, lineWidth: focused ? 2 : 1)
            )
    }
}

/// Trait de séparation (border.hairline).
struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(DoneColor.borderSubtle)
            .frame(height: 1)
    }
}

/// Hachures « temps pris » : traits à 45° tous les 6 points, sur le fond de réunion.
struct Hatching: View {
    var color: Color = DoneColor.meetingHatch

    var body: some View {
        Canvas { context, size in
            var path = Path()
            var x = -size.height
            while x < size.width {
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += 6
            }
            context.stroke(path, with: .color(color), lineWidth: 1.5)
        }
        .allowsHitTesting(false)
    }
}

// MARK: Boutons

/// Boutons : hauteur 32, rayon 6, padding 14. Un seul principal par vue.
struct DoneButtonStyle: ButtonStyle {
    enum Kind {
        /// Indigo en clair, Indigo 400 en sombre.
        case primary
        /// Contour border.control.
        case secondary
        /// Texte seul, discret.
        case plain
    }

    var kind: Kind = .secondary
    var fullWidth = false
    /// 26 de haut, pour les lignes de réglages et les puces d'action.
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        DoneButtonBody(configuration: configuration, kind: kind, fullWidth: fullWidth, compact: compact)
    }
}

private struct DoneButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let kind: DoneButtonStyle.Kind
    let fullWidth: Bool
    let compact: Bool

    @Environment(\.isEnabled) private var isEnabled
    @State private var hovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DoneRadius.sm, style: .continuous)
        configuration.label
            .font(.sans(compact ? 13 : 14, kind == .primary ? .semibold : .medium))
            .lineLimit(1)
            .foregroundStyle(foreground)
            .padding(.horizontal, kind == .plain ? 8 : (compact ? 10 : 14))
            .frame(height: compact ? 26 : 32)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(background, in: shape)
            .overlay {
                if kind == .secondary {
                    shape.strokeBorder(isEnabled ? DoneColor.borderControl : DoneColor.borderSubtle, lineWidth: 1)
                }
            }
            .contentShape(shape)
            .onHover { hovered = $0 }
    }

    private var background: Color {
        switch kind {
        case .primary:
            guard isEnabled else { return DoneColor.actionDisabled }
            if configuration.isPressed { return DoneColor.actionPrimaryPressed }
            return hovered ? DoneColor.actionPrimaryHover : DoneColor.actionPrimary
        case .secondary:
            guard isEnabled else { return .clear }
            return configuration.isPressed || hovered ? DoneColor.surfaceHover : DoneColor.surfaceDefault
        case .plain:
            return configuration.isPressed ? DoneColor.surfaceHover : .clear
        }
    }

    private var foreground: Color {
        guard isEnabled else { return DoneColor.textDisabled }
        switch kind {
        case .primary: return DoneColor.actionOnPrimary
        case .secondary: return DoneColor.textPrimary
        case .plain: return hovered ? DoneColor.textPrimary : DoneColor.textSecondary
        }
    }
}

/// Bouton carré à icône, 32 × 32 : nouvelle tâche, semaine précédente ou suivante.
struct DoneIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        DoneIconButtonBody(configuration: configuration)
    }
}

private struct DoneIconButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DoneRadius.sm, style: .continuous)
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isEnabled ? DoneColor.textPrimary : DoneColor.textDisabled)
            .frame(width: 32, height: 32)
            .background(isEnabled && (hovered || configuration.isPressed) ? DoneColor.surfaceHover : DoneColor.surfaceDefault, in: shape)
            .overlay(shape.strokeBorder(isEnabled ? DoneColor.borderControl : DoneColor.borderSubtle, lineWidth: 1))
            .contentShape(shape)
            .onHover { hovered = $0 }
    }
}

/// Stepper « − | + » des réglages.
struct DoneStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step = 1

    var body: some View {
        HStack(spacing: DoneSpace.s4) {
            Button("−") { value = max(range.lowerBound, value - step) }
                .disabled(value <= range.lowerBound)
            Button("+") { value = min(range.upperBound, value + step) }
                .disabled(value >= range.upperBound)
        }
        .buttonStyle(DoneButtonStyle(kind: .secondary, compact: true))
    }
}

/// Choix exclusif : piste bg.sunken, segment choisi sur une surface.
struct DoneSegmented<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, title: String)]

    var body: some View {
        HStack(spacing: DoneSpace.s2) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let isOn = selection == option.value
                Button {
                    selection = option.value
                } label: {
                    Text(option.title)
                        .font(.sans(13, isOn ? .semibold : .medium))
                        .foregroundStyle(isOn ? DoneColor.textPrimary : DoneColor.textSecondary)
                        .lineLimit(1)
                        .padding(.horizontal, DoneSpace.s12)
                        .frame(height: 24)
                        .background {
                            if isOn {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(DoneColor.surfaceDefault)
                                    .shadow(color: DoneColor.shadowCard, radius: 1, y: 1)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(DoneColor.bgSunken, in: RoundedRectangle(cornerRadius: DoneRadius.sm, style: .continuous))
        .fixedSize()
    }
}

// MARK: Tâches

/// Case à cocher de tâche : carré de 18, rayon 5, contour 1,5. La coche apparaît en filigrane
/// au survol ; cochée, plein action.primary.
struct TaskCheckbox: View {
    let isDone: Bool
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var hovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 5, style: .continuous)
        Button(action: action) {
            shape
                .fill(isDone ? DoneColor.actionPrimary : (isEnabled ? DoneColor.surfaceDefault : DoneColor.actionDisabled))
                .overlay {
                    if !isDone {
                        shape.strokeBorder(isEnabled ? DoneColor.borderControl : DoneColor.borderSubtle, lineWidth: 1.5)
                    }
                }
                .overlay {
                    if isDone || (hovered && isEnabled) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(isDone ? DoneColor.actionOnPrimary : DoneColor.borderControl)
                    }
                }
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help(isDone ? "Rouvrir" : "Cocher")
    }
}

/// Puce d'état : hauteur 22, rayon 3, texte 12 Medium. Chaque état a une forme en plus de sa couleur.
struct StateChip: View {
    enum Kind {
        /// Tâche du plan du jour, en cours : point plein sur Indigo.
        case active
        /// Ne peut pas avancer.
        case blocked
        /// Échéance dépassée : contour Alerte.
        case risk
        /// Fait : recule visuellement.
        case done
    }

    let kind: Kind
    let title: String

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DoneRadius.xs, style: .continuous)
        HStack(spacing: 5) {
            icon
            Text(title)
        }
        .font(.sans(12, .medium))
        .foregroundStyle(foreground)
        .padding(.horizontal, 7)
        .frame(height: 22)
        .background(background, in: shape)
        .overlay {
            if kind == .risk {
                shape.strokeBorder(DoneColor.stateRisk, lineWidth: 1)
            }
        }
        .fixedSize()
    }

    @ViewBuilder
    private var icon: some View {
        switch kind {
        case .active:
            Circle().fill(DoneColor.stateOnActive).frame(width: 5, height: 5)
        case .blocked:
            Image(systemName: "nosign").font(.system(size: 9, weight: .bold))
        case .risk:
            Image(systemName: "triangle").font(.system(size: 9, weight: .bold))
        case .done:
            Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
        }
    }

    private var background: Color {
        switch kind {
        case .active: DoneColor.stateActive
        case .blocked: DoneColor.stateBlocked
        case .risk: DoneColor.stateRiskTint
        case .done: DoneColor.stateDone
        }
    }

    private var foreground: Color {
        switch kind {
        case .active: DoneColor.stateOnActive
        case .blocked: DoneColor.stateOnBlocked
        case .risk: DoneColor.stateRiskText
        case .done: DoneColor.stateOnDone
        }
    }
}

/// Puce de durée ou de date : hauteur 24, rayon 3, chiffres tabulaires. Une échéance dépassée
/// passe en teinte d'alerte.
struct InfoChip: View {
    /// Symbole SF : « calendar » pour une date, « clock » pour une durée.
    let symbol: String
    let text: String
    var isAlert = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
        }
        .font(.done(.numericS))
        .foregroundStyle(isAlert ? DoneColor.stateRiskText : DoneColor.textPrimary)
        .padding(.horizontal, 7)
        .frame(height: 24)
        .background(isAlert ? DoneColor.stateRiskTint : DoneColor.bgSunken, in: RoundedRectangle(cornerRadius: DoneRadius.xs, style: .continuous))
        .fixedSize()
    }
}

/// Priorité : « P1 » en Indigo plein, « P2 » en contour Indigo, rien pour P3 et P4.
struct PriorityChip: View {
    let priority: Int

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DoneRadius.xs, style: .continuous)
        if priority <= 2 {
            Text("P\(priority)")
                .font(.done(.numericS))
                .foregroundStyle(priority == 1 ? DoneColor.stateOnActive : DoneColor.stateActiveText)
                .padding(.horizontal, DoneSpace.s6)
                .frame(height: 22)
                .background(priority == 1 ? DoneColor.stateActive : Color.clear, in: shape)
                .overlay {
                    if priority == 2 {
                        shape.strokeBorder(DoneColor.stateActiveText, lineWidth: 1)
                    }
                }
                .fixedSize()
                .help(priority == 1 ? "Priorité 1" : "Priorité 2")
        }
    }
}

// MARK: Navigation

/// Élément de navigation : hauteur 32, rayon 6, icône 16, compteur tabulaire à droite.
/// Actif : surface.selected et graisse Semibold.
struct NavItem: View {
    let title: String
    let icon: Image
    var counter: String?
    let isSelected: Bool
    var isDropTarget = false
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var hovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DoneRadius.sm, style: .continuous)
        Button(action: action) {
            HStack(spacing: DoneSpace.s8) {
                icon
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 15, height: 15)
                    .frame(width: 16, height: 16)
                Text(title)
                    .font(isSelected ? .sans(14, .semibold) : .done(.body))
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let counter {
                    Text(counter)
                        .font(.done(.numericS))
                        .foregroundStyle(DoneColor.textSecondary)
                }
            }
            .foregroundStyle(isEnabled ? DoneColor.textPrimary : DoneColor.textDisabled)
            .padding(.horizontal, DoneSpace.s8)
            .frame(height: 32)
            .background(isSelected ? DoneColor.surfaceSelected : (hovered ? DoneColor.surfaceHover : Color.clear), in: shape)
            .overlay(shape.strokeBorder(DoneColor.focusRing, lineWidth: isDropTarget ? 2 : 0))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

// MARK: Réunions

/// Bloc réunion, rayon 6. Hachuré à venir (temps pris), plein Indigo en cours, gris une fois passé.
struct MeetingBlock: View {
    let meeting: Meeting
    let now: Date
    /// Créneau affiché sous le titre, par exemple « 14:00–15:00 ».
    let detail: String

    private enum Moment { case upcoming, now, past }

    var body: some View {
        let moment: Moment = meeting.contains(now) ? .now : (meeting.end <= now ? .past : .upcoming)
        let shape = RoundedRectangle(cornerRadius: DoneRadius.sm, style: .continuous)
        VStack(alignment: .leading, spacing: 1) {
            Text(meeting.title)
                .font(.sans(13, .medium))
                .lineLimit(1)
            Text(moment == .now ? "En cours · fin \(Format.time(meeting.end))" : detail)
                .font(.done(.numericS))
                .opacity(moment == .now ? 1 : 0.85)
        }
        .foregroundStyle(moment == .now ? DoneColor.meetingOnNow : (moment == .past ? DoneColor.textDisabled : DoneColor.textPrimary))
        .padding(.horizontal, DoneSpace.s8)
        .padding(.vertical, DoneSpace.s6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            switch moment {
            case .now:
                shape.fill(DoneColor.meetingNow)
            case .past:
                shape.fill(DoneColor.stateDone)
            case .upcoming:
                ZStack {
                    DoneColor.meetingBg
                    Hatching()
                }
                .clipShape(shape)
            }
        }
    }
}

// MARK: Logo et anneaux

/// Icône de l'app : carré arrondi en dégradé Indigo 400 vers Indigo 700, anneau blanc presque refermé.
struct DoneAppIcon: View {
    var size: CGFloat = 90

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2245, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0x5A / 255, green: 0x68 / 255, blue: 0xC0 / 255),
                             Color(red: 0x31 / 255, green: 0x3B / 255, blue: 0x7C / 255)],
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
    }
}

/// Anneau du minuteur : la part restante, depuis midi, dans le sens horaire.
/// Diamètre 280 et trait 12 en session ; Indigo en concentration, couleur de pause, gris à l'arrêt.
struct ProgressRing: View {
    let fraction: Double
    var color: Color = DoneColor.pomodoroFocus
    var lineWidth: CGFloat = 12

    var body: some View {
        ZStack {
            Circle()
                .stroke(DoneColor.pomodoroTrack, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, fraction)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: fraction)
        }
        .padding(lineWidth / 2)
    }
}

/// Barre de progression horizontale : piste pomodoro.track, plein state.active.
struct ProgressBar: View {
    let fraction: Double
    var color: Color = DoneColor.stateActive
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(DoneColor.pomodoroTrack)
                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * max(0, min(1, fraction)))
            }
        }
        .frame(height: height)
    }
}

/// Encadré de message : information (teinte active) ou erreur (alerte, la seule couleur chaude).
struct NoticeBox: View {
    enum Tone {
        case info, error
    }

    let text: String
    var tone: Tone = .info

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DoneRadius.sm, style: .continuous)
        HStack(alignment: .firstTextBaseline, spacing: DoneSpace.s8) {
            Image(systemName: tone == .info ? "info.circle" : "triangle")
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .doneText(.callout)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(tone == .info ? DoneColor.stateActiveText : DoneColor.stateRiskText)
        .padding(.horizontal, DoneSpace.s12)
        .padding(.vertical, DoneSpace.s8)
        .background(tone == .info ? DoneColor.stateActiveTint : DoneColor.stateRiskTint, in: shape)
        .overlay {
            if tone == .error {
                shape.strokeBorder(DoneColor.stateRisk, lineWidth: 1)
            }
        }
    }
}
