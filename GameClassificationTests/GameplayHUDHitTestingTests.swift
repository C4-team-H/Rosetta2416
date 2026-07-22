import CoreGraphics
import Testing
import UIKit
@testable import GameClassification

@Suite("Gameplay HUD hit testing")
@MainActor
struct GameplayHUDHitTestingTests {
    @Test("Map button routes touches across its full visible frame")
    func fullMapButtonIsTappable() {
        let container = makeContainer()
        let touchTarget = UIView(frame: container.bounds)
        container.addSubview(touchTarget)

        let buttonFrame = GameplayHUDLayout.buttonFrame(
            at: 1,
            in: container.bounds,
            safeAreaInsets: container.safeAreaInsets
        )
        let testPoints = [
            CGPoint(x: buttonFrame.minX + 1, y: buttonFrame.minY + 1),
            CGPoint(x: buttonFrame.maxX - 1, y: buttonFrame.minY + 1),
            CGPoint(x: buttonFrame.minX + 1, y: buttonFrame.maxY - 1),
            CGPoint(x: buttonFrame.maxX - 1, y: buttonFrame.maxY - 1),
            CGPoint(x: buttonFrame.midX, y: buttonFrame.midY)
        ]

        for point in testPoints {
            #expect(container.hitTest(point, with: nil) === touchTarget)
        }
    }

    @Test("Gameplay touches outside the HUD controls pass through")
    func gameplayStillReceivesTouchesOutsideControls() {
        let container = makeContainer()
        container.addSubview(UIView(frame: container.bounds))

        #expect(container.hitTest(CGPoint(x: 300, y: 300), with: nil) == nil)
    }

    private func makeContainer() -> MapOverlayContainerView {
        let session = GameSessionState(localPlayer: PlayerState(
            id: "local",
            name: "Player",
            worldPosition: GameMapLayout.playerSpawnPosition,
            isConnected: true
        ))
        session.beginGameplay()
        while session.currentDialogue != nil {
            session.dismissDialogue()
        }

        let container = MapOverlayContainerView(
            viewModel: TacticalMapViewModel(sessionState: session),
            debugSettings: GameDebugSettings()
        )
        container.frame = CGRect(x: 0, y: 0, width: 844, height: 390)
        return container
    }
}
