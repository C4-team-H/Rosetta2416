import SwiftUI

struct GameplayHUDView: View {
    let viewModel: TacticalMapViewModel
    let session: GameSessionState
    #if DEBUG
    let mapDebugViewModel: MapDebugViewModel?
    #endif
    let onRetryCheckpoint: () -> Void
    let onPlayAgain: () -> Void
    let onMainMenu: () -> Void
    let onLeaveGame: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var feedbackTrigger = 0
    @State private var isPausePresented = false

    var body: some View {
        ZStack {
            #if DEBUG
            if DebugAvailability.isMapEditorAvailable, let mapDebugViewModel {
                MapDebugOverlayView(viewModel: mapDebugViewModel)
                    .zIndex(1)
            }
            #endif
            if viewModel.isGameplayActive && !viewModel.isMapPresented {
                StoryProgressHUDView(session: session)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.top, 16)
                    .padding(.leading, 16)

                VStack(spacing: GameplayHUDLayout.buttonSpacing) {
                    PauseButton(action: openPauseMenu)
                    MapButton(action: openMap)
                }
                .disabled(session.showLowEnergyAlert || session.isPaused || isPausePresented)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, GameplayHUDLayout.topPadding)
                .padding(.trailing, GameplayHUDLayout.trailingPadding)
            }

            if let line = session.currentDialogue, session.phase == .playing {
                AIDialogueOverlay(line: line) {
                    session.dismissDialogue()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .zIndex(5)
            }

            if let message = session.transientMessage, session.phase != .gameOver {
                Group {
                    if message.isAccessDeniedNotice {
                        AccessDeniedNoticeView(
                            message: message,
                            reduceMotion: reduceMotion
                        )
                    } else {
                        Text(message)
                            .font(GameFont.calloutBold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.black.opacity(0.75), in: .capsule)
                    }
                }
                .id(message)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 132)
                .transition(message.isAccessDeniedNotice ? accessDeniedTransition : .identity)
                .allowsHitTesting(false)
                .zIndex(4)
                .task(id: message) {
                    try? await Task.sleep(for: .seconds(3))
                    session.clearTransientPresentation()
                }
            }

            if let checkpoint = session.checkpointNotice, session.phase == .playing {
                CheckpointNoticeView(
                    checkpoint: checkpoint,
                    reduceMotion: reduceMotion
                )
                .id(checkpoint)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 76)
                .transition(checkpointTransition)
                .allowsHitTesting(false)
                .task(id: checkpoint) {
                    try? await Task.sleep(for: .seconds(2.5))
                    session.dismissCheckpointNotice()
                }
            }

            if viewModel.isMapPresented {
                TacticalMapView(viewModel: viewModel, onClose: closeMap)
                    .transition(mapTransition)
                    .zIndex(2)
            }

            // Original: if session.phase == .gameOver || session.phase == .victory {
            // DEBUG: if true {
            if session.phase == .gameOver || session.phase == .victory { // TEMPORARY DEBUG PREVIEW
                StoryTerminalOverlay(
                    session: session,
                    onRetry: onRetryCheckpoint,
                    onPlayAgain: onPlayAgain,
                    onMainMenu: onMainMenu
                )
                .zIndex(3)
            }

            if session.showLowEnergyAlert && (session.phase == .playing || session.isDrawing) {
                LowEnergyAlertOverlay(session: session) {
                    session.dismissLowEnergyAlert()
                }
                .zIndex(6)
            }

            if session.isPaused || isPausePresented {
                PauseMenuOverlay(
                    onKeepPlaying: {
                        session.setPaused(false)
                        isPausePresented = false
                    },
                    onMainMenu: {
                        session.setPaused(false)
                        isPausePresented = false
                        onLeaveGame()
                    }
                )
                .zIndex(7)
            }
        }
        .animation(overlayAnimation, value: viewModel.isMapPresented)
        .animation(accessDeniedAnimation, value: session.transientMessage)
        .animation(checkpointAnimation, value: session.checkpointNotice)
        .sensoryFeedback(.impact(weight: .light), trigger: feedbackTrigger)
    }

    private var overlayAnimation: Animation {
        reduceMotion ? .linear(duration: 0.12) : .easeInOut(duration: MapDesignTokens.overlayAnimationDuration)
    }

    private var mapTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96))
    }

    private var checkpointAnimation: Animation {
        reduceMotion ? .linear(duration: 0.12) : .spring(response: 0.42, dampingFraction: 0.76)
    }

    private var checkpointTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }

        return .asymmetric(
            insertion: .move(edge: .top)
                .combined(with: .scale(scale: 0.9, anchor: .top))
                .combined(with: .opacity),
            removal: .scale(scale: 0.96, anchor: .top)
                .combined(with: .opacity)
        )
    }

    private var accessDeniedAnimation: Animation {
        reduceMotion ? .linear(duration: 0.12) : .spring(response: 0.34, dampingFraction: 0.68)
    }

    private var accessDeniedTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }

        return .asymmetric(
            insertion: .move(edge: .top)
                .combined(with: .scale(scale: 0.88, anchor: .top))
                .combined(with: .opacity),
            removal: .scale(scale: 0.96, anchor: .top)
                .combined(with: .opacity)
        )
    }

    private func openMap() {
        AudioManager.shared.playButtonSound()
        feedbackTrigger += 1
        viewModel.openMap()
    }

    private func openPauseMenu() {
        AudioManager.shared.playButtonSound()
        feedbackTrigger += 1
        session.setPaused(true)
        isPausePresented = true
    }

    private func closeMap() {
        AudioManager.shared.playButtonSound()
        feedbackTrigger += 1
        viewModel.closeMap()
    }
}

