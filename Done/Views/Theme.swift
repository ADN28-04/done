import AppKit
import SwiftUI

// MARK: Couleurs

/// Design system Done v6 « Jardin » : couleurs nommées par rôle, en clair et en sombre.
/// Référence : docs/design/done-jardin/design-system (README.md et tokens.json).
/// Le code ne référence jamais une couleur de marque (Crème, Encre, Vert profond, Tournesol, Brique)
/// directement. En sombre, le vert s'éclaircit et ce qui est posé dessus passe en vert nuit.
enum DoneColor {
    // Fonds et surfaces
    static let bgCanvas = dynamic(0xF7F3E8, 0x161914)
    static let bgSunken = dynamic(0xEFE9DA, 0x11140F)
    static let surfaceDefault = dynamic(0xFFFDF7, 0x1E221B)
    static let surfaceHover = dynamic(0xF3EEE0, 0x272C23)
    static let surfaceSelected = dynamic(0xE2EDE3, 0x243529)

    // Bordures
    static let borderSubtle = dynamic(0xE6DFCD, 0x2E3329)
    static let borderDefault = dynamic(0xD5CDB8, 0x3E4537)
    static let borderControl = dynamic(0x8A8473, 0x858C7C)

    // Textes
    static let textPrimary = dynamic(0x23281F, 0xECEADF)
    static let textSecondary = dynamic(0x5C6354, 0xA7AC9C)
    static let textDisabled = dynamic(0xB4AF9F, 0x585E51)

    // Actions
    static let actionPrimary = dynamic(0x2F6B4F, 0x7CC39C)
    static let actionPrimaryHover = dynamic(0x285E45, 0x8DCDA9)
    static let actionPrimaryPressed = dynamic(0x204F3A, 0x6BB38C)
    static let actionOnPrimary = dynamic(0xFFFFFF, 0x0F2419)
    static let actionDisabled = dynamic(0xEBE5D6, 0x272C23)
    static let focusRing = dynamic(0x2F6B4F, 0x8DCDA9)

    // États
    static let stateActive = dynamic(0x3B7A5B, 0x7CC39C)
    static let stateOnActive = dynamic(0xFFFFFF, 0x0F2419)
    static let stateActiveText = dynamic(0x1F5138, 0xA6DBBB)
    static let stateActiveTint = dynamic(0xDCEBDF, 0x21362A)
    static let stateBlocked = dynamic(0xECE6D7, 0x2A2F25)
    static let stateOnBlocked = dynamic(0x23281F, 0xECEADF)
    static let stateWaiting = dynamic(0x8A8473, 0x858C7C)
    static let stateRisk = dynamic(0xC2463F, 0xE06A63)
    static let stateRiskTint = dynamic(0xF8E3DE, 0x3A2320)
    static let stateRiskText = dynamic(0xA3332E, 0xF0A29D)
    static let stateDone = dynamic(0xEFE9DA, 0x1B1F18)
    static let stateOnDone = dynamic(0x5C6354, 0xA7AC9C)

    // Joie : réservée aux réussites (Aujourd'hui, Fait, plan terminé, fin de pomodoro).
    // `sun` en plein ou en forme, jamais en texte ; `sunText` sur `sunTint` pour les mots.
    static let sun = dynamic(0xF6C343, 0xF6C343)
    static let onSun = dynamic(0x3D2A00, 0x3D2A00)
    static let sunTint = dynamic(0xFBECC2, 0x3A3016)
    static let sunText = dynamic(0x6B4A05, 0xF2CF6E)

    // Réunions
    static let meetingBg = dynamic(0xEEE8D8, 0x23281F)
    static let meetingHatch = dynamic(0x2F6B4F, 0x7CC39C, lightAlpha: 0.16, darkAlpha: 0.16)
    static let meetingNow = dynamic(0x2F6B4F, 0x7CC39C)
    static let meetingOnNow = dynamic(0xFFFFFF, 0x0F2419)

    // Pomodoro
    static let pomodoroFocus = dynamic(0x2F6B4F, 0x8DCDA9)
    static let pomodoroBreak = dynamic(0xB07A12, 0xF2CF6E)
    static let pomodoroBreakBg = dynamic(0xFBF1D6, 0x24210F)
    static let pomodoroTrack = dynamic(0xE6DFCD, 0x2E3329)
    static let pomodoroPaused = dynamic(0xB4AF9F, 0x585E51)

