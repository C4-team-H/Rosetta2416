import CoreGraphics
import Foundation
import Observation

@MainActor
@Observable
final class GameSessionState {
    private(set) var phase: GamePhase = .preparing
    private(set) var localPlayer: PlayerState
    private(set) var teammate: PlayerState?
    private(set) var teammateConnectionState: TeammateConnectionState = .disconnected

    init(localPlayer: PlayerState) {
        self.localPlayer = localPlayer
    }

    func beginGameplay() {
        phase = .playing
    }

    func endGameplay() {
        phase = .preparing
    }

    func updateLocalPlayer(position: CGPoint) {
        guard position.isFinite, localPlayer.worldPosition != position else { return }
        localPlayer.worldPosition = position
    }

    func updateTeammate(position: CGPoint?, connectionState: TeammateConnectionState, name: String? = nil) {
        let cleanName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let teammateName = cleanName.flatMap { $0.isEmpty ? nil : $0 } ?? "Teammate"

        if teammate == nil, let position, position.isFinite {
            teammate = PlayerState(
                id: "teammate",
                name: teammateName,
                worldPosition: position,
                isConnected: connectionState == .connected
            )
        } else {
            if let position, position.isFinite { teammate?.worldPosition = position }
            if let cleanName, !cleanName.isEmpty { teammate?.name = cleanName }
            teammate?.isConnected = connectionState == .connected
        }

        teammateConnectionState = connectionState
    }

    func clearTeammate() {
        teammate = nil
        teammateConnectionState = .disconnected
    }
}
