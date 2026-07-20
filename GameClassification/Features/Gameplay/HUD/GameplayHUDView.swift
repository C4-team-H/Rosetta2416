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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var feedbackTrigger = 0

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

                MapButton(action: openMap)
                    .disabled(session.showLowEnergyAlert)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, 80)
                    .padding(.trailing, 16)
            }

            if let line = session.currentDialogue, session.phase != .gameOver, session.phase != .victory {
                AIDialogueOverlay(line: line)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    .task(id: line.id) {
                        try? await Task.sleep(for: .seconds(5))
                        session.dismissDialogue()
                    }
            }

            if let message = session.transientMessage, session.phase != .gameOver {
                Text(message)
                    .font(GameFont.calloutBold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.75), in: .capsule)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 132)
                    .task(id: message) {
                        try? await Task.sleep(for: .seconds(3))
                        session.clearTransientPresentation()
                    }
            }

            if let checkpoint = session.checkpointNotice, session.phase == .playing {
                Label("CHECKPOINT  \(checkpoint.displayName)", systemImage: "flag.checkered")
                    .font(GameFont.caption1Bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.blue.opacity(0.85), in: .capsule)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 88)
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

            if session.phase == .gameOver || session.phase == .victory {
                StoryTerminalOverlay(
                    session: session,
                    onRetry: onRetryCheckpoint,
                    onPlayAgain: onPlayAgain,
                    onMainMenu: onMainMenu
                )
                .zIndex(3)
            }

            if session.showLowEnergyAlert && session.phase != .gameOver && session.phase != .victory {
                LowEnergyAlertOverlay(session: session) {
                    session.dismissLowEnergyAlert()
                }
                .zIndex(4)
            }
        }
        .animation(overlayAnimation, value: viewModel.isMapPresented)
        .sensoryFeedback(.impact(weight: .light), trigger: feedbackTrigger)
    }

    private var overlayAnimation: Animation {
        reduceMotion ? .linear(duration: 0.12) : .easeInOut(duration: MapDesignTokens.overlayAnimationDuration)
    }

    private var mapTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96))
    }

    private func openMap() {
        AudioManager.shared.playButtonSound()
        feedbackTrigger += 1
        viewModel.openMap()
    }
    private func closeMap() {
        AudioManager.shared.playButtonSound()
        feedbackTrigger += 1
        viewModel.closeMap()
    }
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