    // Ombres : teintées de l'encre en clair, noires en sombre. Jamais sur une carte ordinaire :
    // shadowCard pour le segment choisi, shadowRaised (et sa part proche) pour la carte de fin de
    // pomodoro et la saisie flottante.
    static let shadowCard = dynamic(0x23281F, 0x000000, lightAlpha: 0.08, darkAlpha: 0.35)
    static let shadowRaised = dynamic(0x23281F, 0x000000, lightAlpha: 0.12, darkAlpha: 0.50)
    static let shadowRaisedNear = dynamic(0x23281F, 0x000000, lightAlpha: 0.06, darkAlpha: 0.30)

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

/// Rayons doux : assez ronds pour être amicaux, jamais en pilule sauf la barre de progression.
enum DoneRadius {
    /// Case à cocher, segment choisi du sélecteur.
    static let xs: CGFloat = 5
    /// Puces d'état, de priorité et de réussite.
    static let chip: CGFloat = 8
    /// Boutons, champs, réunions, navigation, tuile numérotée, encadrés.
    static let sm: CGFloat = 10
    /// Lignes de tâche, cartes.
    static let md: CGFloat = 14
    /// Panneaux, feuilles, carte de fin de pomodoro, carte de la ligne de temps.
    static let lg: CGFloat = 20
}

// MARK: Typographie

/// Échelle typographique, en deux familles. Fraunces (version douce, SemiBold) pour les trois titres
/// d'affichage seulement ; Archivo pour tout le reste, nombres compris, en chiffres tabulaires.
/// Fraunces ne descend jamais sous displayM. Fichiers dans Done/Fonts, chargés par `FontLoader`.
enum DoneTextStyle {
    /// 46/52 Fraunces, l'action proposée. Une seule chose forte par écran.
    case displayXL
    /// 34/40 Fraunces, titre d'écran.
    case displayL
    /// 23/28 Fraunces, titre de feuille et de carte, tâche en session.
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
    /// 12/16 SemiBold, étiquette de section en casse normale.
    case label
    /// 60/64 Regular, minuteur.
    case numericXL
    /// 28/32, totaux.
    case numericL
    /// 14/20, heures et durées en ligne.
    case numericM
    /// 12/16, puces de durée et de date.
    case numericS

    var size: CGFloat {
        switch self {
        case .displayXL: 46
        case .displayL: 34
        case .displayM: 23
        case .title: 17
        case .body, .bodyStrong, .numericM: 14
        case .callout: 13
        case .caption, .label, .numericS: 12
        case .numericXL: 60
        case .numericL: 28
        }
    }

    var lineHeight: CGFloat {
        switch self {
        case .displayXL: 52
        case .displayL: 40
        case .displayM: 28
        case .title: 24
        case .body, .bodyStrong, .numericM: 20
        case .callout: 18
        case .caption, .label, .numericS: 16
        case .numericXL: 64
        case .numericL: 32
        }
    }

    /// Interlettrage, en em.
    var tracking: CGFloat {
        switch self {
        case .numericXL: -0.02
        case .displayXL, .numericL: -0.01
        case .displayL: -0.005
        default: 0
        }
    }

    var fontName: String {
        switch self {
        case .displayXL, .displayL, .displayM: "FrauncesSoft-SemiBold"
        case .title, .label: "Archivo-SemiBold"
        case .bodyStrong, .numericL, .numericM, .numericS: "Archivo-Medium"
        case .body, .callout, .caption, .numericXL: "Archivo-Regular"
        }
    }

    var isNumeric: Bool {
        switch self {
        case .numericXL, .numericL, .numericM, .numericS: true
        default: false
        }
    }

    /// Les styles numériques prennent les chiffres tabulaires d'Archivo : les colonnes et le minuteur
    /// ne bougent pas en largeur.
    var font: Font {
        let font = Font.custom(fontName, fixedSize: size)
        return isNumeric ? font.monospacedDigit() : font
    }
}

extension Font {
    enum TextWeight {
        case regular, medium, semibold
    }

    static func done(_ style: DoneTextStyle) -> Font { style.font }

