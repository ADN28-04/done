import SwiftUI

/// Minuteur en cours ou en pause.
struct SessionView: View {
    @Environment(FocusEngine.self) private var engine

    var body: some View {
        if let current = engine.current {
            VStack(spacing: 28) {
                VStack(spacing: 6) {
                    Text(context(current))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(current.action.content)
                        .font(.system(size: 26, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 560)
                }

                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 14)
                    Circle()
                        .trim(from: 0, to: engine.progress)
                        .stroke(
                            engine.phase == .paused ? Color.secondary : Color.accentColor,
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: engine.progress)
                    VStack(spacing: 4) {
                        Text(Format.clock(engine.remaining))
                            .font(.system(size: 56, weight: .light, design: .rounded).monospacedDigit())
                        Text(engine.phase == .paused ? "En pause" : "sur \(Int(current.planned / 60)) min")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 260, height: 260)

                HStack(spacing: 12) {
                    if engine.phase == .paused {
                        Button {
                            engine.resume()
                        } label: {
                            Label("Reprendre", systemImage: "play.fill")
                        }
                        .keyboardShortcut(.space, modifiers: [])
                    } else {
                        Button {
                            engine.pause()
                        } label: {
                            Label("Pause", systemImage: "pause.fill")
                        }
                        .keyboardShortcut(.space, modifiers: [])
                    }
                    Menu {
                        ForEach(InterruptionReason.allCases) { reason in
                            Button {
                                engine.interrupt(reason)
                            } label: {
                                Label(reason.label, systemImage: reason.symbol)
                            }
                        }
                    } label: {
                        Label("Interrompre", systemImage: "hand.raised")
                    }
                    .fixedSize()
                    Button {
                        engine.finishEarly()
                    } label: {
                        Label("Terminer", systemImage: "stop.fill")
                    }
                }
                .controlSize(.large)
            }
        }
    }

    private func context(_ current: FocusEngine.Current) -> String {
        guard current.action.id != current.root.id else { return current.projectName }
        return "\(current.projectName) · \(current.root.content)"
    }
}

/// Session interrompue : on garde la place et on attend la suite.
struct InterruptionView: View {
    @Environment(AppModel.self) private var model
    @Environment(FocusEngine.self) private var engine
    let reason: InterruptionReason
    @State private var showPicker = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: reason.symbol)
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text("Interrompu : \(reason.label)")
                .font(.title)
            if let since = engine.interruptedAt {
                Text("Depuis \(Format.minutes(engine.now.timeIntervalSince(since) / 60))")
                    .font(.title3.monospacedDigit())
            }
            if let current = engine.current {
                Text("« \(current.action.content) » est en pause, il restait \(Format.clock(engine.remaining)).")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
            }
            HStack {
                Button("Choisir autre chose") { engine.stop(as: .interrupted) }
                Button("Insérer une tâche urgente…") { showPicker = true }
                Button {
                    engine.resume()
                } label: {
                    Label("Reprendre", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
        }
        .sheet(isPresented: $showPicker) {
            TaskPickerView(title: "Tâche urgente à mettre en tête du plan") { task in
                model.putFirst(task.id)
                engine.stop(as: .interrupted)
            }
            .environment(model)
        }
    }
}

/// Fin du minuteur : on décide de la suite.
struct OutcomeView: View {
    @Environment(FocusEngine.self) private var engine

    var body: some View {
        if let current = engine.current {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.seal")
                    .font(.system(size: 44))
                    .foregroundStyle(.green)
                Text("Session terminée")
                    .font(.title)
                Text("\(Format.minutes(engine.elapsed / 60)) sur « \(current.action.content) »")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 560)
                HStack(spacing: 12) {
                    Button {
                        Task { await engine.markDone() }
                    } label: {
                        Label("Terminé, cocher dans Todoist", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    Button {
                        engine.continueSameAction()
                    } label: {
                        Label("Je continue (\(Int(current.planned / 60)) min)", systemImage: "arrow.clockwise")
                    }
                    Button {
                        engine.takeBreakAfterSession()
                    } label: {
                        Label("Pause", systemImage: "cup.and.saucer")
                    }
                    Button("Arrêter là") { engine.stop(as: .partial) }
                }
                .controlSize(.large)
                .disabled(engine.isClosing)
                if engine.isClosing {
                    ProgressView().controlSize(.small)
                }
                if let error = engine.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
            }
        }
    }
}

struct BreakView: View {
    @Environment(FocusEngine.self) private var engine

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 44))
                .foregroundStyle(.brown)
            Text("Pause")
                .font(.title)
            Text(Format.clock(engine.breakRemaining))
                .font(.system(size: 56, weight: .light, design: .rounded).monospacedDigit())
            Text("Lève-toi, bois de l'eau, regarde loin de l'écran.")
                .foregroundStyle(.secondary)
            Button("Passer la pause") { engine.skipBreak() }
                .controlSize(.large)
        }
    }
}
