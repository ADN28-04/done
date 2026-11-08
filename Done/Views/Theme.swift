import AppKit
import SwiftUI

// MARK: Couleurs

/// Design system Done v7 « Mymind » : couleurs nommées par rôle, en clair et en sombre.
/// Référence : docs/design/mymind/design-system (README.md et tokens.json).
/// Le code ne référence jamais une couleur de marque (Toile, Encre, Braise, Cobalt, Rose des halos)
/// directement. En sombre, la pilule principale s'inverse : fond clair, texte sombre.
enum DoneColor {
    // Fonds et surfaces. La fenêtre se pose sur bgCanvas, réchauffée par deux halos.
    static let bgCanvas = dynamic(0xF9FAFC, 0x0F1012)
    static let bgSunken = dynamic(0xF1F3F7, 0x0B0C0E)
    static let surfaceDefault = dynamic(0xFFFFFF, 0x18191C)
    static let surfaceHover = dynamic(0xF3F5F9, 0x202226)
    static let surfaceSelected = dynamic(0xE5EAF2, 0x232A36)
    static let haloWarm = dynamic(0xFF5924, 0xFF6A3D, lightAlpha: 0.22, darkAlpha: 0.12)
    static let haloPink = dynamic(0xF078A0, 0xF078A0, lightAlpha: 0.20, darkAlpha: 0.10)

    // Bordures
    static let borderSubtle = dynamic(0xE6E8EE, 0x2A2C31)
    static let borderDefault = dynamic(0xD6DAE2, 0x383B42)
    static let borderControl = dynamic(0x8B91A0, 0x7D8494)

    // Textes
    static let textPrimary = dynamic(0x24272D, 0xEEF0F4)
    static let textSecondary = dynamic(0x5D6575, 0xA3A9B6)
    static let textDisabled = dynamic(0xAFB5C1, 0x4F5560)

    // Actions : une pilule d'encre, inversée en sombre. focusRing en cobalt, aussi l'AccentColor.
    static let actionPrimary = dynamic(0x24272D, 0xEEF0F4)
    static let actionPrimaryHover = dynamic(0x3A3E46, 0xFFFFFF)
    static let actionPrimaryPressed = dynamic(0x111316, 0xD5D8DE)
    static let actionOnPrimary = dynamic(0xFFFFFF, 0x15171A)
    static let actionDisabled = dynamic(0xECEEF3, 0x202226)
    static let focusRing = dynamic(0x1573DD, 0x5AA2F0)

    // Marque et joie : la braise, en plein ou en forme (bouton + du rail, anneau du minuteur, heure
    // courante, soleil d'« Aujourd'hui », pétales, pastilles de série), jamais en texte ; pour du texte,
    // accentText sur accentTint.
    static let accent = dynamic(0xFF5924, 0xFF6A3D)
    static let onAccent = dynamic(0x2B0F04, 0x2B0F04)
    static let accentTint = dynamic(0xFFECE4, 0x3A1D14)
    static let accentText = dynamic(0xB33A0C, 0xFF9B77)

    // Rôles de joie de la v6, gardés sous leur nom : alias de la braise, le temps que chaque composant
    // passe à son rôle Mymind (accent, ou success pour « Fait »).
    static let sun = dynamic(0xFF5924, 0xFF6A3D)
    static let onSun = dynamic(0x2B0F04, 0x2B0F04)
    static let sunTint = dynamic(0xFFECE4, 0x3A1D14)
    static let sunText = dynamic(0xB33A0C, 0xFF9B77)

    // États : le cobalt pour ce qui est actif, le vert pour « Fait », l'alerte toujours avec son triangle.
    static let stateActive = dynamic(0x1573DD, 0x5AA2F0)
    static let stateOnActive = dynamic(0xFFFFFF, 0x0B1A2C)
    static let stateActiveText = dynamic(0x0F5BB5, 0x91C2F7)
    static let stateActiveTint = dynamic(0xE7F0FC, 0x16243A)
    static let success = dynamic(0x3D8C4A, 0x6CC07A)
    static let successTint = dynamic(0xE4EFDC, 0x1B2B1D)
    static let successText = dynamic(0x2D6B33, 0x9FD6A5)
    static let stateBlocked = dynamic(0xECEEF3, 0x23262B)
    static let stateOnBlocked = dynamic(0x24272D, 0xEEF0F4)
    static let stateWaiting = dynamic(0x8B91A0, 0x7D8494)
    static let stateRisk = dynamic(0xD2313C, 0xF0646B)
    static let stateRiskTint = dynamic(0xFDEAEA, 0x3A1B1E)
    static let stateRiskText = dynamic(0x8F1A24, 0xFCC4C7)
    static let stateDone = dynamic(0xF1F3F7, 0x141518)
    static let stateOnDone = dynamic(0x5D6575, 0xA3A9B6)