    /// Archivo hors échelle : boutons, navigation active. Ajouter `.monospacedDigit()` pour un nombre.
    static func sans(_ size: CGFloat, _ weight: TextWeight = .regular) -> Font {
        let name = switch weight {
        case .regular: "Archivo-Regular"
        case .medium: "Archivo-Medium"
        case .semibold: "Archivo-SemiBold"
        }
        return .custom(name, fixedSize: size)
    }
}

extension View {
    /// Style de texte du design system : police, interlignage et interlettrage.
    func doneText(_ style: DoneTextStyle) -> some View {
        font(style.font)
            .tracking(style.size * style.tracking)
            .lineSpacing(max(0, style.lineHeight - style.size * 1.3))
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

/// Étiquette de section (style label), en casse normale : « Candidates », « Ensuite ».
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
    /// Carte : surface et liseré border.subtle, sans ombre.
    func doneCard(radius: CGFloat = DoneRadius.md) -> some View {
        background(DoneColor.surfaceDefault, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(DoneColor.borderSubtle, lineWidth: 1))
    }

    /// Carte surélevée (shadow.raised : 0 14 32 et 0 2 6) : carte de fin de pomodoro, saisie flottante.
    func doneRaised(radius: CGFloat = DoneRadius.lg) -> some View {
        background(DoneColor.surfaceDefault, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(DoneColor.borderSubtle, lineWidth: 1))
            .shadow(color: DoneColor.shadowRaised, radius: 16, y: 14)
            .shadow(color: DoneColor.shadowRaisedNear, radius: 3, y: 2)
    }

    /// Champ de saisie : hauteur 32, rayon sm, contour border.control, contour focus.ring de 2 au focus.
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

/// Boutons : hauteur 32, rayon sm, padding 14. Un seul principal par vue.
struct DoneButtonStyle: ButtonStyle {
    enum Kind {
        /// action.primary : vert profond en clair, vert clair en sombre.
        case primary
        /// Surface et contour border.default.
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
                    shape.strokeBorder(isEnabled ? DoneColor.borderDefault : DoneColor.borderSubtle, lineWidth: 1)
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
            .overlay(shape.strokeBorder(isEnabled ? DoneColor.borderDefault : DoneColor.borderSubtle, lineWidth: 1))
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
                                RoundedRectangle(cornerRadius: DoneRadius.xs, style: .continuous)
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

/// Case à cocher de tâche : carré de 18, rayon xs, contour 1,5. La coche apparaît en filigrane
/// au survol ; cochée, plein action.primary.
struct TaskCheckbox: View {
    let isDone: Bool
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var hovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DoneRadius.xs, style: .continuous)
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

/// Puce d'état : hauteur 22, rayon chip, marge 8, icône 10, texte 12 Medium. Une forme en plus de la couleur ; fond léger,
/// jamais de plein ni de contour, pour que la ligne reste calme.
struct StateChip: View {
    enum Kind {
        /// Tâche du plan du jour : point state.active sur teinte active.
        case active
        /// Ne peut pas avancer.
        case blocked
        /// Échéance dépassée : teinte d'alerte.
        case risk
        /// Fait : texte seul, recule visuellement.
        case done
    }

    let kind: Kind
    let title: String

    var body: some View {
        HStack(spacing: 5) {
            icon
            Text(title)
        }
        .font(.sans(12, .medium))
        .foregroundStyle(foreground)
        .padding(.horizontal, kind == .done ? 0 : DoneSpace.s8)
        .frame(height: 22)
        .background(background, in: RoundedRectangle(cornerRadius: DoneRadius.chip, style: .continuous))
        .fixedSize()
    }

    @ViewBuilder
    private var icon: some View {
        switch kind {
        case .active:
            Circle().fill(DoneColor.stateActive).frame(width: 5, height: 5)
        case .blocked:
            Image(systemName: "nosign").font(.system(size: 10, weight: .semibold))
        case .risk:
            Image(systemName: "exclamationmark.triangle").font(.system(size: 10, weight: .semibold))
        case .done:
            Image(systemName: "checkmark").font(.system(size: 10, weight: .semibold))
        }
    }

    private var background: Color {
        switch kind {
        case .active: DoneColor.stateActiveTint
        case .blocked: DoneColor.stateBlocked
        case .risk: DoneColor.stateRiskTint
        case .done: .clear
        }
    }

    private var foreground: Color {
        switch kind {
        case .active: DoneColor.stateActiveText
        case .blocked: DoneColor.stateOnBlocked
        case .risk: DoneColor.stateRiskText
        case .done: DoneColor.stateOnDone
        }
    }
}

/// Date ou durée : icône et texte secondaires, chiffres tabulaires, sans fond. Une échéance
/// dépassée passe en texte d'alerte.
struct InfoChip: View {
    /// Symbole SF : « calendar » pour une date, « clock » pour une durée.
    let symbol: String
    let text: String
    var isAlert = false

    var body: some View {
        HStack(spacing: DoneSpace.s4) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .medium))
            Text(text)
        }
        .font(.done(.numericS))
        .foregroundStyle(isAlert ? DoneColor.stateRiskText : DoneColor.textSecondary)
        .frame(height: 22)
        .fixedSize()
    }
}

/// Étiquette : icône et nom en texte secondaire, sans fond, comme les dates et les durées.
struct TagChip: View {
    let name: String

