import Foundation
import SwiftUI

struct StoryProgressHUDView: View {
    let session: GameSessionState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            chapterHeader
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 10) {
                resourceBar(
                    title: "Robo Intelligence",
                    value: session.progress.intelligence,
                    iconName: "AIKnowledgeBarIcon",
                    tint: StoryHUDPalette.intelligence
                )
                resourceBar(
                    title: "Engine Progress",
                    value: session.progress.engineProgress,
                    iconName: "EngineBarIcon",
                    tint: StoryHUDPalette.engine
                )
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)

            if let mission = session.sharedStory.activeMission {
                missionPanel(mission)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            }
        }
        .frame(width: 316, alignment: .leading)
        .background(panelBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(StoryHUDPalette.ink, lineWidth: 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                .padding(5)
        }
        .shadow(color: .black.opacity(0.38), radius: 12, y: 7)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Story progress")
    }

    private var chapterHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(StoryHUDPalette.intelligence)

                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(StoryHUDPalette.ink)
            }
            .frame(width: 38, height: 38)
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(StoryHUDPalette.ink, lineWidth: 3)
            }
            .overlay(alignment: .top) {
                Capsule()
                    .fill(.white.opacity(0.42))
                    .frame(width: 18, height: 3)
                    .padding(.top, 5)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("MISSION CONTROL")
                    .font(GameFont.custom(size: 15, weight: 800))
                    .foregroundStyle(.white)
                    .tracking(0.6)

                Text(session.sharedStory.currentChapter.displayName.uppercased())
                    .font(GameFont.custom(size: 10, weight: 700))
                    .foregroundStyle(StoryHUDPalette.intelligence)
                    .tracking(0.8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 8)

            VStack(spacing: 4) {
                statusLight(color: StoryHUDPalette.engine)
                statusLight(color: StoryHUDPalette.intelligence)
                statusLight(color: StoryHUDPalette.mission)
            }
            .padding(6)
            .background(StoryHUDPalette.ink.opacity(0.84), in: .capsule)
            .overlay { Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Mission control, \(session.sharedStory.currentChapter.displayName)"
        )
    }

    private func resourceBar(title: String, value: Double, iconName: String, tint: Color) -> some View {
        let normalizedValue = value.clamped(to: 0...100)
        let percentage = Int(normalizedValue)

        return HStack(spacing: 10) {
            Image(iconName)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 44, height: 44)
                .shadow(color: .black.opacity(0.28), radius: 2, y: 2)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(GameFont.custom(size: 14, weight: 700))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Spacer(minLength: 6)

                    Text("\(percentage)%")
                        .font(GameFont.custom(size: 13, weight: 800))
                        .foregroundStyle(tint)
                        .monospacedDigit()
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(StoryHUDPalette.ink.opacity(0.86), in: .capsule)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(StoryHUDPalette.ink)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [tint.opacity(0.72), tint],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * CGFloat(normalizedValue) / 100)
                            .overlay(alignment: .top) {
                                Capsule()
                                    .fill(.white.opacity(0.34))
                                    .frame(height: 2)
                                    .padding(.horizontal, 4)
                                    .padding(.top, 2)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .frame(height: 12)
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(.white.opacity(0.16), lineWidth: 1)
                }
            }
        }
        .padding(9)
        .background(StoryHUDPalette.well, in: .rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(StoryHUDPalette.ink, lineWidth: 3)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(percentage) percent")
    }

    private func missionPanel(_ mission: MissionState) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "scope")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(StoryHUDPalette.mission, in: .rect(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(StoryHUDPalette.ink, lineWidth: 3)
                }
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(.white.opacity(0.34))
                        .frame(width: 18, height: 3)
                        .padding(.top, 5)
                }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(StoryHUDPalette.mission)
                        .frame(width: 7, height: 7)

                    Text("ACTIVE OBJECTIVE")
                        .font(GameFont.custom(size: 10, weight: 800))
                        .foregroundStyle(StoryHUDPalette.mission)
                        .tracking(0.8)
                }

                if let objective = session.activeObjective {
                    Text(objective.definition.title)
                        .font(GameFont.custom(size: 16, weight: 800))
                        .foregroundStyle(missionChromeColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    Text(objective.definition.description)
                        .font(GameFont.custom(size: 12, weight: 500))
                        .foregroundStyle(missionChromeColor.opacity(0.76))
                        .lineLimit(3)
                } else {
                    Text(taskTitle(for: mission))
                        .font(GameFont.custom(size: 16, weight: 800))
                        .foregroundStyle(missionChromeColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(11)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(StoryHUDPalette.ink.opacity(missionBackgroundOpacity))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(StoryHUDPalette.ink, lineWidth: 3)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .strokeBorder(StoryHUDPalette.mission.opacity(0.28), lineWidth: 1)
                .padding(4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Active objective")
        .accessibilityValue(missionAccessibilityValue(for: mission))
    }

    private var panelBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(StoryHUDPalette.ink.opacity(0.65))
                .offset(y: 5)

            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [StoryHUDPalette.shellHighlight, StoryHUDPalette.shell],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    private func statusLight(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 5, height: 5)
            .overlay { Circle().stroke(.white.opacity(0.3), lineWidth: 0.5) }
    }

    private func taskTitle(for mission: MissionState) -> String {
        switch mission.id {
        case .findLaboratory:
            "Find the laboratory."
        default:
            mission.title
        }
    }

    private func missionAccessibilityValue(for mission: MissionState) -> String {
        guard let objective = session.activeObjective else {
            return taskTitle(for: mission)
        }

        return "\(objective.definition.title). \(objective.definition.description)"
    }

    private var missionChromeColor: Color {
        switch session.sharedStory.powerState {
        case .off, .disrupted, .basicPower, .fullyRestored:
            .white
        }
    }

    private var missionBackgroundOpacity: Double {
        switch session.sharedStory.powerState {
        case .off, .disrupted:
            0.72
        case .basicPower, .fullyRestored:
            0.54
        }
    }

}

private enum StoryHUDPalette {
    static let ink = Color(red: 0.025, green: 0.075, blue: 0.09)
    static let shell = Color(red: 0.10, green: 0.22, blue: 0.25)
    static let shellHighlight = Color(red: 0.22, green: 0.39, blue: 0.41)
    static let well = Color(red: 0.045, green: 0.12, blue: 0.14).opacity(0.94)
    static let intelligence = Color(red: 0.31, green: 0.84, blue: 0.91)
    static let engine = Color(red: 1.0, green: 0.74, blue: 0.20)
    static let mission = Color(red: 0.96, green: 0.32, blue: 0.27)
}

struct AIDialogueOverlay: View {
    let line: AIDialogueLine
    let onDismiss: () -> Void

    @State private var displayedCount: Int = 0
    @State private var isTyping: Bool = true
    @State private var continuePulse: Bool = false
    @State private var timer: Timer? = nil

    private var dialogueFrameImageName: String {
        let lowerText = line.text.lowercased()
        if lowerText.contains("astro:") {
            return "AstroDialogueFrame"
        } else if lowerText.contains("robo:") {
            return "RoboDialogueFrame"
        }
        return "AstroDialogueFrame"
    }

    private var currentText: String {
        let text = line.text
        guard displayedCount < text.count else { return text }
        let index = text.index(text.startIndex, offsetBy: displayedCount)
        return String(text[..<index])
    }

    var body: some View {
        GeometryReader { geometry in
            let frameYFromBottom: CGFloat = max(140, geometry.size.height * 0.1)
            let frameCenterY = geometry.size.height - frameYFromBottom

            let frameWidth = geometry.size.width * 0.6 // Ukuran frame terhadap widht device
            let frameHeight = frameWidth * (232.0 / 1254.0) // Rasio gambar AstroDialogueFrame & RoboDialogueFrame (1254x232)
            let textWidth = frameWidth * 0.7
            let horizontalPadding = max(16, frameWidth * 0.04)
            let verticalPadding = max(10, frameHeight * 0.10)
            let bodyFontSize = max(11, min(16, frameWidth * 0.026))
            let labelFontSize = max(8, min(12, frameWidth * 0.020))

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
                .offset(y: -6)
                .frame(width: frameWidth)
                .frame(minHeight: frameHeight)
                .background {
                    Image(dialogueFrameImageName)
                        .resizable()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    handleTap()
                }
                .position(x: geometry.size.width / 2 + 30, y: frameCenterY)
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

            if session.phase == .victory {
                ZStack(alignment: .top) {
                    Image("VictoryPopUp")
                        .resizable()
                        .scaledToFit()

                    VStack(spacing: 12) {
                        Grid(horizontalSpacing: 24, verticalSpacing: 6) {
                            GridRow {
                                Text("Elapsed time")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(session.stats.elapsedTime.formattedDuration)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            GridRow {
                                Text("Missions")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(session.sharedStory.completedMissionIDs.count)/6")
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            GridRow {
                                Text("Drawing attempts")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(session.stats.drawingAttempts)")
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            GridRow {
                                Text("Kitchen restores")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(session.stats.kitchenRestores)")
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            GridRow {
                                Text("Final energy")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(Int(session.energy))%")
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                        .font(GameFont.callout)
                        .foregroundStyle(.white)

                        VStack {
                            Button(action: {
                                AudioManager.shared.playButtonSound()
                                onMainMenu()
                            }) {
                                Text("MAIN MENU")
                                    .font(GameFont.bodyBold)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        Color.green.opacity(0.4),
                                        in: .rect(cornerRadius: 10)
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white.opacity(0.4), lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 6)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 170)
                    .padding(.bottom, 16)
                }
                .frame(width: 500)
                .onTapGesture {
                    // Prevent tap on card from passing through.
                }
            } else if session.phase == .gameOver {
                GameOverPanel(onRetry: onRetry, onMainMenu: onMainMenu)
            }
        }
    }
}

private struct GameOverPanel: View {
    let onRetry: () -> Void
    let onMainMenu: () -> Void

    var body: some View {
        Image("GameOver")
            .resizable()
            .scaledToFit()
            .accessibilityLabel("Game over")
            .overlay {
                GeometryReader { geometry in
                    VStack(spacing: max(10, geometry.size.height * 0.035)) {
                        Text("Energy reached zero. Restore the latest safe checkpoint to continue.")
                            .font(GameFont.custom(size: 16, weight: 700))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)
                            .shadow(color: .black.opacity(0.8), radius: 2, y: 1)

                        HStack(spacing: max(10, geometry.size.width * 0.025)) {
                            Button("RETRY CHECKPOINT", action: onRetry)
                                .buttonStyle(GameOverActionButtonStyle(isPrimary: true))

                            Button("MAIN MENU", action: onMainMenu)
                                .buttonStyle(GameOverActionButtonStyle(isPrimary: false))
                        }
                    }
                    .frame(width: geometry.size.width * 0.76)
                    .position(
                        x: geometry.size.width / 2,
                        y: geometry.size.height * 0.68
                    )
                }
            }
            .aspectRatio(618.0 / 412.0, contentMode: .fit)
            .frame(maxWidth: 720)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
    }
}

private struct GameOverActionButtonStyle: ButtonStyle {
    let isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(GameFont.custom(size: 15, weight: 800))
            .foregroundStyle(isPrimary ? Color.black : Color.white)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                isPrimary
                    ? Color(red: 0.88, green: 0.91, blue: 0.91)
                    : Color(red: 0.24, green: 0.03, blue: 0.10).opacity(0.88),
                in: .rect(cornerRadius: 10)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isPrimary ? Color.black : Color.white.opacity(0.9), lineWidth: 2)
            }
            .shadow(color: .black.opacity(0.45), radius: 3, y: 2)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#if DEBUG
@MainActor
private struct GameOverOverlayPreview: View {
    private let session: GameSessionState

    init() {
        let session = GameSessionState(
            localPlayer: PlayerState(
                id: "preview-player",
                name: "Preview",
                worldPosition: GameMapLayout.playerSpawnPosition,
                isConnected: true
            )
        )
        session.beginGameplay()
        session.updateEnergy(deltaTime: 10_000, isMoving: true)
        self.session = session
    }

    var body: some View {
        StoryTerminalOverlay(
            session: session,
            onRetry: {},
            onPlayAgain: {},
            onMainMenu: {}
        )
        .background(.black)
    }
}

#Preview("Game Over", traits: .landscapeLeft) {
    GameOverOverlayPreview()
}
#endif

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