    // Étiquettes et cartes de note : une teinte par type de note.
    static let tagPink = dynamic(0xB8336A, 0xF08AB3)
    static let tagYellow = dynamic(0x8A5D00, 0xF2C25C)
    static let cardParchment = dynamic(0xF3F0E7, 0x1F1D18)
    static let cardSage = dynamic(0xDDE9D3, 0x19221A)
    static let cardSlate = dynamic(0xE5EAF2, 0x1A1F29)
    static let cardBlush = dynamic(0xFFF1F1, 0x251A1A)

    // Réunions
    static let meetingBg = dynamic(0xE5EAF2, 0x1C2230)
    static let meetingHatch = dynamic(0x1573DD, 0x5AA2F0, lightAlpha: 0.14, darkAlpha: 0.16)
    static let meetingNow = dynamic(0x24272D, 0xEEF0F4)
    static let meetingOnNow = dynamic(0xFFFFFF, 0x15171A)

    // Pomodoro : la braise en concentration, le cobalt en pause.
    static let pomodoroFocus = dynamic(0xF4511F, 0xFF6A3D)
    static let pomodoroBreak = dynamic(0x1573DD, 0x5AA2F0)
    static let pomodoroBreakBg = dynamic(0xEEF4FC, 0x101A27)
    static let pomodoroTrack = dynamic(0xE6E8EE, 0x2A2C31)
    static let pomodoroPaused = dynamic(0xAFB5C1, 0x4F5560)

    // Ombres, en deux couches, teintées de l'encre en clair, noires en sombre. shadowCard (avec sa
    // part proche) : cartes widget, barre de saisie, boutons du rail. shadowRaised : carte de fin de
    // pomodoro et saisie flottante. shadowControl : segment choisi.
    static let shadowCard = dynamic(0x24272D, 0x000000, lightAlpha: 0.06, darkAlpha: 0.30)
    static let shadowCardNear = dynamic(0x24272D, 0x000000, lightAlpha: 0.05, darkAlpha: 0.40)
    static let shadowRaised = dynamic(0x24272D, 0x000000, lightAlpha: 0.14, darkAlpha: 0.55)
    static let shadowRaisedNear = dynamic(0x24272D, 0x000000, lightAlpha: 0.06, darkAlpha: 0.35)
    static let shadowControl = dynamic(0x24272D, 0x000000, lightAlpha: 0.10, darkAlpha: 0.45)

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

/// Rayons : de grands rectangles doux pour ce qui regroupe, la pilule pour tout ce qui se clique.
enum DoneRadius {
    /// Case à cocher.
    static let xs: CGFloat = 6
    /// Champs de formulaire, tuiles numérotées, réunions, segments.
    static let sm: CGFloat = 12
    /// Lignes de tâche au survol, cartes de note, encadrés.
    static let md: CGFloat = 18
    /// Cartes widget, feuilles, carte de fin de pomodoro.
    static let lg: CGFloat = 24
    /// Capsule : boutons, puces, étiquettes, recherche, barre de saisie, boutons du rail. Un rayon plus
    /// grand que la demi-hauteur donne une capsule.
    static let pill: CGFloat = 999
    /// Puces d'état, de priorité et de réussite : en capsule, comme toutes les puces.
    static let chip: CGFloat = pill
}

// MARK: Mouvement

/// Mouvement : durées et courbes de tokens.json, avec leurs équivalents SwiftUI. Le mouvement dit
/// « c'est fait », il ne décore pas : ce qui arrive ralentit en se posant, ce qui se déplace accélère
/// puis freine, et seules les réussites rebondissent, une fois. Rien ne bouge sans action de la
/// personne, sauf l'anneau du minuteur. Avec « Réduire les animations », il ne reste que des fondus :
/// chaque vue lit `accessibilityReduceMotion` et passe par `DoneMotion.fade`, ou ne bouge pas.
enum DoneMotion {
    // Durées, en secondes.
    /// Appui : un bouton qui s'enfonce, une case qui se tasse.
    static let instant: Double = 0.09
    /// Survol, coche qui se trace, changement de couleur d'état.
    static let fast: Double = 0.16
    /// Puces qui apparaissent, segment qui glisse, ligne qui se barre.
    static let base: Double = 0.26
    /// Cartes, feuilles, fond de la pause, ligne qui part vers « Fait aujourd'hui ».
    static let slow: Double = 0.42
    /// Éclat des réussites.
    static let celebrate: Double = 0.9