    var body: some View {
        HStack(spacing: DoneSpace.s4) {
            Image(systemName: "tag")
                .font(.system(size: 10, weight: .medium))
            Text(name)
                .lineLimit(1)
        }
        .font(.sans(12, .medium))
        .foregroundStyle(DoneColor.textSecondary)
        .frame(height: 22)
        .fixedSize()
    }
}

/// Priorité : « P1 » sur teinte active, « P2 » en texte actif seul, rien pour P3 et P4.
struct PriorityChip: View {
    let priority: Int

    var body: some View {
        if priority <= 2 {
            Text("P\(priority)")
                .font(.sans(12, priority == 1 ? .semibold : .medium).monospacedDigit())
                .foregroundStyle(DoneColor.stateActiveText)
                .padding(.horizontal, priority == 1 ? DoneSpace.s8 : 0)
                .frame(height: 22)
                .background(priority == 1 ? DoneColor.stateActiveTint : Color.clear, in: RoundedRectangle(cornerRadius: DoneRadius.chip, style: .continuous))
                .fixedSize()
                .help(priority == 1 ? "Priorité 1" : "Priorité 2")
        }
    }
}

// MARK: Navigation

/// Élément de navigation : hauteur 32, rayon sm, icône 16, compteur en chiffres tabulaires à droite.
/// Un projet qui a des sous-projets porte un chevron pour les replier.
/// Actif : surface.selected et graisse Semibold.
struct NavItem: View {
    let title: String
    let icon: Image
    var counter: String?
    let isSelected: Bool
    var isDropTarget = false
    /// `nil` sans sous-éléments ; sinon, vrai quand ils sont dépliés.
    var isExpanded: Bool?
    var onToggle: () -> Void = {}
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
                if let isExpanded {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(DoneColor.textSecondary)
                        .frame(width: 14, height: 24)
                        .contentShape(Rectangle())
                        // Le chevron replie sans ouvrir la liste.
                        .highPriorityGesture(TapGesture().onEnded { onToggle() })
                        .help(isExpanded ? "Replier les sous-projets" : "Déplier les sous-projets")
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

/// Bloc réunion, rayon sm. Hachuré à venir (temps pris), plein vert en cours, gris une fois passé.
struct MeetingBlock: View {
    let meeting: Meeting
    let now: Date
    /// Créneau affiché sous le titre, par exemple « 14:00–15:00 ».
    let detail: String
    /// Remplit toute la hauteur proposée : un créneau de la grille du calendrier.
    var fillsHeight = false

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
        .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading)
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
/// Diamètre 280 et trait 8 en session ; vert en concentration, ocre en pause, gris à l'arrêt.
struct ProgressRing: View {
    let fraction: Double
    var color: Color = DoneColor.pomodoroFocus
    var lineWidth: CGFloat = 8

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

/// Encadré de message, sans contour : information (teinte active) ou erreur (teinte d'alerte, la seule couleur chaude).
struct NoticeBox: View {
    enum Tone {
        case info, error
    }

    let text: String
    var tone: Tone = .info

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DoneRadius.sm, style: .continuous)
        HStack(alignment: .firstTextBaseline, spacing: DoneSpace.s8) {
            Image(systemName: tone == .info ? "info.circle" : "exclamationmark.triangle")
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
    }
}
