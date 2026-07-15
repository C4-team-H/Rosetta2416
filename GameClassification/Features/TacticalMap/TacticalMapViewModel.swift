import CoreGraphics
import Foundation
import Observation

@MainActor
@Observable
final class TacticalMapViewModel {
    let sessionState: GameSessionState

    private(set) var isMapPresented = false
    var gameplayMode: MapGameplayMode = .continueGameplay
    var showsTeammateOnMap = true
    var markers = GameMapLayout.defaultMarkers

    init(sessionState: GameSessionState) {
        self.sessionState = sessionState
    }

    var isGameplayActive: Bool {
        sessionState.phase == .playing
    }

    var localPlayer: MapPlayerPosition {
        MapPlayerPosition(
            id: sessionState.localPlayer.id,
            name: sessionState.localPlayer.name,
            worldPosition: sessionState.localPlayer.worldPosition,
            isLocalPlayer: true,
            isConnected: sessionState.localPlayer.isConnected
        )
    }

    var teammate: MapPlayerPosition? {
        guard showsTeammateOnMap, let teammate = sessionState.teammate else { return nil }

        return MapPlayerPosition(
            id: teammate.id,
            name: teammate.name,
            worldPosition: teammate.worldPosition,
            isLocalPlayer: false,
            isConnected: teammate.isConnected
        )
    }

    var teammateConnectionState: TeammateConnectionState {
        sessionState.teammateConnectionState
    }

    var visibleMarkers: [MapMarker] {
        markers.filter(\.isVisible)
    }

    var shouldRunLocalSimulation: Bool {
        !isMapPresented || gameplayMode == .continueGameplay
    }

    func openMap() {
        guard isGameplayActive else { return }
        isMapPresented = true
    }

    func closeMap() {
        isMapPresented = false
    }

    func toggleMap() {
        isMapPresented ? closeMap() : openMap()
    }

    func completeActiveMissions() {
        markers = markers.map { marker in
            marker.type == .activeMission ? marker.replacingType(with: .completedMission) : marker
        }
    }

    func resetMissionMarkers() {
        markers = GameMapLayout.defaultMarkers
    }

#if DEBUG
    func applyMockMovement(elapsedTime: TimeInterval) {
        let center = CGPoint(x: 1_000, y: 1_000)
        let localAngle = CGFloat(elapsedTime * 0.65)
        let teammateAngle = CGFloat(elapsedTime * -0.5)

        sessionState.updateLocalPlayer(
            position: CGPoint(
                x: center.x + cos(localAngle) * 320,
                y: center.y + sin(localAngle) * 240
            )
        )
        sessionState.updateTeammate(
            position: CGPoint(
                x: center.x + cos(teammateAngle) * 250,
                y: center.y + sin(teammateAngle) * 340
            ),
            connectionState: .connected,
            name: "Scout"
        )
    }
#endif
}