    // Animations.
    /// ease-out, dur-instant : l'appui.
    static let press = Animation.easeOut(duration: instant)
    /// ease-out, dur-fast : survol, coche, couleur d'état.
    static let hover = Animation.easeOut(duration: fast)
    /// ease-out, dur-base : une puce, un encadré ou un trait qui arrive.
    static let appear = Animation.easeOut(duration: base)
    /// ease-out, dur-slow : une carte, une feuille, un fond qui change.
    static let arrive = Animation.smooth(duration: slow)
    /// ease-in-out, dur-base : ce qui se déplace (segment choisi, section qui se replie, barre latérale).
    static let move = Animation.easeInOut(duration: base)
    /// ease-in-out, dur-slow : une ligne qui change de liste.
    static let travel = Animation.easeInOut(duration: slow)
    /// ease-spring, dur-base : le rebond des réussites (case cochée, puce « Fait », pastille de série).
    static let pop = Animation.spring(response: 0.3, dampingFraction: 0.55)
    /// ease-out, dur-celebrate : l'éclat des réussites.
    static let burst = Animation.easeOut(duration: celebrate)
    /// Ce qui reste d'un mouvement avec « Réduire les animations » : un fondu court.
    static let fade = Animation.easeOut(duration: fast)

    /// L'animation demandée, ou un simple fondu si la personne a choisi de réduire les animations.
    static func motion(_ animation: Animation, reduced: Bool) -> Animation {
        reduced ? fade : animation
    }
}

/// Appui : la cible se tasse en dur-instant (bouton à 0,97, case à 0,88). Rien avec « Réduire les animations ».
private struct PressEffect: ViewModifier {
    let isPressed: Bool
    let scale: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed && !reduceMotion ? scale : 1)
            .animation(DoneMotion.press, value: isPressed)
    }
}

/// Arrivée à l'apparition : fondu, et pour une carte une montée de 12 (d-rise). Une seule fois.
/// Avec « Réduire les animations », le fondu seul.
private struct ArriveEffect: ViewModifier {
    let rise: CGFloat
    let animation: Animation
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let moving = !shown && !reduceMotion && rise > 0
        content
            .opacity(shown ? 1 : 0)
            .offset(y: moving ? rise : 0)
            .scaleEffect(moving ? 0.98 : 1)
            .onAppear {
                withAnimation(DoneMotion.motion(animation, reduced: reduceMotion)) { shown = true }
            }
    }
}

extension View {
    /// La vue se tasse tant qu'elle est appuyée.
    func donePress(_ isPressed: Bool, scale: CGFloat = 0.97) -> some View {
        modifier(PressEffect(isPressed: isPressed, scale: scale))
    }

    /// La vue arrive en fondu à son apparition ; avec `rise`, elle monte aussi de cette hauteur.
    func doneArrive(rise: CGFloat = 0, animation: Animation = DoneMotion.arrive) -> some View {
        modifier(ArriveEffect(rise: rise, animation: animation))
    }
}

/// Bouton sans habillage qui se tasse à l'appui : la case à cocher.
struct DonePressStyle: ButtonStyle {
    var scale: CGFloat = 0.88

    func makeBody(configuration: Configuration) -> some View {
        configuration.label.donePress(configuration.isPressed, scale: scale)
    }
}

/// Coche du design system, sur un carré de 12 : « M2.2 6.4 l2.4 2.4 5.2-5.6 ». Se trace avec `.trim`.
struct CheckMarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let x = rect.width / 12
        let y = rect.height / 12
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 2.2 * x, y: rect.minY + 6.4 * y))
        path.addLine(to: CGPoint(x: rect.minX + 4.6 * x, y: rect.minY + 8.8 * y))
        path.addLine(to: CGPoint(x: rect.minX + 9.8 * x, y: rect.minY + 3.2 * y))
        return path
    }
}

