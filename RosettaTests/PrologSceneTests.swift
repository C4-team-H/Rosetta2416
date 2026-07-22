import SpriteKit
import Testing
@testable import Rosetta

@Suite("Prolog Scene Tests")
@MainActor
struct PrologSceneTests {
    @Test("Prolog presents a readable mission archive hierarchy")
    func missionArchiveHierarchy() throws {
        let sceneSize = CGSize(width: 932, height: 430)
        let scene = PrologScene(size: sceneSize) {}
        let view = SKView(frame: CGRect(origin: .zero, size: sceneSize))
        view.presentScene(scene)
        defer {
            view.presentScene(nil)
            AudioManager.shared.stopBackgroundMusic()
        }

        let background = try #require(scene.childNode(withName: "prologBackground"))
        let ambientLayer = try #require(scene.childNode(withName: "prologAmbientLayer"))
        let panel = try #require(scene.childNode(withName: "prologArchivePanel") as? SKShapeNode)
        let title = try #require(scene.childNode(withName: "//prologTitleLabel") as? SKLabelNode)
        let status = try #require(scene.childNode(withName: "//prologStatusLabel") as? SKLabelNode)
        let callToAction = try #require(scene.childNode(withName: "//prologContinueLabel") as? SKLabelNode)

        #expect(background.hasActions())
        #expect(ambientLayer.children.count >= 40)
        #expect(panel.path != nil)
        #expect(title.text == "A NEW FRONTIER")
        #expect(status.text == "SIGNAL STABLE")
        #expect(callToAction.text == "TAP TO REVEAL")
        #expect(scene.children.filter { $0.name == "prologArchivePanel" }.count == 1)
        #expect(scene["//prologProgressSegment"].count == 2)
    }

    @Test("Prolog panel remains inside a compact landscape scene")
    func compactLandscapeLayout() throws {
        let sceneSize = CGSize(width: 667, height: 375)
        let scene = PrologScene(size: sceneSize) {}
        let view = SKView(frame: CGRect(origin: .zero, size: sceneSize))
        view.presentScene(scene)
        defer {
            view.presentScene(nil)
            AudioManager.shared.stopBackgroundMusic()
        }

        let panel = try #require(scene.childNode(withName: "prologArchivePanel") as? SKShapeNode)
        let panelBounds = try #require(panel.path?.boundingBox)
        let body = try #require(scene.childNode(withName: "//prologBodyLabel") as? SKLabelNode)
        let button = try #require(scene.childNode(withName: "//prologContinueButton") as? SKShapeNode)

        #expect(panelBounds.width <= sceneSize.width - 32)
        #expect(panelBounds.height <= sceneSize.height - 46)
        #expect(body.preferredMaxLayoutWidth <= panelBounds.width - 56 + 0.01)
        #expect(button.position.x + button.frame.width / 2 <= panelBounds.maxX)
        #expect(button.position.y - button.frame.height / 2 >= panelBounds.minY)
    }
}
