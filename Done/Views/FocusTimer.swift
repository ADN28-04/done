import SwiftUI

/// Minuteur de session, piste C « Grands chiffres » (maquette validée :
/// `docs/design/mymind/maquettes/minuteur-de-focus.html`). Le temps restant en Oswald SemiBold, chaque
/// chiffre dans une case fixe ; dessous, une règle graduée de 0 (à gauche) à la durée de la session
/// (à droite), et une barre qui part de 0 et dont le bout pointe les minutes qui restent ; puis une
/// ligne : « sur 25 min », « En pause », « de pause, sur 5 min ».
struct FocusTimer: View {
    enum Tone: Equatable {
        /// Concentration : barre braise.
        case focus
        /// À l'arrêt : barre grise, chiffres secondaires qui clignotent lentement.
        case paused
        /// Pause café : barre cobalt.
        case onBreak
    }

    let remaining: TimeInterval
    let total: TimeInterval
    let tone: Tone
    let caption: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let fraction = total > 0 ? max(0, min(1, remaining / total)) : 0
        let lastMinute = tone != .paused && remaining > 0 && remaining <= 60
        VStack(spacing: DoneTimer.gap) {
            TimerDigits(text: Format.clock(remaining), color: tone == .paused ? DoneColor.textSecondary : DoneColor.textPrimary)
                .modifier(Blink(isOn: tone == .paused && !reduceMotion))
                .accessibilityLabel("Temps restant : \(Format.clock(remaining))")
            TimerRuler(fraction: fraction, total: total, tone: tone, glowing: lastMinute)
                .frame(maxWidth: DoneTimer.rulerMaxWidth)
            Text(caption)
                .font(.sans(14, .bold))
                .foregroundStyle(DoneColor.textSecondary)
        }
    }
}

/// Mesures du minuteur, reprises de la maquette.
enum DoneTimer {
    /// Taille des chiffres (Oswald SemiBold) ; la ligne fait la même hauteur, comme un interlignage de 1.
    static let digitSize: CGFloat = 142
    /// Case d'un chiffre : le plus large de la police (« 0 », 0,543 em) moins 0,04 em. Les chiffres sont
    /// serrés et ne bougent pas d'une seconde à l'autre.
    static let digitCell: CGFloat = 0.503
    /// Case des deux-points : leur largeur (0,261 em) moins 0,01 em.
    static let colonCell: CGFloat = 0.251
    /// Écart entre les chiffres, la règle et la ligne du dessous.
    static let gap: CGFloat = 22
    /// La règle s'étire jusqu'à 1000 ; épaisseurs, graduations et chiffres gardent leur taille.
    static let rulerMaxWidth: CGFloat = 1000
    static let rulerHeight: CGFloat = 52
    static let barHeight: CGFloat = 11
    /// La lueur de la dernière minute déborde de 5 au-dessus et au-dessous de la barre.
    static let glowHeight: CGFloat = 21
}

/// Le temps restant, « 08:42 », un chiffre par case de largeur fixe.
private struct TimerDigits: View {
    let text: String
    let color: Color

    var body: some View {
        let size = DoneTimer.digitSize
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, character in
                Text(String(character))
                    .font(.timer(size))
                    .foregroundStyle(color)
                    .fixedSize()
                    .frame(width: size * (character == ":" ? DoneTimer.colonCell : DoneTimer.digitCell))
            }
        }
        .frame(height: size)
        .animation(DoneMotion.arrive, value: color)
    }
}