/// Éclat des réussites : un halo sunTint et huit pétales sun (la braise) qui partent du centre puis s'effacent,
/// une fois chaque fois que `count` augmente. À poser en fond ou en surimpression, centré : il ne
/// prend pas de place. Rien avec « Réduire les animations ».
struct SunBurst: View {
    /// Augmente d'un à chaque réussite.
    let count: Int
    /// Distance parcourue par les pétales : 24 depuis une case, 44 depuis l'anneau de fin.
    var distance: CGFloat = 24
    /// Taille des pétales et du halo : 1 pour une case ou un anneau, moins pour une icône.
    var scale: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SunBurstFrame(progress: Double(count), distance: distance, scale: scale)
            .animation(reduceMotion ? nil : DoneMotion.burst, value: count)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Une image de l'éclat. `progress` avance d'un entier par éclat ; sa partie décimale est l'avancée,
/// et un nombre entier, l'éclat au repos, invisible.
private struct SunBurstFrame: View, Animatable {
    var progress: Double
    let distance: CGFloat
    let scale: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let t = progress - progress.rounded(.down)
        // Les pétales apparaissent sur le premier quart, puis s'effacent en s'éloignant.
        let petalOpacity = t < 0.25 ? t / 0.25 : (1 - t) / 0.75
        ZStack {
            Circle()
                .fill(DoneColor.sunTint)
                .frame(width: 56 * scale, height: 56 * scale)
                .scaleEffect(0.4 + 1.2 * t)
                .opacity(t == 0 ? 0 : 0.9 * (1 - t))
            ForEach(0..<8, id: \.self) { index in
                Capsule()
                    .fill(DoneColor.sun)
                    .frame(width: 8 * scale, height: 14 * scale)
                    .scaleEffect(0.4 + 0.6 * t)
                    .offset(y: -distance * t)
                    .rotationEffect(.degrees(Double(index) * 45))
                    .opacity(petalOpacity)
            }
        }
        .frame(width: 0, height: 0)
    }
}

// MARK: Typographie

/// Échelle typographique, en trois familles libres (licences OFL dans docs/fonts) :
/// - Newsreader (Display pour displayXL et displayL, Text pour displayM et noteTitle), Medium, pour les
///   titres ; l'italique pour la salutation de l'accueil. Jamais sous noteTitle (17), jamais pour un nombre.
/// - Nunito Sans pour l'interface : Regular pour le texte, SemiBold pour les libellés et les titres de
///   tâche, Bold pour title et label, Light pour les grands chiffres. Ses chiffres sont à chasse fixe.
/// - Courier Prime pour noteMono seulement : le corps des notes dans la mosaïque.
/// Fichiers dans Done/Fonts, chargés par `FontLoader`.
enum DoneTextStyle {
    /// 46/50 Newsreader Display, titre d'accueil et action proposée en session. Une seule chose forte par écran.
    case displayXL
    /// 32/38 Newsreader Display, prochaine action, titres d'écran.
    case displayL
    /// 22/28 Newsreader Text, titres de feuille et de carte surélevée, note ouverte.
    case displayM
    /// 17/22 Newsreader Text, titre d'une carte de note dans la mosaïque.
    case noteTitle
    /// 16/22 Bold, titre de panneau, tâche parente.
    case title
    /// 14/20, texte courant.
    case body
    /// 14/20 SemiBold, titre de tâche, libellé de pilule.
    case bodyStrong
    /// 13/18, texte d'appoint.
    case callout
    /// 12/16, métadonnées.
    case caption
    /// 12/16 Bold, en-tête de carte et étiquette de section, en casse normale.
    case label
    /// 60/64 Light, minuteur.
    case numericXL
    /// 44/48 Light, grand chiffre d'une carte, totaux.
    case numericL
    /// 14/20 SemiBold, valeurs en ligne.
    case numericM
    /// 12/16 SemiBold, dates, durées, heures, compteurs.
    case numericS
    /// 13/19 Courier Prime, corps des notes rapides et du journal dans la mosaïque. Jamais pour l'interface.
    case noteMono

    var size: CGFloat {
        switch self {
        case .displayXL: 46
        case .displayL: 32
        case .displayM: 22
        case .noteTitle: 17
        case .title: 16
        case .body, .bodyStrong, .numericM: 14
        case .callout, .noteMono: 13
        case .caption, .label, .numericS: 12
        case .numericXL: 60
        case .numericL: 44
        }
    }

    var lineHeight: CGFloat {
        switch self {
        case .displayXL: 50
        case .displayL: 38
        case .displayM: 28
        case .noteTitle, .title: 22
        case .body, .bodyStrong, .numericM: 20
        case .callout: 18
        case .noteMono: 19
        case .caption, .label, .numericS: 16
        case .numericXL: 64
        case .numericL: 48
        }
    }

    /// Interlettrage, en em.
    var tracking: CGFloat {
        switch self {
        case .displayXL, .numericXL, .numericL: -0.02
        case .displayL: -0.015
        case .displayM: -0.01
        default: 0
        }
    }

