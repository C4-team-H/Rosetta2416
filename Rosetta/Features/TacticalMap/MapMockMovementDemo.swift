#if DEBUG
import Foundation
import SwiftUI

struct MapMockMovementDemo: View {
    @State private var viewModel: TacticalMapViewModel
    @State private var session: GameSessionState

    init() {
        let sessionState = GameSessionState(
            localPlayer: PlayerState(
                id: "local-player",
                name: "You",
                worldPosition: GameMapLayout.playerSpawnPosition,
                isConnected: true
            )
        )
        _session = State(initialValue: sessionState)
        _viewModel = State(initialValue: TacticalMapViewModel(sessionState: sessionState))
    }
    @State private var startedAt = Date.now

    var body: some View {
        GameplayHUDView(
            viewModel: viewModel,
            session: session,
            mapDebugViewModel: nil,
            onRetryCheckpoint: {},
            onPlayAgain: {},
            onMainMenu: {},
            onLeaveGame: {}
        )
            .background(.black)
            .task {
                await runDemo()
            }
    }

    @MainActor
    private func runDemo() async {
        startedAt = .now
        viewModel.showsTeammateOnMap = true
        viewModel.sessionState.beginGameplay()
        viewModel.openMap()

        while !Task.isCancelled {
            viewModel.applyMockMovement(elapsedTime: Date.now.timeIntervalSince(startedAt))
            do {
                try await Task.sleep(for: .milliseconds(80))
            } catch {
                return
            }
        }
    }
}

#Preview("Live tactical map") {
    MapMockMovementDemo()
}
#endif
