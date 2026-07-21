import Foundation
import SwiftUI

struct StoryProgressHUDView: View {
    let session: GameSessionState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.sharedStory.currentChapter.displayName.uppercased())
                .font(GameFont.caption1Bold)
                .foregroundStyle(.cyan)

            progressRow("ENERGY", value: session.progress.energy, color: energyColor)
            progressRow("AI INTEL", value: session.progress.intelligence, color: .blue)
            progressRow("ENGINE", value: session.progress.engineProgress, color: .orange)

            if let mission = session.sharedStory.activeMission {
                Divider().overlay(.white.opacity(0.25))
                Label(mission.title, systemImage: "scope")
                    .font(GameFont.caption1Bold)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                if let objective = session.activeObjective {
                    Text(objective.definition.description)
                    .font(GameFont.caption2)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
                }
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
                Text(title).font(GameFont.custom(size: 9, weight: 700))
                Spacer()
                Text("\(Int(value))%").font(GameFont.custom(size: 9, weight: 700))
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
    let onDismiss: () -> Void

    @State private var displayedCount: Int = 0
    @State private var isTyping: Bool = true
    @State private var continuePulse: Bool = false
    @State private var timer: Timer? = nil

    private var currentText: String {
        let text = line.text
        guard displayedCount < text.count else { return text }
        let index = text.index(text.startIndex, offsetBy: displayedCount)
        return String(text[..<index])
    }

    var body: some View {
        GeometryReader { geometry in
            // Joystick berjarak 160 point dari bagian bawah layar (joystickRadius: 30 + offset: 100)
            let joystickYFromBottom: CGFloat = 140
            let joystickCenterY = geometry.size.height - joystickYFromBottom

            let frameWidth = min(800, geometry.size.width * 0.65)
            let frameHeight = max(180, frameWidth * (1080.0 / 1440.0)) // Rasio asli gambar DialogueFrame (1440x1080 = 0.75)
            let textWidth = frameWidth * 0.74
            let horizontalPadding = max(16, frameWidth * 0.06)
            let verticalPadding = max(18, frameHeight * 0.11)
            let bodyFontSize = max(11, min(15, frameWidth * 0.032))
            let labelFontSize = max(8, min(12, frameWidth * 0.024))

            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        handleTap()
                    }

                VStack(alignment: .center, spacing: max(2, frameHeight * 0.015)) {
                    Text(currentText)
                        .font(GameFont.custom(size: bodyFontSize))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(max(2, bodyFontSize * 0.25))
                        .fixedSize(horizontal: false, vertical: true)

                    if !isTyping {
                        Text("TAP TO CONTINUE")
                            .font(GameFont.custom(size: labelFontSize, weight: 600))
                            .foregroundStyle(.cyan.opacity(0.9))
                            .opacity(continuePulse ? 0.3 : 1.0)
                            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: continuePulse)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 2)
                            .onAppear { continuePulse = true }
                    }
                }
                .frame(width: textWidth, alignment: .center)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .frame(width: frameWidth)
                .frame(minHeight: frameHeight)
                .background {
                    Image("DialogueFrame")
                        .resizable()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    handleTap()
                }
                .position(x: geometry.size.width / 2, y: joystickCenterY)
            }
            .ignoresSafeArea()
        }
        .task(id: line.id) {
            startTyping()
        }
        .onDisappear {
            stopTyping()
        }
        .accessibilityElement(children: .combine)
    }

    private func startTyping() {
        stopTyping()
        displayedCount = 0
        isTyping = true
        continuePulse = false
        AudioManager.shared.playTypingSound(volume: 0.8)

        timer = Timer.scheduledTimer(withTimeInterval: 0.035, repeats: true) { _ in
            Task { @MainActor in
                if self.displayedCount < self.line.text.count {
                    self.displayedCount += 1
                } else {
                    self.finishTyping()
                }
            }
        }
    }

    private func finishTyping() {
        timer?.invalidate()
        timer = nil
        displayedCount = line.text.count
        isTyping = false
        AudioManager.shared.stopTypingSound()
    }

    private func stopTyping() {
        timer?.invalidate()
        timer = nil
        AudioManager.shared.stopTypingSound()
    }

    private func handleTap() {
        if isTyping {
            finishTyping()
        } else {
            onDismiss()
        }
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
                    .font(GameFont.custom(size: 54))
                    .foregroundStyle(session.phase == .victory ? .green : .red)
                Text(session.phase == .victory ? "SHIP RESTORED" : "GAME OVER")
                    .font(GameFont.largeTitleBold)
                    .foregroundStyle(.white)

                if session.phase == .victory {
                    Grid(horizontalSpacing: 24, verticalSpacing: 8) {
                        GridRow { Text("Elapsed time"); Text(session.stats.elapsedTime.formattedDuration) }
                        GridRow { Text("Missions"); Text("\(session.sharedStory.completedMissionIDs.count)/6") }
                        GridRow { Text("Drawing attempts"); Text("\(session.stats.drawingAttempts)") }
                        GridRow { Text("Kitchen restores"); Text("\(session.stats.kitchenRestores)") }
                        GridRow { Text("Final energy"); Text("\(Int(session.energy))%") }
                        GridRow { Text("Final intelligence"); Text("\(Int(session.sharedStory.intelligence))%") }
                        GridRow { Text("Final engine"); Text("\(Int(session.sharedStory.engineProgress))%") }
                    }
                    .font(GameFont.callout)
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
        case .engineInitial: "Engine Initial"
        case .storage: "Storage"
        case .engineFinal: "Engine Final"
        case .cockpit: "Cockpit"
        case .victory: "Victory"
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