    var fontName: String {
        switch self {
        case .displayXL, .displayL: "NewsreaderDisplay-Medium"
        case .displayM, .noteTitle: "NewsreaderText-Medium"
        case .title, .label: "NunitoSans-Bold"
        case .bodyStrong, .numericM, .numericS: "NunitoSans-SemiBold"
        case .body, .callout, .caption: "NunitoSans-Regular"
        case .numericXL, .numericL: "NunitoSans-Light"
        case .noteMono: "CourierPrime-Regular"
        }
    }

    var isNumeric: Bool {
        switch self {
        case .numericXL, .numericL, .numericM, .numericS: true
        default: false
        }
    }

    /// Les chiffres de Nunito Sans sont déjà à chasse fixe ; `monospacedDigit` le garantit pour les
    /// styles numériques : les colonnes et le minuteur ne bougent pas en largeur.
    var font: Font {
        let font = Font.custom(fontName, fixedSize: size)
        return isNumeric ? font.monospacedDigit() : font
    }
}

extension Font {
    /// Graisses hors échelle. Nunito Sans n'a pas de Medium : `medium` et `semibold` donnent SemiBold,
    /// `bold` donne Bold (navigation active).
    enum TextWeight {
        case regular, medium, semibold, bold
    }

    static func done(_ style: DoneTextStyle) -> Font { style.font }

    /// Un titre d'affichage en italique (Newsreader Display Medium Italic) : la salutation de l'accueil.
    static func doneItalic(_ style: DoneTextStyle) -> Font {
        .custom("NewsreaderDisplay-MediumItalic", fixedSize: style.size)
    }