/// La règle : piste, barre (et sa lueur dans la dernière minute), une graduation par minute (plus
/// longue toutes les 5 min) et un chiffre toutes les 5 min, toutes les 10 au-delà d'une demi-heure.
private struct TimerRuler: View {
    let fraction: Double
    let total: TimeInterval
    let tone: FocusTimer.Tone
    let glowing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    drawScale(in: &context, width: size.width)
                }
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DoneColor.pomodoroTrack)
                        .frame(height: DoneTimer.barHeight)
                    if glowing {
                        Capsule()
                            .fill(tint)
                            .frame(width: width * fraction, height: DoneTimer.glowHeight)
                            .modifier(Glow(isOn: !reduceMotion))
                            .transition(.opacity)
                    }
                    Capsule()
                        .fill(color)
                        .frame(width: width * fraction, height: DoneTimer.barHeight)
                }
                .frame(width: width, height: DoneTimer.barHeight)
                // Le bout de la barre glisse d'une seconde à l'autre ; la couleur change en dur-slow.
                .animation(DoneMotion.tick, value: fraction)
                .animation(DoneMotion.arrive, value: tone)
                .animation(DoneMotion.motion(DoneMotion.appear, reduced: reduceMotion), value: glowing)
            }
        }
        .frame(height: DoneTimer.rulerHeight)
        .accessibilityHidden(true)
    }

    private var color: Color {
        switch tone {
        case .focus: DoneColor.pomodoroFocus
        case .paused: DoneColor.pomodoroPaused
        case .onBreak: DoneColor.pomodoroBreak
        }
    }

    private var tint: Color {
        tone == .onBreak ? DoneColor.stateActiveTint : DoneColor.accentTint
    }

    /// Graduations (2 × 11 toutes les 5 min, 1,2 × 6 sinon, à 18 sous le haut) et chiffres (Nunito Sans
    /// SemiBold 12, à 34 sous le haut ; le premier calé à gauche, le dernier à droite).
    private func drawScale(in context: inout GraphicsContext, width: CGFloat) {
        guard total >= 60, width > 0 else { return }
        let minutes = Int(total / 60)
        let labelStep = minutes > 30 ? 10 : 5
        for minute in 0...minutes {
            let x = width * CGFloat(Double(minute) * 60 / total)
            let major = minute % 5 == 0
            let tickWidth: CGFloat = major ? 2 : 1.2
            let tickHeight: CGFloat = major ? 11 : 6
            let tick = Path(roundedRect: CGRect(x: x - tickWidth / 2, y: 18, width: tickWidth, height: tickHeight), cornerRadius: 1)
            context.fill(tick, with: .color(major ? DoneColor.textSecondary : DoneColor.textDisabled))
            guard minute % labelStep == 0 else { continue }
            let anchor: UnitPoint = minute == 0 ? .topLeading : (x >= width - 0.5 ? .topTrailing : .top)
            let label = Text("\(minute)")
                .font(.sans(12, .semibold).monospacedDigit())
                .foregroundStyle(DoneColor.textSecondary)
            context.draw(label, at: CGPoint(x: x, y: 34), anchor: anchor)
        }
    }
}

/// En pause : les chiffres passent de 1 à 0,35 d'opacité et reviennent, lentement.
private struct Blink: ViewModifier {
    let isOn: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isOn {
            content.phaseAnimator([1.0, 0.35]) { view, opacity in
                view.opacity(opacity)
            } animation: { _ in
                DoneMotion.timerBlink
            }
        } else {
            content
        }
    }
}

/// Dernière minute : la lueur va de 0,35 à 0,9 d'opacité et revient ; immobile à 0,6 avec
/// « Réduire les animations ».
private struct Glow: ViewModifier {
    let isOn: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isOn {
            content.phaseAnimator([0.35, 0.9]) { view, opacity in
                view.opacity(opacity)
            } animation: { _ in
                DoneMotion.timerGlow
            }
        } else {
            content.opacity(0.6)
        }
    }
}

#Preview("Concentration") {
    FocusTimer(remaining: 18 * 60 + 42, total: 25 * 60, tone: .focus, caption: "sur 25 min")
        .padding(40)
        .frame(width: 1100)
}

#Preview("Dernière minute, Deepwork") {
    FocusTimer(remaining: 48, total: 50 * 60, tone: .focus, caption: "sur 50 min")
        .padding(40)
        .frame(width: 1100)
}

#Preview("En pause") {
    FocusTimer(remaining: 12 * 60 + 5, total: 25 * 60, tone: .paused, caption: "En pause")
        .padding(40)
        .frame(width: 1100)
}

#Preview("Pause café") {
    FocusTimer(remaining: 3 * 60 + 10, total: 5 * 60, tone: .onBreak, caption: "de pause, sur 5 min")
        .padding(40)
        .frame(width: 1100)
}