private struct AccessDeniedNoticeView: View {
    let message: String
    let reduceMotion: Bool

    @State private var isActive = false

    var body: some View {
        HStack(spacing: 12) {
            lockBadge

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    statusLight

                    Text("SECURITY ALERT")
                        .font(GameFont.custom(size: 10, weight: 800))
                        .foregroundStyle(AccessDeniedPalette.warning)
                        .tracking(1.2)
                }

                Text("ACCESS DENIED")
                    .font(GameFont.custom(size: 19, weight: 800))
                    .foregroundStyle(.white)
                    .tracking(0.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 8)

            VStack(spacing: 4) {
                Image(systemName: "exclamationmark")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(AccessDeniedPalette.ink)
                    .frame(width: 24, height: 24)
                    .background(AccessDeniedPalette.warning, in: .circle)
                    .overlay {
                        Circle()
                            .strokeBorder(AccessDeniedPalette.ink, lineWidth: 2.5)
                    }

                Text("LOCKED")
                    .font(GameFont.custom(size: 9, weight: 800))
                    .foregroundStyle(AccessDeniedPalette.dangerHighlight)
                    .tracking(0.8)
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 13)
        .padding(.vertical, 9)
        .frame(width: 354, height: 72)
        .background(panelBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(AccessDeniedPalette.ink, lineWidth: 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.13), lineWidth: 1)
                .padding(5)
        }
        .overlay(alignment: .bottom) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            AccessDeniedPalette.danger.opacity(0),
                            AccessDeniedPalette.danger,
                            AccessDeniedPalette.warning,
                            AccessDeniedPalette.danger,
                            AccessDeniedPalette.danger.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 224, height: 4)
                .offset(y: 1)
        }
        .shadow(color: AccessDeniedPalette.danger.opacity(0.22), radius: 16, y: 5)
        .shadow(color: .black.opacity(0.46), radius: 12, y: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(message)
        .accessibilityValue("Security alert. Area locked.")
        .onAppear {
            isActive = true
        }
    }

    private var lockBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            AccessDeniedPalette.dangerHighlight,
                            AccessDeniedPalette.danger
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "lock.fill")
                .font(.system(size: 23, weight: .black))
                .foregroundStyle(.white)
                .shadow(color: AccessDeniedPalette.ink.opacity(0.5), radius: 0, y: 2)
                .rotationEffect(.degrees(isActive ? 0 : -8))
                .scaleEffect(isActive ? 1 : 0.76)
                .animation(
                    reduceMotion
                        ? .linear(duration: 0.01)
                        : .spring(response: 0.38, dampingFraction: 0.55).delay(0.08),
                    value: isActive
                )
        }
        .frame(width: 50, height: 50)
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(AccessDeniedPalette.ink, lineWidth: 3)
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(.white.opacity(0.34))
                .frame(width: 25, height: 3)
                .padding(.top, 6)
        }
        .overlay(alignment: .bottom) {
            HStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { _ in
                    Capsule()
                        .fill(AccessDeniedPalette.warning)
                        .frame(width: 7, height: 3)
                        .rotationEffect(.degrees(-28))
                }
            }
            .padding(.bottom, 5)
        }
    }

    private var statusLight: some View {
        ZStack {
            Circle()
                .stroke(AccessDeniedPalette.danger.opacity(0.65), lineWidth: 2)
                .frame(width: 8, height: 8)
                .scaleEffect(reduceMotion ? 1 : (isActive ? 2.1 : 0.8))
                .opacity(reduceMotion ? 0 : (isActive ? 0 : 0.9))
                .animation(
                    reduceMotion
                        ? nil
                        : .easeOut(duration: 0.9).repeatForever(autoreverses: false),
                    value: isActive
                )

            Circle()
                .fill(AccessDeniedPalette.dangerHighlight)
                .frame(width: 7, height: 7)
                .shadow(color: AccessDeniedPalette.danger.opacity(0.9), radius: 5)
        }
        .frame(width: 9, height: 9)
    }

    private var panelBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(AccessDeniedPalette.ink.opacity(0.78))
                .offset(y: 5)

            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            AccessDeniedPalette.shellHighlight,
                            AccessDeniedPalette.shell
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}