    /// Nunito Sans hors échelle : boutons, puces, navigation. Ajouter `.monospacedDigit()` pour un nombre.
    static func sans(_ size: CGFloat, _ weight: TextWeight = .regular) -> Font {
        let name = switch weight {
        case .regular: "NunitoSans-Regular"
        case .medium, .semibold: "NunitoSans-SemiBold"
        case .bold: "NunitoSans-Bold"
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

    /// Carte surélevée (shadow.raised : 0 20 50 et 0 4 10) : carte de fin de pomodoro, saisie flottante.
    func doneRaised(radius: CGFloat = DoneRadius.lg) -> some View {
        background(DoneColor.surfaceDefault, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(DoneColor.borderSubtle, lineWidth: 1))
            .shadow(color: DoneColor.shadowRaised, radius: 25, y: 20)
            .shadow(color: DoneColor.shadowRaisedNear, radius: 5, y: 4)
    }

    /// Champ de saisie : hauteur 34, rayon sm, contour border.control, contour focus.ring de 2 au focus.
    func doneField(focused: Bool, height: CGFloat? = 34) -> some View {
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

/// Boutons : hauteur 34 (compact 28), rayon sm, padding 14. Un seul principal par vue.
struct DoneButtonStyle: ButtonStyle {
    enum Kind {
        /// action.primary : pilule d'encre, inversée en sombre.
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
            .frame(height: compact ? 28 : 34)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(background, in: shape)
            .overlay {
                if kind == .secondary {
                    shape.strokeBorder(isEnabled ? DoneColor.borderDefault : DoneColor.borderSubtle, lineWidth: 1)
                }
            }
            .contentShape(shape)
            .donePress(configuration.isPressed)
            .animation(DoneMotion.hover, value: hovered)
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

/// Bouton carré à icône, 34 × 34 : nouvelle tâche, semaine précédente ou suivante.
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
            .frame(width: 34, height: 34)
            .background(isEnabled && (hovered || configuration.isPressed) ? DoneColor.surfaceHover : DoneColor.surfaceDefault, in: shape)
            .overlay(shape.strokeBorder(isEnabled ? DoneColor.borderDefault : DoneColor.borderSubtle, lineWidth: 1))
            .contentShape(shape)
            .donePress(configuration.isPressed)
            .animation(DoneMotion.hover, value: hovered)
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

/// Choix exclusif : piste bg.sunken, segment choisi sur une surface, qui glisse vers la nouvelle
/// option (dur-base, ease-in-out). Avec « Réduire les animations », il change de place sans glisser.
struct DoneSegmented<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, title: String)]
    @Namespace private var segment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: DoneSpace.s2) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let isOn = selection == option.value
                Button {
                    withAnimation(reduceMotion ? nil : DoneMotion.move) { selection = option.value }
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
                                    .shadow(color: DoneColor.shadowControl, radius: 1, y: 1)
                                    .matchedGeometryEffect(id: "segment", in: segment)
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

/// Case à cocher de tâche : carré de 18, rayon xs, contour 1,5. La coche apparaît en filigrane au
/// survol ; cochée, plein action.primary. Au moment où l'on coche, la case se tasse, rebondit et la
/// coche se trace ; dans une ligne de tâche (`bursts`), huit pétales partent aussi. Rouvrir ne rejoue
/// rien. Avec « Réduire les animations », la case change en fondu.
struct TaskCheckbox: View {
    let isDone: Bool
    /// Ligne de tâche : l'éclat accompagne la coche.
    var bursts = false
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered = false
    /// Augmente à chaque coche faite ici : rejoue le rebond, le tracé et l'éclat.
    @State private var celebrations = 0

    var body: some View {
        Button {
            // Seule une coche faite ici se fête : une case qui arrive déjà cochée ne bouge pas.
            if !isDone, !reduceMotion { celebrations += 1 }
            action()
        } label: {
            CheckboxFace(progress: Double(celebrations), isDone: isDone, isEnabled: isEnabled, hovered: hovered)
                .animation(.linear(duration: DoneMotion.base), value: celebrations)
                .animation(DoneMotion.motion(DoneMotion.hover, reduced: reduceMotion), value: isDone)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(DonePressStyle())
        .background {
            if bursts {
                SunBurst(count: celebrations)
            }
        }
        .onHover { hovered = $0 }
        .help(isDone ? "Rouvrir" : "Cocher")
    }
}

/// Une image de la case. `progress` avance d'un entier par coche fêtée ; sa partie décimale est
/// l'avancée du rebond (0,6, puis 1,14, puis 1) et du tracé de la coche (60 ms après, en dur-fast).
private struct CheckboxFace: View, Animatable {
    var progress: Double
    let isDone: Bool
    let isEnabled: Bool
    let hovered: Bool

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DoneRadius.xs, style: .continuous)
        let t = progress - progress.rounded(.down)
        let celebrating = isDone && t > 0
        shape
            .fill(isDone ? DoneColor.actionPrimary : (isEnabled ? DoneColor.surfaceDefault : DoneColor.actionDisabled))
            .overlay {
                if !isDone {
                    shape.strokeBorder(isEnabled ? DoneColor.borderControl : DoneColor.borderSubtle, lineWidth: 1.5)
                }
            }
            .overlay {
                if isDone || (hovered && isEnabled) {
                    // Coche de 10, en gras.
                    CheckMarkShape()
                        .trim(from: 0, to: celebrating ? Self.drawn(t) : 1)
                        .stroke(isDone ? DoneColor.actionOnPrimary : DoneColor.borderControl, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                        .frame(width: 10, height: 10)
                }
            }
            .scaleEffect(celebrating ? Self.scale(t) : 1)
    }

    /// Rebond d-pop : de 0,6 à 1,14 sur 60 % du temps, puis retour à 1.
    private static func scale(_ t: Double) -> CGFloat {
        t < 0.6 ? 0.6 + 0.54 * easeOut(t / 0.6) : 1.14 - 0.14 * easeOut((t - 0.6) / 0.4)
    }

    /// Part de la coche tracée : de 60 ms à 220 ms sur les 260 ms du rebond.
    private static func drawn(_ t: Double) -> CGFloat {
        let elapsed = t * DoneMotion.base
        return easeOut(min(max((elapsed - 0.06) / DoneMotion.fast, 0), 1))
    }

    private static func easeOut(_ x: Double) -> Double {
        1 - (1 - x) * (1 - x) * (1 - x)
    }
}

/// Puce d'état : hauteur 22, rayon chip, marge 8, icône 10, texte 12 Medium. Une icône double toujours
/// la couleur ; fond léger, jamais de plein ni de contour, pour que la ligne reste calme.
struct StateChip: View {
    enum Kind {
        /// « Aujourd'hui », tâche du plan du jour : soleil, sunText sur sunTint.
        case active
        /// Ne peut pas avancer.
        case blocked
        /// Échéance dépassée : teinte d'alerte.
        case risk
        /// Fait un autre jour : coche et texte seuls, recule visuellement.
        case done
        /// « Fait », tout juste coché : coche, sunText sur sunTint. L'appelant la fait arriver en
        /// rebondissant (DoneMotion.pop).
        case doneToday
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
            Image(systemName: "sun.max").font(.system(size: 10, weight: .semibold))
        case .doneToday:
            Image(systemName: "checkmark").font(.system(size: 10, weight: .semibold))
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
        case .active, .doneToday: DoneColor.sunTint
        case .blocked: DoneColor.stateBlocked
        case .risk: DoneColor.stateRiskTint
        case .done: .clear
        }
    }

    private var foreground: Color {
        switch kind {
        case .active, .doneToday: DoneColor.sunText
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

// MARK: Raccourcis

/// Touche dessinée, comme le « ⌘K » d'une recherche : 11 Medium en texte secondaire, sur surface, contour
/// borderDefault, rayon xs, 18 de haut. Montre un raccourci sans prendre la parole.
struct KeyCap: View {
    let key: String

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DoneRadius.xs, style: .continuous)
        Text(key)
            .font(.sans(11, .medium).monospacedDigit())
            .foregroundStyle(DoneColor.textSecondary)
            .padding(.horizontal, DoneSpace.s4)
            .frame(minWidth: 18, minHeight: 18)
            .background(DoneColor.surfaceDefault, in: shape)
            .overlay(shape.strokeBorder(DoneColor.borderDefault, lineWidth: 1))
            .fixedSize()
    }
}

/// Un raccourci et ce qu'il fait : des touches dessinées, puis le verbe en caption secondaire.
struct ShortcutHint: View {
    let keys: [String]
    let label: String

    var body: some View {
        HStack(spacing: DoneSpace.s2) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                KeyCap(key: key)
            }
            Text(label)
                .doneText(.caption)
                .foregroundStyle(DoneColor.textSecondary)
                .padding(.leading, DoneSpace.s4)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Les raccourcis d'une liste de tâches, à droite de son titre.
struct ListShortcutHints: View {
    /// ⌘↑ ⌘↓ pour déplacer : dans une liste rangée à la main, pas sur Aujourd'hui.
    var canMove = true

    var body: some View {
        HStack(spacing: DoneSpace.s16) {
            ShortcutHint(keys: ["↑", "↓"], label: "Choisir")
            ShortcutHint(keys: ["Espace"], label: "Cocher")
            ShortcutHint(keys: ["↩"], label: "Ouvrir")
            if canMove {
                ShortcutHint(keys: ["⌘", "↑", "↓"], label: "Déplacer")
            }
        }
        .help("Raccourcis de la liste, quand elle a le focus : Tab depuis le champ d'ajout, Échap pour y revenir")
    }
}

// MARK: Navigation

/// Élément de navigation : hauteur 34, rayon sm, icône 16, compteur en chiffres tabulaires à droite.
/// Un projet qui a des sous-projets porte un chevron pour les replier.
/// Actif : surface.selected et graisse Semibold.
struct NavItem: View {
    let title: String
    let icon: Image
    /// Couleur propre de l'icône : le soleil d'« Aujourd'hui » reste en sunText, même au repos.
    var iconColor: Color?
    /// Pour une icône qui fête une réussite : augmente d'un à chaque éclat (plan du jour bouclé).
    var burstCount: Int?
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
                iconView
                    .background {
                        if let burstCount {
                            SunBurst(count: burstCount, distance: 16, scale: 0.55)
                        }
                    }
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
            .frame(height: 34)
            .background(isSelected ? DoneColor.surfaceSelected : (hovered ? DoneColor.surfaceHover : Color.clear), in: shape)
            .overlay(shape.strokeBorder(DoneColor.focusRing, lineWidth: isDropTarget ? 2 : 0))
            .contentShape(shape)
            .animation(DoneMotion.hover, value: hovered)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }

    @ViewBuilder
    private var iconView: some View {
        let image = icon
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 15, height: 15)
            .frame(width: 16, height: 16)
        if let iconColor {
            image.foregroundStyle(iconColor)
        } else {
            image
        }
    }
}

/// Élément du rail de navigation (barre latérale réduite) : icône de 16 dans une case de 40 × 32,
/// rayon sm. Actif en surfaceSelected, survol en surfaceHover. Le titre et le raccourci passent dans l'aide.
struct NavRailItem: View {
    let title: String
    let icon: Image
    /// Couleur propre de l'icône : le soleil d'« Aujourd'hui » reste en sunText.
    var iconColor: Color?
    let isSelected: Bool
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DoneRadius.sm, style: .continuous)
        Button(action: action) {
            iconView
                .frame(width: 40, height: 32)
                .background(isSelected ? DoneColor.surfaceSelected : (hovered ? DoneColor.surfaceHover : Color.clear), in: shape)
                .contentShape(shape)
                .animation(DoneMotion.hover, value: hovered)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help(title)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private var iconView: some View {
        let image = icon
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 15, height: 15)
            .frame(width: 16, height: 16)
        image.foregroundStyle(iconColor ?? DoneColor.textPrimary)
    }
}

// MARK: Réunions

/// Bloc réunion, rayon sm. Hachuré à venir (temps pris), plein meetingNow (encre) en cours, gris une fois passé.
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

/// Icône de l'app : carré arrondi blanc, réchauffé d'un halo braise en haut à droite et d'un halo rose en
/// bas à gauche ; dessus, un anneau fin en encre (trait de 30 sur 824) ouvert sur 60°, et un point
/// braise au milieu de l'ouverture. Mêmes proportions que docs/design/icon.svg (carré de 824).
/// Couleurs fixes : l'icône ne change pas avec le thème.
struct DoneAppIcon: View {
    var size: CGFloat = 90

    private static let ink = fixed(0x24272D)
    private static let ember = fixed(0xFF5924)
    private static let warmStops: [Gradient.Stop] = [
        .init(color: fixed(0xFFD9C9), location: 0),
        .init(color: fixed(0xFFF4EF), location: 0.45),
        .init(color: fixed(0xFFFFFF), location: 1),
    ]
    private static let pink = fixed(0xF7C6D8)

    var body: some View {
        let unit = size / 824
        let ring = 480 * unit
        let line = 30 * unit
        // Milieu de l'ouverture : 330°, depuis midi dans le sens horaire, sur l'anneau.
        let dotAngle = Angle.degrees(330).radians
        let shape = RoundedRectangle(cornerRadius: 185 * unit, style: .continuous)
        ZStack {
            shape
                .fill(RadialGradient(stops: Self.warmStops, center: UnitPoint(x: 0.85, y: 0.1), startRadius: 0, endRadius: 0.9 * size))
            shape
                .fill(RadialGradient(colors: [Self.pink.opacity(0.9), Self.pink.opacity(0)], center: UnitPoint(x: 0.1, y: 0.95), startRadius: 0, endRadius: 0.7 * size))
            Circle()
                .stroke(Self.ink.opacity(0.12), lineWidth: line)
                .frame(width: ring, height: ring)
            Circle()
                .trim(from: 0, to: 300.0 / 360.0)
                .stroke(Self.ink, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: ring, height: ring)
            Circle()
                .fill(Self.ember)
                .frame(width: 80 * unit, height: 80 * unit)
                .offset(x: ring / 2 * sin(dotAngle), y: -ring / 2 * cos(dotAngle))
        }
        .frame(width: size, height: size)
    }

    private static func fixed(_ hex: UInt32) -> Color {
        Color(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// Anneau du minuteur : la part restante, depuis midi, dans le sens horaire.
/// Diamètre 280 et trait 6 en session, fin comme le logo ; braise en concentration, cobalt en pause, gris à l'arrêt.
struct ProgressRing: View {
    let fraction: Double
    var color: Color = DoneColor.pomodoroFocus
    var lineWidth: CGFloat = 6

    var body: some View {
        ZStack {
            Circle()
                .stroke(DoneColor.pomodoroTrack, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, fraction)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                // Le trait glisse d'une seconde à l'autre ; la couleur change avec le fond, en dur-slow.
                .animation(.linear(duration: 1), value: fraction)
                .animation(DoneMotion.arrive, value: color)
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

/// Encadré de message, sans contour : information en cobalt, réussite en braise (plan du jour
/// terminé), erreur en brique. Arrive en fondu (dur-base).
struct NoticeBox: View {
    enum Tone {
        case info, success, error
    }

    let text: String
    var tone: Tone = .info

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DoneRadius.sm, style: .continuous)
        HStack(alignment: .firstTextBaseline, spacing: DoneSpace.s8) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .doneText(.callout)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, DoneSpace.s12)
        .padding(.vertical, DoneSpace.s8)
        .background(background, in: shape)
        .doneArrive(animation: DoneMotion.appear)
    }

    private var symbol: String {
        switch tone {
        case .info: "info.circle"
        case .success: "sun.max"
        case .error: "exclamationmark.triangle"
        }
    }

    private var foreground: Color {
        switch tone {
        case .info: DoneColor.stateActiveText
        case .success: DoneColor.sunText
        case .error: DoneColor.stateRiskText
        }
    }

    private var background: Color {
        switch tone {
        case .info: DoneColor.stateActiveTint
        case .success: DoneColor.sunTint
        case .error: DoneColor.stateRiskTint
        }
    }
}
