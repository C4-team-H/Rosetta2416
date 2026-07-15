import Foundation
import SwiftUI

struct StoryProgressHUDView: View {
    let session: GameSessionState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.sharedStory.currentChapter.displayName.uppercased())
                .font(.caption.bold())
                .foregroundStyle(.cyan)

            progressRow("ENERGY", value: session.progress.energy, color: energyColor)
            progressRow("AI INTEL", value: session.progress.intelligence, color: .blue)
            progressRow("ENGINE", value: session.progress.engineProgress, color: .orange)

            if let objective = session.activeObjective {
                Divider().overlay(.white.opacity(0.25))
                Label(objective.definition.title, systemImage: "scope")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(objective.definition.description)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
            }
        }
        .padding(12)
        .frame(width: 220, alignment: .leading)
        .background(.black.opacity(0.58), in: .rect(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).stroke(.cyan.opacity(0.25)) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Story progress")
    }

    private func progressRow(_ title: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title).font(.system(size: 9, weight: .bold))
                Spacer()
                Text("\(Int(value))%").font(.system(size: 9, weight: .bold, design: .monospaced))
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.15))
                    Capsule().fill(color).frame(width: geometry.size.width * value.clamped(to: 0...100) / 100)
                }
            }
            .frame(height: 7)
        }
        .foregroundStyle(.white)
    }

    private var energyColor: Color {
        switch session.energy {
        case 50...: .green
        case 20...: .orange
        default: .red
        }
    }
}

struct AIDialogueOverlay: View {
    let line: AIDialogueLine

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "waveform.circle.fill")
                .font(.title2)
                .foregroundStyle(.cyan)
            VStack(alignment: .leading, spacing: 3) {
                Text("SHIP AI").font(.caption2.bold()).foregroundStyle(.cyan)
                Text(line.text).font(.callout).foregroundStyle(.white)
            }
        }
        .padding(14)
        .frame(maxWidth: 520, alignment: .leading)
        .background(.black.opacity(0.82), in: .rect(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).stroke(.cyan.opacity(0.45)) }
        .accessibilityElement(children: .combine)
    }
}

struct StoryTerminalOverlay: View {
    let session: GameSessionState
    let onRetry: () -> Void
    let onPlayAgain: () -> Void
    let onMainMenu: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.84).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: session.phase == .victory ? "sparkles" : "bolt.slash.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(session.phase == .victory ? .green : .red)
                Text(session.phase == .victory ? "SHIP RESTORED" : "GAME OVER")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                if session.phase == .victory {
                    Grid(horizontalSpacing: 24, verticalSpacing: 8) {
                        GridRow { Text("Elapsed time"); Text(session.stats.elapsedTime.formattedDuration) }
                        GridRow { Text("Objectives"); Text("\(session.sharedStory.completedObjectiveIDs.count)") }
                        GridRow { Text("Drawing attempts"); Text("\(session.stats.drawingAttempts)") }
                        GridRow { Text("Kitchen restores"); Text("\(session.stats.kitchenRestores)") }
                        GridRow { Text("Final energy"); Text("\(Int(session.energy))%") }
                    }
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.8))
                } else {
                    Text("Energy reached zero. Restore the latest safe checkpoint to continue.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.75))
                }

                HStack(spacing: 12) {
                    if session.phase == .gameOver {
                        Button("RETRY CHECKPOINT", action: onRetry).buttonStyle(.borderedProminent)
                    } else {
                        Button("PLAY AGAIN", action: onPlayAgain).buttonStyle(.borderedProminent)
                    }
                    Button("MAIN MENU", action: onMainMenu).buttonStyle(.bordered)
                }
                .controlSize(.large)
            }
            .padding(28)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 24))
            .padding(24)
        }
    }
}

private extension StoryChapter {
    var displayName: String {
        switch self {
        case .sleepingRoom: "Sleeping Room"
        case .laboratory: "Laboratory"
        case .enginePhaseOne: "Engine Phase One"
        case .enginePhaseTwo: "Engine Phase Two"
        case .engineBlocked: "Engine Blocked"
        case .storage: "Storage"
        case .engineFinal: "Engine Final"
        case .cockpit: "Cockpit"
        case .completed: "Completed"
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private extension TimeInterval {
    var formattedDuration: String {
        let totalSeconds = max(0, Int(self))
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}