private enum AccessDeniedPalette {
    static let ink = Color(red: 0.025, green: 0.065, blue: 0.075)
    static let shell = Color(red: 0.11, green: 0.16, blue: 0.18)
    static let shellHighlight = Color(red: 0.27, green: 0.34, blue: 0.35)
    static let danger = Color(red: 0.9, green: 0.12, blue: 0.12)
    static let dangerHighlight = Color(red: 1.0, green: 0.34, blue: 0.25)
    static let warning = Color(red: 1.0, green: 0.76, blue: 0.16)
}

private extension String {
    var isAccessDeniedNotice: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!"))
            .lowercased() == "access denied"
    }
}

private struct CheckpointNoticeView: View {
    let checkpoint: CheckpointID
    let reduceMotion: Bool

    @State private var isPresented = false

    var body: some View {
        HStack(spacing: 12) {
            checkpointIcon

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(CheckpointNoticePalette.saved)
                        .frame(width: 7, height: 7)
                        .shadow(
                            color: CheckpointNoticePalette.saved.opacity(isPresented ? 0.9 : 0),
                            radius: isPresented ? 5 : 0
                        )

                    Text("CHECKPOINT REACHED")
                        .font(GameFont.custom(size: 11, weight: 800))
                        .foregroundStyle(CheckpointNoticePalette.gold)
                        .tracking(1.1)
                }

                Text(checkpoint.displayName.uppercased())
                    .font(GameFont.custom(size: 17, weight: 800))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 8)

            VStack(spacing: 3) {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(CheckpointNoticePalette.ink)
                    .frame(width: 22, height: 22)
                    .background(CheckpointNoticePalette.saved, in: .circle)
                    .overlay {
                        Circle()
                            .strokeBorder(CheckpointNoticePalette.ink, lineWidth: 2.5)
                    }

                Text("SAVED")
                    .font(GameFont.custom(size: 9, weight: 800))
                    .foregroundStyle(CheckpointNoticePalette.saved)
                    .tracking(0.8)
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 13)
        .padding(.vertical, 9)
        .frame(width: 344, height: 68)
        .background(panelBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 19)
                .strokeBorder(CheckpointNoticePalette.ink, lineWidth: 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                .padding(5)
        }
        .overlay(alignment: .bottom) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            CheckpointNoticePalette.gold.opacity(0),
                            CheckpointNoticePalette.gold,
                            CheckpointNoticePalette.gold.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 190, height: 3)
                .offset(y: 1)
        }
        .shadow(color: .black.opacity(0.42), radius: 12, y: 7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Checkpoint reached")
        .accessibilityValue("\(checkpoint.displayName). Progress saved.")
        .onAppear {
            guard !reduceMotion else {
                isPresented = true
                return
            }

            withAnimation(.easeOut(duration: 0.42).delay(0.12)) {
                isPresented = true
            }
        }
    }

    private var checkpointIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13)
                .fill(
                    LinearGradient(
                        colors: [CheckpointNoticePalette.goldHighlight, CheckpointNoticePalette.gold],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "flag.checkered")
                .font(.system(size: 23, weight: .black))
                .foregroundStyle(CheckpointNoticePalette.ink)
                .rotationEffect(.degrees(isPresented ? 0 : -8), anchor: .bottomLeading)
                .scaleEffect(isPresented ? 1 : 0.82)
        }
        .frame(width: 48, height: 48)
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .strokeBorder(CheckpointNoticePalette.ink, lineWidth: 3)
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(.white.opacity(0.42))
                .frame(width: 23, height: 3)
                .padding(.top, 6)
        }
    }

    private var panelBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 19)
                .fill(CheckpointNoticePalette.ink.opacity(0.72))
                .offset(y: 4)

            RoundedRectangle(cornerRadius: 19)
                .fill(
                    LinearGradient(
                        colors: [
                            CheckpointNoticePalette.shellHighlight,
                            CheckpointNoticePalette.shell
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}

private enum CheckpointNoticePalette {
    static let ink = Color(red: 0.025, green: 0.075, blue: 0.09)
    static let shell = Color(red: 0.08, green: 0.18, blue: 0.21)
    static let shellHighlight = Color(red: 0.19, green: 0.35, blue: 0.38)
    static let gold = Color(red: 1.0, green: 0.72, blue: 0.18)
    static let goldHighlight = Color(red: 1.0, green: 0.88, blue: 0.39)
    static let saved = Color(red: 0.35, green: 0.91, blue: 0.58)
}

private extension CheckpointID {
    var displayName: String {
        switch self {
        case .sleepingRoomStart: "Sleeping Room"
        case .laboratoryEntered: "Laboratory Entered"
        case .laboratoryCompleted: "Laboratory Restored"
        case .engine10: "Engine 10%"
        case .engine40: "Power Disruption"
        case .engine60: "Engine 60%"
        case .advancedToolsAcquired: "Advanced Tools"
        case .engine100: "Engine Restored"
        case .cockpitEntered: "Cockpit Entered"
        }
    }
}
